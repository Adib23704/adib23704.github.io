<#
.SYNOPSIS
    Zero-admin Vencord + completeDiscordQuest installer for Windows.
.DESCRIPTION
    Made by Adib A.K.A Azure (Discord: __azuree__ | https://adibdev.me/)
    Safe for: irm https://raw.githubusercontent.com/Adib23704/adib23704.github.io/refs/heads/main/quest.ps1 | iex
#>

& {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # --- Configuration ---
    $VencordRepo  = 'Vendicated/Vencord'
    $PluginRepo   = 'Adib23704/completeDiscordQuest-Vencord'
    # Pinned commit SHA prevents unreviewed upstream pushes from running in Discord.
    # Update this SHA when releasing a new version of completeDiscordQuest-Vencord.
    $PluginCommit = '792b8b3350d830c0c778d94da3641e169960dfa6'

    $InstallDir = Join-Path $env:LOCALAPPDATA 'VencordQuest'
    $StageDir   = "$InstallDir.staging"
    $LogFile    = Join-Path $env:TEMP 'vencord-quest-setup.log'
    $TempDir    = Join-Path $env:TEMP ('vc-quest-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $OrigPath   = $env:PATH
    $Succeeded  = $false

    function Write-Step([string]$Num, [string]$Msg) {
        Write-Host "[$Num] $Msg" -ForegroundColor Cyan
    }

    function Write-Ok([string]$Msg) {
        Write-Host "      [OK] $Msg" -ForegroundColor Green
    }

    function Write-Warn([string]$Msg) {
        Write-Host "      [WARN] $Msg" -ForegroundColor Yellow
    }

    function Get-Arch {
        if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
            return 'arm64'
        }
        if ([Environment]::Is64BitOperatingSystem) {
            return 'x64'
        }
        throw '32-bit Windows is not supported.'
    }

    function Get-File([string]$Url, [string]$OutPath) {
        Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing -Headers @{
            'User-Agent' = 'VencordQuestSetup/2.0'
        }
    }

    function Expand-ZipFast([string]$ZipPath, [string]$DestDir) {
        if (Test-Path -LiteralPath $DestDir) {
            Remove-Item -LiteralPath $DestDir -Recurse -Force
        }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $DestDir)
    }

    function Assert-Sha256([string]$FilePath, [string]$ExpectedHex) {
        $actual = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $ExpectedHex.ToLowerInvariant()) {
            throw "SHA-256 mismatch for $(Split-Path -Leaf $FilePath). Expected $ExpectedHex, got $actual."
        }
    }

    function Invoke-Logged([string]$Exe, [string[]]$CmdArgs) {
        "`n=== $Exe $($CmdArgs -join ' ') ===" | Out-File -FilePath $LogFile -Append -Encoding utf8
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $out = & $Exe @CmdArgs 2>&1
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prevEap
        }
        if ($null -ne $out) {
            $out | Out-File -FilePath $LogFile -Append -Encoding utf8
        }
        if ($code -ne 0) {
            $tail = if ($null -ne $out) { (@($out | Select-Object -Last 25)) -join "`n" } else { '(no output)' }
            throw "Command '$Exe $($CmdArgs -join ' ')' failed (exit $code).`n--- Last output ---`n$tail`nFull log: $LogFile"
        }
    }

    function Stop-DiscordIfRunning {
        $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Discord' })
        if ($procs.Count -eq 0) { return }

        Write-Warn 'Discord is currently running (open files can block build replacement or injection).'
        $reply = Read-Host '      Close Discord now? [Y/n]'
        if ([string]::IsNullOrWhiteSpace($reply) -or $reply.Trim().ToLowerInvariant().StartsWith('y')) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Write-Ok 'Discord closed.'
        } else {
            Write-Warn 'Continuing with Discord open. If injection fails, close Discord and re-run.'
        }
    }

    function Ensure-Node22([string]$Arch, [string]$WorkDir) {
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if ($nodeCmd) {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $verRaw = (& $nodeCmd.Source -p "process.versions.node" 2>$null)
            $code = $LASTEXITCODE
            $ErrorActionPreference = $prevEap
            if ($code -eq 0 -and $verRaw -match '^(\d+)\.') {
                if ([int]$Matches[1] -ge 22) {
                    Write-Ok "Using existing Node.js v$($verRaw.Trim())"
                    return
                }
                Write-Warn "Existing Node.js v$($verRaw.Trim()) is below v22; fetching portable Node.js v22..."
            }
        } else {
            Write-Host '      Downloading portable Node.js v22 LTS...'
        }

        $shasums = (Invoke-WebRequest -Uri 'https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt' -UseBasicParsing).Content
        $pattern = "(?m)^([0-9a-f]{64})\s+(node-v22\.\d+\.\d+-win-$Arch\.zip)\s*$"
        if ($shasums -notmatch $pattern) {
            throw "Could not find portable Node.js v22 ($Arch) in nodejs.org SHASUMS256.txt."
        }
        $expectedSha = $Matches[1]
        $zipName     = $Matches[2]
        $zipPath     = Join-Path $WorkDir $zipName
        $extractDir  = Join-Path $WorkDir 'node-extract'

        Get-File -Url "https://nodejs.org/dist/latest-v22.x/$zipName" -OutPath $zipPath
        Assert-Sha256 -FilePath $zipPath -ExpectedHex $expectedSha
        Expand-ZipFast -ZipPath $zipPath -DestDir $extractDir

        $nodeRoot = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
        if (-not $nodeRoot -or -not (Test-Path -LiteralPath (Join-Path $nodeRoot.FullName 'node.exe'))) {
            throw 'Portable Node.js archive did not contain node.exe.'
        }
        $env:PATH = "$($nodeRoot.FullName);$env:PATH"
        Write-Ok "Portable $($nodeRoot.Name) verified (SHA-256) and ready."
    }

    function Ensure-Pnpm([string]$RequiredVersion, [string]$Arch, [string]$WorkDir) {
        $reqMajor = $RequiredVersion.Split('.')[0]
        $pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
        if ($pnpmCmd) {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $curVer = (& $pnpmCmd.Source -v 2>$null)
            $code = $LASTEXITCODE
            $ErrorActionPreference = $prevEap
            if ($code -eq 0 -and $curVer -match "^$reqMajor\.") {
                Write-Ok "Using existing pnpm v$($curVer.Trim())"
                return $pnpmCmd.Source
            }
        }

        Write-Host "      Downloading portable pnpm v$RequiredVersion..."
        $assetName = "pnpm-win32-$Arch.zip"
        $zipPath   = Join-Path $WorkDir $assetName
        $pnpmDir   = Join-Path $WorkDir 'pnpm-bin'

        $expectedSha = $null
        try {
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/pnpm/pnpm/releases/tags/v$RequiredVersion" -UseBasicParsing -Headers @{
                'User-Agent' = 'VencordQuestSetup/2.0'
            }
            $asset = $rel.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
            if ($asset -and $asset.PSObject.Properties['digest'] -and $asset.digest -match '^sha256:([0-9a-f]{64})$') {
                $expectedSha = $Matches[1]
            }
        } catch {
            Write-Warn 'Could not fetch pnpm release checksum from GitHub API; continuing with HTTPS download.'
        }

        Get-File -Url "https://github.com/pnpm/pnpm/releases/download/v$RequiredVersion/$assetName" -OutPath $zipPath
        if ($expectedSha) {
            Assert-Sha256 -FilePath $zipPath -ExpectedHex $expectedSha
        }
        Expand-ZipFast -ZipPath $zipPath -DestDir $pnpmDir

        $pnpmExe = Get-ChildItem -LiteralPath $pnpmDir -Filter 'pnpm.exe' -Recurse | Select-Object -First 1
        if (-not $pnpmExe) {
            throw 'Portable pnpm archive did not contain pnpm.exe.'
        }
        $env:PATH = "$($pnpmExe.DirectoryName);$env:PATH"
        Write-Ok "Portable pnpm v$RequiredVersion ready."
        return $pnpmExe.FullName
    }

    try {
        Clear-Host
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor DarkCyan
        Write-Host '         CUSTOM DISCORD VENCORD QUEST PLUGIN SETUP' -ForegroundColor White
        Write-Host '============================================================' -ForegroundColor DarkCyan
        Write-Host '  Made by Adib A.K.A Azure'
        Write-Host '  Discord: __azuree__  |  https://adibdev.me/'
        Write-Host "  Install Dir: $InstallDir"
        Write-Host '============================================================' -ForegroundColor DarkCyan
        Write-Host ''

        if (Test-Path -LiteralPath $LogFile) {
            Remove-Item -LiteralPath $LogFile -Force
        }
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        $arch = Get-Arch

        # 1. Fetch Vencord source zip (no git required)
        Write-Step '1/6' 'Downloading Vencord source...'
        $vencordZip = Join-Path $TempDir 'vencord.zip'
        if (Test-Path -LiteralPath $StageDir) {
            Remove-Item -LiteralPath $StageDir -Recurse -Force
        }
        Get-File -Url "https://github.com/$VencordRepo/archive/refs/heads/main.zip" -OutPath $vencordZip
        Expand-ZipFast -ZipPath $vencordZip -DestDir $StageDir
        $vencordRoot = Get-ChildItem -LiteralPath $StageDir -Directory | Select-Object -First 1
        if (-not $vencordRoot -or -not (Test-Path -LiteralPath (Join-Path $vencordRoot.FullName 'package.json'))) {
            throw 'Downloaded Vencord archive is invalid (missing package.json).'
        }

        # Resolve Vencord commit SHA so common.mjs skips `git rev-parse` & `git remote`
        $vencordHash = 'custom'
        try {
            $commitInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$VencordRepo/commits/main" -UseBasicParsing -Headers @{
                'User-Agent' = 'VencordQuestSetup/2.0'
            }
            if ($commitInfo.PSObject.Properties['sha'] -and $commitInfo.sha.Length -ge 7) {
                $vencordHash = $commitInfo.sha.Substring(0, 7)
            }
        } catch {
            Write-Warn 'Could not fetch Vencord commit hash from GitHub API; using fallback.'
        }
        $env:VENCORD_HASH   = $vencordHash
        $env:VENCORD_REMOTE = $VencordRepo
        Write-Ok "Vencord source ready (ref: $vencordHash)."

        # 2. Fetch pinned completeDiscordQuest plugin zip
        Write-Step '2/6' "Downloading completeDiscordQuest plugin ($($PluginCommit.Substring(0, 7)))..."
        $pluginZip = Join-Path $TempDir 'plugin.zip'
        $pluginExtract = Join-Path $TempDir 'plugin-extract'
        Get-File -Url "https://github.com/$PluginRepo/archive/$PluginCommit.zip" -OutPath $pluginZip
        Expand-ZipFast -ZipPath $pluginZip -DestDir $pluginExtract
        $pluginRoot = Get-ChildItem -LiteralPath $pluginExtract -Directory | Select-Object -First 1
        if (-not $pluginRoot -or -not (Test-Path -LiteralPath (Join-Path $pluginRoot.FullName 'index.tsx'))) {
            throw 'Downloaded plugin archive is invalid (missing index.tsx).'
        }

        $userPluginsDir = Join-Path $vencordRoot.FullName 'src\userplugins'
        New-Item -ItemType Directory -Path $userPluginsDir -Force | Out-Null
        $pluginDest = Join-Path $userPluginsDir 'completeDiscordQuest'
        Copy-Item -LiteralPath $pluginRoot.FullName -Destination $pluginDest -Recurse -Force
        Write-Ok 'Plugin staged into src/userplugins/completeDiscordQuest.'

        # 3. Ensure portable Node.js >=22 and matching pnpm
        Write-Step '3/6' 'Checking Node.js (>=22) and pnpm...'
        $pkgJson = Get-Content -LiteralPath (Join-Path $vencordRoot.FullName 'package.json') -Raw | ConvertFrom-Json
        $pnpmVersion = '12.15.0'
        if ($pkgJson.PSObject.Properties['packageManager'] -and $pkgJson.packageManager -match '^pnpm@([0-9]+\.[0-9]+\.[0-9]+)') {
            $pnpmVersion = $Matches[1]
        }
        Ensure-Node22 -Arch $arch -WorkDir $TempDir
        $pnpmExe = Ensure-Pnpm -RequiredVersion $pnpmVersion -Arch $arch -WorkDir $TempDir

        # 4. Prepare final install directory (outside OneDrive/Documents, preserving other userplugins)
        Write-Step '4/6' "Preparing $InstallDir..."
        if (Test-Path -LiteralPath $InstallDir) {
            Stop-DiscordIfRunning
            $existingUserPlugins = Join-Path $InstallDir 'src\userplugins'
            if (Test-Path -LiteralPath $existingUserPlugins) {
                $extras = @(Get-ChildItem -LiteralPath $existingUserPlugins -Directory | Where-Object { $_.Name -ne 'completeDiscordQuest' })
                foreach ($extra in $extras) {
                    Copy-Item -LiteralPath $extra.FullName -Destination (Join-Path $userPluginsDir $extra.Name) -Recurse -Force
                    Write-Ok "Preserved existing userplugin: $($extra.Name)"
                }
            }
            Remove-Item -LiteralPath $InstallDir -Recurse -Force
        }
        Move-Item -LiteralPath $vencordRoot.FullName -Destination $InstallDir -Force
        Write-Ok 'Source files placed.'

        # 5. Install dependencies & build Vencord
        Write-Step '5/6' 'Installing dependencies and building Vencord (this may take 1-2 minutes)...'
        Push-Location -LiteralPath $InstallDir
        try {
            Invoke-Logged -Exe $pnpmExe -CmdArgs @('install', '--frozen-lockfile')
            Write-Ok 'Dependencies installed.'

            Invoke-Logged -Exe $pnpmExe -CmdArgs @('build')
            Write-Ok 'Vencord built.'

            # 6. Inject Vencord interactively
            Write-Step '6/6' 'Injecting Vencord - follow the installer prompts below:'
            Stop-DiscordIfRunning
            Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                & $pnpmExe inject
                $injectExit = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $prevEap
            }
            Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
            if ($injectExit -ne 0) {
                throw "Vencord injection exited with code $injectExit."
            }
            Write-Ok 'Vencord injected.'
        } finally {
            Pop-Location
        }

        $Succeeded = $true
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor Green
        Write-Host '  Setup complete!' -ForegroundColor Green
        Write-Host '  1. Restart Discord and open User Settings -> Vencord -> Plugins.'
        Write-Host '  2. Enable "CompleteDiscordQuest".'
        Write-Host "  Note: Keep $InstallDir (Discord loads Vencord from dist/)."
        Write-Host '============================================================' -ForegroundColor Green
        Write-Host ''
    } catch {
        Write-Host ''
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path -LiteralPath $LogFile) {
            Write-Host "Log saved at: $LogFile" -ForegroundColor Yellow
        }
    } finally {
        $env:PATH = $OrigPath
        Remove-Item -Path Env:VENCORD_HASH -ErrorAction SilentlyContinue
        Remove-Item -Path Env:VENCORD_REMOTE -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $TempDir) {
            Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $StageDir) {
            Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($Succeeded -and (Test-Path -LiteralPath $LogFile)) {
            Remove-Item -LiteralPath $LogFile -Force -ErrorAction SilentlyContinue
        }
    }
}

