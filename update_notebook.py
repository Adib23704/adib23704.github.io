import json

# Read the notebook
with open('FINAL_PP_AssignMent.ipynb', 'r') as f:
    notebook = json.load(f)

# Find and update each function cell
cells = notebook['cells']

# Function 1: add_student (cell index around 4)
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def add_student(student_id, name):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "\n",
            "def add_student(student_id, name):\n",
            "    \"\"\"Adds a new student to the system.\"\"\"\n",
            "    # Check if student_id already exists in the students dictionary\n",
            "    if student_id in students:\n",
            "        return f\"Error: Student with ID {student_id} already exists.\"\n",
            "    # Add the student with an empty dictionary for enrolled courses\n",
            "    students[student_id] = {\"name\": name, \"enrolled_courses\": {}}\n",
            "    return f\"Student {name} (ID: {student_id}) added successfully.\"\n"
        ]
        print(f"Updated add_student at cell {i}")

# Function 2: enroll_course
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def enroll_course(student_id, course_id):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "\n",
            "def enroll_course(student_id, course_id):\n",
            "    \"\"\"Enrolls a student in a given course.\"\"\"\n",
            "    # Check if student exists\n",
            "    if student_id not in students:\n",
            "        return f\"Error: Student with ID {student_id} does not exist.\"\n",
            "    # Check if course is valid\n",
            "    elif course_id not in courses:\n",
            "        return f\"Error: Course with ID {course_id} is not valid.\"\n",
            "    # Check if student is already enrolled in the course\n",
            "    elif course_id in students[student_id][\"enrolled_courses\"]:\n",
            "        return f\"Error: Student {student_id} is already enrolled in course {course_id}.\"\n",
            "    # Enroll the student in the course with no grade initially\n",
            "    else:\n",
            "        students[student_id][\"enrolled_courses\"][course_id] = None\n",
            "        return f\"Student {student_id} enrolled in {courses[course_id]} ({course_id}) successfully.\"\n"
        ]
        print(f"Updated enroll_course at cell {i}")

# Function 3: view_courses
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def view_courses(student_id):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "\n",
            "def view_courses(student_id):\n",
            "    \"\"\"Returns a list of enrolled courses for a student.\"\"\"\n",
            "    # Check if student exists\n",
            "    if student_id not in students:\n",
            "        return f\"Error: Student with ID {student_id} does not exist.\"\n",
            "    # Get enrolled courses\n",
            "    enrolled = students[student_id][\"enrolled_courses\"]\n",
            "    if not enrolled:\n",
            "        return f\"Student {student_id} is not enrolled in any courses.\"\n",
            "    # Return list of course names\n",
            "    course_list = [courses[cid] for cid in enrolled.keys()]\n",
            "    return course_list"
        ]
        print(f"Updated view_courses at cell {i}")

# Function 4: drop_course
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def drop_course(student_id, course_id):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "\n",
            "def drop_course(student_id, course_id):\n",
            "    \"\"\"Drops a course for a student.\"\"\"\n",
            "    # Check if student exists\n",
            "    if student_id not in students:\n",
            "        return f\"Error: Student with ID {student_id} does not exist.\"\n",
            "    # Check if student is enrolled in the course\n",
            "    if course_id not in students[student_id][\"enrolled_courses\"]:\n",
            "        return f\"Error: Student {student_id} is not enrolled in course {course_id}.\"\n",
            "    # Drop the course\n",
            "    del students[student_id][\"enrolled_courses\"][course_id]\n",
            "    return f\"Student {student_id} dropped course {courses[course_id]} ({course_id}) successfully.\"\n"
        ]
        print(f"Updated drop_course at cell {i}")

# Function 5: record_grade
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def record_grade(student_id, course_id, grade):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "\n",
            "def record_grade(student_id, course_id, grade):\n",
            "    \"\"\"Records a grade for a specific course.\"\"\"\n",
            "    # Check if student exists\n",
            "    if student_id not in students:\n",
            "        return f\"Error: Student with ID {student_id} does not exist.\"\n",
            "    # Check if student is enrolled in the course\n",
            "    if course_id not in students[student_id][\"enrolled_courses\"]:\n",
            "        return f\"Error: Student {student_id} is not enrolled in course {course_id}.\"\n",
            "    # Record the grade\n",
            "    students[student_id][\"enrolled_courses\"][course_id] = grade\n",
            "    return f\"Grade {grade} recorded for student {student_id} in course {courses[course_id]} ({course_id}).\"\n"
        ]
        print(f"Updated record_grade at cell {i}")

# Function 6: calculate_gpa
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def calculate_gpa(student_id):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "\n",
            "def calculate_gpa(student_id):\n",
            "    \"\"\"Calculates GPA for a student (average of grades).\"\"\"\n",
            "    # Check if student exists\n",
            "    if student_id not in students:\n",
            "        return f\"Error: Student with ID {student_id} does not exist.\"\n",
            "    # Get enrolled courses\n",
            "    enrolled = students[student_id][\"enrolled_courses\"]\n",
            "    # Use a for loop to calculate total and count of recorded grades\n",
            "    total_grade = 0\n",
            "    count = 0\n",
            "    for course_id, grade in enrolled.items():\n",
            "        # Only include courses with recorded grades (not None)\n",
            "        if grade is not None:\n",
            "            total_grade += grade\n",
            "            count += 1\n",
            "    # Handle division by zero if no recorded grades\n",
            "    if count == 0:\n",
            "        return 0.0\n",
            "    # Return GPA as average\n",
            "    return total_grade / count\n"
        ]
        print(f"Updated calculate_gpa at cell {i}")

# Function 7: transcript
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def transcript(student_id):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "\n",
            "def transcript(student_id):\n",
            "    \"\"\"Generates a transcript for a student with all courses and grades.\"\"\"\n",
            "    # Check if student exists\n",
            "    if student_id not in students:\n",
            "        return f\"Error: Student with ID {student_id} does not exist.\"\n",
            "    # Get student information\n",
            "    student = students[student_id]\n",
            "    name = student[\"name\"]\n",
            "    enrolled = student[\"enrolled_courses\"]\n",
            "    # Build transcript string\n",
            "    transcript_str = f\"\\n--- Transcript for {name} (ID: {student_id}) ---\\n\"\n",
            "    if not enrolled:\n",
            "        transcript_str += \"No courses enrolled.\\n\"\n",
            "    else:\n",
            "        # Loop through enrolled courses and display grades\n",
            "        for course_id, grade in enrolled.items():\n",
            "            course_name = courses[course_id]\n",
            "            grade_str = str(grade) if grade is not None else \"Not Graded\"\n",
            "            transcript_str += f\"{course_name} ({course_id}): {grade_str}\\n\"\n",
            "        # Add GPA\n",
            "        gpa = calculate_gpa(student_id)\n",
            "        transcript_str += f\"\\nGPA: {gpa:.2f}\\n\"\n",
            "    return transcript_str\n"
        ]
        print(f"Updated transcript at cell {i}")

# Function 8: check_honors_eligibility
for i, cell in enumerate(cells):
    if cell['cell_type'] == 'code' and 'def check_honors_eligibility(student_id):' in ''.join(cell.get('source', [])):
        cell['source'] = [
            "def check_honors_eligibility(student_id):\n",
            "    \"\"\"Checks if a student has an average grade >= 90 across all courses.\"\"\"\n",
            "    # Check if student exists\n",
            "    if student_id not in students:\n",
            "        return False\n",
            "    # Get enrolled courses\n",
            "    enrolled = students[student_id][\"enrolled_courses\"]\n",
            "    # Use a for loop and break to check for any grade < 90\n",
            "    has_grades = False\n",
            "    for course_id, grade in enrolled.items():\n",
            "        # Only check recorded grades (not None)\n",
            "        if grade is not None:\n",
            "            has_grades = True\n",
            "            # If any grade is below 90, return False immediately using break\n",
            "            if grade < 90:\n",
            "                return False\n",
            "    # Return True only if student has grades and all are >= 90\n",
            "    return has_grades"
        ]
        print(f"Updated check_honors_eligibility at cell {i}")

# Save the updated notebook
with open('FINAL_PP_AssignMent.ipynb', 'w') as f:
    json.dump(notebook, f, indent=2)

print("All functions updated successfully!")
