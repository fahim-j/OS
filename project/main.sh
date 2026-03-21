#!/bin/bash

# ================= FILES =================
ADMIN_FILE="admin.txt"
TEACHER_FILE="teacher.txt"
STUDENT_FILE="student.txt"
ATTENDANCE_FILE="attendance.txt"
LOGIN_HISTORY_FILE="login_history.txt"

# ================= COLORS =================
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
CYAN="\e[1;36m"
MAGENTA="\e[1;35m"
RESET="\e[0m"

# ================= DRAW BOX =================
draw_box() {
    msg="$1"
    length=$(echo -e "$msg" | wc -L)
    border=$(printf '%*s' "$length" '' | tr ' ' '=')
    echo -e "${CYAN}$border${RESET}"
    echo -e "$msg"
    echo -e "${CYAN}$border${RESET}"
}

# ================= OTP FUNCTION =================
send_otp() {
    email="$1"
    otp=$(python3 otp.py "$email")
    [ "$otp" == "ERROR" ] && echo "ERROR" || echo "$otp"
}

# ================= LOGIN FUNCTION =================
login_user() {
    user_type="$1"
    read -p "Username: " username
    read -sp "Password: " password
    echo ""

    case $user_type in
        admin) user_data=$(grep "^$username:$password:" "$ADMIN_FILE"); role="Admin" ;;
        teacher) user_data=$(grep "^$username:$password:" "$TEACHER_FILE"); role="Teacher" ;;
        student) user_data=$(grep "^$username:$password:" "$STUDENT_FILE"); role="Student" ;;
        *) echo -e "${RED}Invalid role${RESET}"; return 1 ;;
    esac

    [ -z "$user_data" ] && { echo -e "${RED}❌ Invalid Username or Password${RESET}"; return 1; }

    email=$(echo $user_data | cut -d ":" -f3)
    echo -e "📩 Sending OTP to $email..."
    otp=$(send_otp "$email")
    [ "$otp" == "ERROR" ] && { echo -e "${RED}❌ OTP send failed${RESET}"; return 1; }

    read -p "Enter OTP: " user_otp
    [ "$otp" != "$user_otp" ] && { echo -e "${RED}❌ Wrong OTP${RESET}"; return 1; }

    # Save login history (short device name)
    datetime=$(date "+%Y-%m-%d %H:%M:%S")
    device=$(uname -n)
    echo "$datetime:$username:$role:Login:$device" >> "$LOGIN_HISTORY_FILE"

    echo -e "${GREEN}✅ Login Successful!${RESET}"
    return 0
}

# ================= LOGOUT FUNCTION =================
logout_user() {
    username="$1"
    role="$2"
    datetime=$(date "+%Y-%m-%d %H:%M:%S")
    device=$(uname -n)
    echo "$datetime:$username:$role:Logout:$device" >> "$LOGIN_HISTORY_FILE"
}

# ================= FORGET PASSWORD =================
forget_password() {
    read -p "Enter role (admin/teacher/student): " role_type
    read -p "Enter username: " uname

    case $role_type in
        admin) file=$ADMIN_FILE ;;
        teacher) file=$TEACHER_FILE ;;
        student) file=$STUDENT_FILE ;;
        *) echo -e "${RED}❌ Invalid role${RESET}"; return ;;
    esac

    user_record=$(grep "^$uname:" "$file")
    [ -z "$user_record" ] && { echo -e "${RED}❌ User not found${RESET}"; return; }

    email=$(echo $user_record | cut -d ":" -f3)
    echo -e "📩 Sending OTP to $email..."
    otp=$(send_otp "$email")
    [ "$otp" == "ERROR" ] && { echo -e "${RED}❌ OTP failed${RESET}"; return; }

    read -p "Enter OTP: " input_otp
    [ "$otp" != "$input_otp" ] && { echo -e "${RED}❌ Wrong OTP${RESET}"; return; }

    read -sp "Enter new password: " newpass; echo ""
    sed -i "/^$uname:/c\\$uname:$newpass:$email" "$file"
    echo -e "${GREEN}✅ Password changed successfully!${RESET}"
}

# ================= TABLE PRINT FUNCTION =================
print_table() {
    file="$1"
    headers="$2"
    echo -e "$MAGENTA$headers${RESET}"
    column -t -s ":" "$file"
}

# ================= ADMIN DASHBOARD =================
admin_dashboard() {
    draw_box "Welcome System Admin\nRole: Admin"
    while true; do
        echo -e "\n${CYAN}===== ADMIN MENU =====${RESET}"
        echo -e "1) View Admin Info"
        echo -e "2) View Teacher Info"
        echo -e "3) View Student Info"
        echo -e "4) Add Teacher"
        echo -e "5) Update Teacher"
        echo -e "6) Delete Teacher"
        echo -e "7) Change Password"
        echo -e "8) View Login History"
        echo -e "9) Logout"
        read -p "Select: " choice
        case $choice in
            1) print_table "$ADMIN_FILE" "ID   Password   Email" ;;
            2) print_table "$TEACHER_FILE" "ID   Name   Email   Password" ;;
            3) print_table "$STUDENT_FILE" "ID   Name   Email   Password" ;;
            4)
                read -p "Teacher ID: " tid
                read -p "Name: " tname
                read -p "Email: " temail
                read -p "Password: " tpass
                echo "$tid:$tname:$temail:$tpass" >> "$TEACHER_FILE"
                echo -e "${GREEN}✅ Teacher added successfully!${RESET}" ;;
            5)
                read -p "Teacher ID to update: " tid
                if grep -q "^$tid:" "$TEACHER_FILE"; then
                    read -p "New Name: " tname
                    read -p "New Email: " temail
                    read -p "New Password: " tpass
                    sed -i "/^$tid:/c\\$tid:$tname:$temail:$tpass" "$TEACHER_FILE"
                    echo -e "${GREEN}✅ Teacher updated successfully!${RESET}"
                else
                    echo -e "${RED}❌ Teacher ID not found!${RESET}"
                fi ;;
            6)
                read -p "Teacher ID to delete: " tid
                if grep -q "^$tid:" "$TEACHER_FILE"; then
                    sed -i "/^$tid:/d" "$TEACHER_FILE"
                    echo -e "${GREEN}✅ Teacher deleted successfully!${RESET}"
                else
                    echo -e "${RED}❌ Teacher ID not found!${RESET}"
                fi ;;
            7)
                otp=$(send_otp "$(echo $user_data | cut -d ":" -f3)")
                [ "$otp" == "ERROR" ] && echo -e "${RED}❌ OTP fail${RESET}" && continue
                read -p "Enter OTP: " in_otp
                [ "$otp" != "$in_otp" ] && echo -e "${RED}❌ Wrong OTP${RESET}" && continue
                read -sp "Enter new password: " np; echo ""
                sed -i "/^$username:/c\\$username:$np:$(echo $user_data | cut -d ":" -f3)" "$ADMIN_FILE"
                echo -e "${GREEN}✅ Password changed!${RESET}" ;;
            8)
                [ ! -f "$LOGIN_HISTORY_FILE" ] && echo -e "${RED}No login history found${RESET}" || {
                    echo -e "${MAGENTA}Date Time           Username Role    Status   Device${RESET}"
                    column -t -s ":" "$LOGIN_HISTORY_FILE"
                } ;;
            9) logout_user "$username" "$role"; break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ;;
        esac
    done
}

# ================= TEACHER DASHBOARD =================
teacher_dashboard() {
    teacher_name=$(echo $user_data | cut -d ":" -f2)
    draw_box "Welcome $teacher_name\nRole: Teacher"

    while true; do
        echo -e "\n${CYAN}===== TEACHER MENU =====${RESET}"
        echo -e "1) View Teacher Info"
        echo -e "2) View Student Info"
        echo -e "3) Add Student"
        echo -e "4) Update Student"
        echo -e "5) Delete Student"
        echo -e "6) Mark Attendance"
        echo -e "7) View Attendance"
        echo -e "8) Generate CSV Attendance"
        echo -e "9) Search Attendance"
        echo -e "10) Update Attendance"
        echo -e "11) Change Password"
        echo -e "12) View Login History"
        echo -e "13) Logout"

        read -p "Select: " choice
        case $choice in
            1) print_table "$TEACHER_FILE" "ID   Name   Email   Password" ;;
            2) print_table "$STUDENT_FILE" "ID   Name   Email   Password" ;;
            3)
                read -p "Student ID: " sid
                read -p "Name: " sname
                read -p "Email: " semail
                read -p "Password: " spass
                echo "$sid:$sname:$semail:$spass" >> "$STUDENT_FILE"
                echo -e "${GREEN}✅ Student added successfully!${RESET}" ;;
            4)
                read -p "Student ID to update: " sid
                if grep -q "^$sid:" "$STUDENT_FILE"; then
                    read -p "New Name: " sname
                    read -p "New Email: " semail
                    read -p "New Password: " spass
                    sed -i "/^$sid:/c\\$sid:$sname:$semail:$spass" "$STUDENT_FILE"
                    echo -e "${GREEN}✅ Student updated successfully!${RESET}"
                else
                    echo -e "${RED}❌ Student ID not found!${RESET}"
                fi ;;
            5)
                read -p "Student ID to delete: " sid
                if grep -q "^$sid:" "$STUDENT_FILE"; then
                    sed -i "/^$sid:/d" "$STUDENT_FILE"
                    echo -e "${GREEN}✅ Student deleted successfully!${RESET}"
                else
                    echo -e "${RED}❌ Student ID not found!${RESET}"
                fi ;;
            6)
                echo -e "${YELLOW}===== MARK ATTENDANCE =====${RESET}"
                printf "%-10s %-20s %-25s\n" "ID" "Name" "Email"
                while IFS=: read -r sid sname semail spass; do
                    printf "%-10s %-20s %-25s\n" "$sid" "$sname" "$semail"
                done < "$STUDENT_FILE"
                while true; do
                    read -p "Enter Student ID (or 'done'): " sid
                    [[ "$sid" == "done" ]] && break
                    grep -q "^$sid:" "$STUDENT_FILE" || { echo -e "${RED}❌ Invalid Student ID${RESET}"; continue; }
                    read -p "Status (P/A/L): " status
                    case $status in
                        P) status_full="Present" ;;
                        A) status_full="Absent" ;;
                        L) status_full="Late" ;;
                        *) echo "Invalid"; continue ;;
                    esac
                    date=$(date +%F)
                    echo "$date:$sid:$status_full" >> "$ATTENDANCE_FILE"
                    echo -e "${GREEN}✅ $sid marked $status_full${RESET}"
                done ;;
            7)
                [ ! -f "$ATTENDANCE_FILE" ] && echo -e "${RED}No attendance data${RESET}" || {
                    echo -e "${MAGENTA}Date       ID   Status${RESET}"
                    column -t -s ":" "$ATTENDANCE_FILE"
                } ;;
            8)
                [ ! -f "$ATTENDANCE_FILE" ] && echo -e "${RED}No data to export${RESET}" || {
                    cp "$ATTENDANCE_FILE" attendance.csv
                    echo -e "${GREEN}✅ attendance.csv generated!${RESET}"
                } ;;
            9)
                read -p "Student ID to search: " sid
                grep ":$sid:" "$ATTENDANCE_FILE" || echo -e "${RED}No record found${RESET}" ;;
            10)
                read -p "Date (YYYY-MM-DD): " date
                read -p "Student ID: " sid
                grep -q "^$date:$sid:" "$ATTENDANCE_FILE" || { echo -e "${RED}❌ Record not found${RESET}"; continue; }
                read -p "New Status (Present/Absent/Late): " status
                sed -i "/^$date:$sid:/c\\$date:$sid:$status" "$ATTENDANCE_FILE"
                echo -e "${GREEN}✅ Attendance updated!${RESET}" ;;
            11)
                otp=$(send_otp "$(echo $user_data | cut -d ":" -f3)")
                [ "$otp" == "ERROR" ] && echo -e "${RED}❌ OTP fail${RESET}" && continue
                read -p "Enter OTP: " in_otp
                [ "$otp" != "$in_otp" ] && echo -e "${RED}❌ Wrong OTP${RESET}" && continue
                read -sp "Enter new password: " np; echo ""
                sed -i "/^$username:/c\\$username:$np:$(echo $user_data | cut -d ":" -f3)" "$TEACHER_FILE"
                echo -e "${GREEN}✅ Password changed!${RESET}" ;;
            12)
                [ ! -f "$LOGIN_HISTORY_FILE" ] && echo -e "${RED}No login history found${RESET}" || {
                    echo -e "${MAGENTA}Date Time           Username Role    Status   Device${RESET}"
                    grep ":$username:" "$LOGIN_HISTORY_FILE" | column -t -s ":"
                } ;;
            13) logout_user "$username" "$role"; break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ;;
        esac
    done
}

# ================= STUDENT DASHBOARD =================
student_dashboard() {
    student_name=$(echo $user_data | cut -d ":" -f2)
    draw_box "Welcome $student_name\nRole: Student"

    while true; do
        echo -e "\n${CYAN}===== STUDENT MENU =====${RESET}"
        echo -e "1) View My Info"
        echo -e "2) View Attendance with % Present"
        echo -e "3) Change Password"
        echo -e "4) View Login History"
        echo -e "5) Logout"
        read -p "Select: " choice
        case $choice in
            1)
                echo -e "${MAGENTA}ID   Name   Email   Password${RESET}"
                echo "$user_data" | column -t -s ":" ;;
            
            2)
                [ ! -f "$ATTENDANCE_FILE" ] && { echo -e "${RED}No attendance records found${RESET}"; continue; }

                sid=$(echo $user_data | cut -d ":" -f1)
                records=$(grep ":$sid:" "$ATTENDANCE_FILE")
                [ -z "$records" ] && { echo -e "${RED}No attendance records found${RESET}"; continue; }

                echo -e "${MAGENTA}Date       ID   Status${RESET}"
                echo "$records" | while IFS=: read -r date sid status; do
                    case $status in
                        Present) color=$GREEN ;;
                        Absent) color=$RED ;;
                        Late) color=$YELLOW ;;
                        *) color=$RESET ;;
                    esac
                    printf "${color}%-12s %-10s %-10s${RESET}\n" "$date" "$sid" "$status"
                done

                # Calculate % Present
                total=$(echo "$records" | wc -l)
                present=$(echo "$records" | grep -c "Present")
                percent=$((present*100/total))
                echo -e "\n${CYAN}✅ Attendance: $percent% Present${RESET}" ;;

            3)
                email=$(echo $user_data | cut -d ":" -f3)
                otp=$(send_otp "$email")
                [ "$otp" == "ERROR" ] && { echo -e "${RED}❌ OTP failed${RESET}"; continue; }
                read -p "Enter OTP: " in_otp
                [ "$otp" != "$in_otp" ] && { echo -e "${RED}❌ Wrong OTP${RESET}"; continue; }

                read -sp "Enter new password: " np; echo ""
                sed -i "/^$username:/c\\$username:$np:$email" "$STUDENT_FILE"
                echo -e "${GREEN}✅ Password changed successfully!${RESET}" ;;

            4)
                [ ! -f "$LOGIN_HISTORY_FILE" ] && { echo -e "${RED}No login history found${RESET}"; continue; }
                echo -e "${MAGENTA}Date Time           Username Role    Status   Device${RESET}"
                grep ":$username:" "$LOGIN_HISTORY_FILE" | column -t -s ":" ;;

            5)
                logout_user "$username" "$role"
                break ;;

            *)
                echo -e "${RED}Invalid option!${RESET}" ;;
        esac
    done
}

# ================= MAIN MENU =================
while true; do
    clear
    draw_box "SYSTEM LOGIN MENU"
    echo -e "1) Admin Login"
    echo -e "2) Teacher Login"
    echo -e "3) Student Login"
    echo -e "4) Forget Password"
    echo -e "5) Exit"
    read -p "Select option: " choice
    case $choice in
        1) login_user admin && admin_dashboard ;;
        2) login_user teacher && teacher_dashboard ;;
        3) login_user student && student_dashboard ;;
        4) forget_password ;;
        5) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid choice!${RESET}" ;;
    esac
done
