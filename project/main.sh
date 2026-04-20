#2
#!/bin/bash

# ================= FILES =================
#ADMIN_FILE="admin.txt"
#TEACHER_FILE="teacher.txt"
#STUDENT_FILE="student.txt"
#ATTENDANCE_FILE="attendance.txt"
#TEACHER_ATT_FILE="teacher_attendance.txt"
#LOGIN_HISTORY_FILE="login_history.txt"
#ANNOUNCEMENT_FILE="announcement.txt"



BASE_DIR="/home/fahim/Desktop/project"

ADMIN_FILE="$BASE_DIR/admin.txt"
TEACHER_FILE="$BASE_DIR/teacher.txt"
STUDENT_FILE="$BASE_DIR/student.txt"
ATTENDANCE_FILE="$BASE_DIR/attendance.txt"
TEACHER_ATT_FILE="$BASE_DIR/teacher_attendance.txt"
LOGIN_HISTORY_FILE="$BASE_DIR/login_history.txt"
ANNOUNCEMENT_FILE="$BASE_DIR/announcement.txt"

# ================= COLORS =================
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
CYAN="\e[1;36m"
MAGENTA="\e[1;35m"
RESET="\e[0m"

# ================= TIMEZONE =================
export TZ="Asia/Dhaka"

# ================= DRAW BOX =================
draw_box() {
    msg="$1"
    length=$(echo -e "$msg" | wc -L)
    border=$(printf '%*s' "$length" '' | tr ' ' '=')
    echo -e "${CYAN}$border${RESET}"
    echo -e "$msg"
    echo -e "${CYAN}$border${RESET}"
}

# ================= AUTO TEACHER ATTENDANCE =================
auto_teacher_attendance() {
    today=$(date +%F)

    while IFS=: read -r tid tname temail tpass; do
        if ! grep -q "^$today:$tid:" "$TEACHER_ATT_FILE" 2>/dev/null; then
            echo "$today:$tid:Absent" >> "$TEACHER_ATT_FILE"
        fi
    done < "$TEACHER_FILE"
}

# ================= CRON FLAGS =================
# ================= AUTO TEACHER ATTENDANCE (Cron compatible) =================
if [ "$1" == "--auto-teacher-att" ]; then
    BASE_DIR="/home/fahim/Desktop/project"
    TEACHER_FILE="$BASE_DIR/teacher.txt"
    TEACHER_ATT_FILE="$BASE_DIR/teacher_attendance.txt"
    
    date_today=$(date "+%Y-%m-%d")
    
    while IFS=: read -r tid tname temail tpass; do
        # check if already marked today
        if grep -q "^$date_today:$tid:" "$TEACHER_ATT_FILE" 2>/dev/null; then
            echo "Attendance already marked for $tname today"
        else
            echo "$date_today:$tid:Present" >> "$TEACHER_ATT_FILE"
            echo "✅ Auto attendance marked for $tname"
        fi
    done < "$TEACHER_FILE"

    # Generate CSV
    csv_file="$BASE_DIR/teacher_attendance_$(date "+%Y-%m-%d").csv"
    cp "$TEACHER_ATT_FILE" "$csv_file"
    echo "✅ CSV generated at $csv_file"

    exit 0
fi
# ================= PREMIUM TABLE =================
print_table() {
    file="$1"
    headers="$2"
    title="$3"

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${YELLOW}📊 $title${RESET}"
    echo -e "${MAGENTA}  $headers${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [ -f "$file" ]; then
        clean_file "$file"
        grep -v '^$' "$file" | column -t -s ":" | awk '
        BEGIN { row=0 }
        {
            status_index=NF
            if ($status_index == "Present") color="\033[1;32m";
            else if ($status_index == "Absent") color="\033[1;31m";
            else if ($status_index == "Late") color="\033[1;33m";
            else color="\033[0m";

            if (row % 2 == 0)
                printf "\033[48;5;236m  %s\033[0m\n", $0;
            else
                printf "  %s\n", $0;
            row++
        }'
    else
        echo -e "${RED}No data found${RESET}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
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
        admin)
            user_data=$(grep "^$username:$password:" "$ADMIN_FILE")
            role="Admin"
            ;;
        teacher)
            user_data=$(awk -F: -v u="$username" -v p="$password" '$1==u && $4==p {print}' "$TEACHER_FILE")
            role="Teacher"
            ;;
        student)
            user_data=$(awk -F: -v u="$username" -v p="$password" '$1==u && $7==p {print}' "$STUDENT_FILE")
            role="Student"
            ;;
        *)
            echo -e "${RED}Invalid role${RESET}"
            return 1
            ;;
    esac

    [ -z "$user_data" ] && { echo -e "${RED}❌ Invalid Username or Password${RESET}"; return 1; }

    #email=$(echo $user_data | cut -d ":" -f3)
    #echo -e "📩 Sending OTP to $email..."
    #otp=$(send_otp "$email")
    #[ "$otp" == "ERROR" ] && { echo -e "${RED}❌ OTP send failed${RESET}"; return 1; }

    #read -p "Enter OTP: " user_otp
    #[ "$otp" != "$user_otp" ] && { echo -e "${RED}❌ Wrong OTP${RESET}"; return 1; }
    
    
    # ================= OTP (skip for students) =================
if [ "$user_type" != "student" ]; then
    email=$(echo $user_data | cut -d ":" -f3)
    echo -e "📩 Sending OTP to $email..."
    otp=$(send_otp "$email")
    [ "$otp" == "ERROR" ] && { echo -e "${RED}❌ OTP send failed${RESET}"; return 1; }

    read -p "Enter OTP: " user_otp
    [ "$otp" != "$user_otp" ] && { echo -e "${RED}❌ Wrong OTP${RESET}"; return 1; }
fi

    datetime=$(date "+%Y-%m-%d %a %I:%M %p")
    device="ubuntu"

    echo "$datetime:$username:$role:Login:$device" >> "$LOGIN_HISTORY_FILE"

    if [ "$role" == "Teacher" ]; then
        date=$(date +%F)
        echo "$date:$username:Present" >> "$TEACHER_ATT_FILE"
    fi

    echo -e "${GREEN}✅ Login Successful!${RESET}"
    return 0
}

# ================= LOGOUT FUNCTION =================
logout_user() {
    username="$1"
    role="$2"
    datetime=$(date "+%Y-%m-%d %a %I:%M %p")
    device="ubuntu"
    echo "$datetime:$username:$role:Logout:$device" >> "$LOGIN_HISTORY_FILE"
}

# ================= CHANGE PASSWORD =================
change_password() {
    case "$role" in
        Admin) file=$ADMIN_FILE ;;
        Teacher) file=$TEACHER_FILE ;;
        Student) file=$STUDENT_FILE ;;
        *) echo -e "${RED}❌ Unknown role${RESET}"; return ;;
    esac

    echo -e "${YELLOW}📩 Sending OTP to your registered email...${RESET}"
    email=$(echo "$user_data" | cut -d ":" -f3)
    otp=$(send_otp "$email")
    [ "$otp" == "ERROR" ] && { echo -e "${RED}❌ OTP sending failed${RESET}"; return; }

    read -p "Enter OTP: " input_otp
    [ "$otp" != "$input_otp" ] && { echo -e "${RED}❌ Wrong OTP${RESET}"; return; }

    read -sp "Enter new password: " newpass; echo ""
    username=$(echo "$user_data" | cut -d ":" -f1)

    if [ "$role" == "Admin" ]; then
        sed -i "/^$username:/c\\$username:$newpass:$email" "$file"
        user_data="$username:$newpass:$email"
    else
        name=$(echo "$user_data" | cut -d ":" -f2)
        sed -i "/^$username:/c\\$username:$name:$email:$newpass" "$file"
        user_data="$username:$name:$email:$newpass"
    fi

    echo -e "${GREEN}✅ Password changed successfully!${RESET}"
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
    if [ "$role_type" == "admin" ]; then
        sed -i "/^$uname:/c\\$uname:$newpass:$email" "$file"
    else
        name=$(echo "$user_record" | cut -d ":" -f2)
        sed -i "/^$uname:/c\\$uname:$name:$email:$newpass" "$file"
    fi
    echo -e "${GREEN}✅ Password changed successfully!${RESET}"
}


# ================= AUTO CLEAN =================
clean_file() {
    [ -f "$1" ] && sed -i '/^$/d' "$1"
}

# ================= ADMIN DASHBOARD =================
admin_dashboard() {
    draw_box "Welcome System Admin\nRole: Admin"

    while true; do
        echo -e "\n${CYAN}===== ADMIN MENU =====${RESET}"
        echo -e "${CYAN}1) View Admin Info${RESET}"
        echo -e "${CYAN}2) Change Password${RESET}"
        echo -e "${CYAN}3) View Teacher Info${RESET}"
        echo -e "${CYAN}4) Add Teacher${RESET}"
        echo -e "${CYAN}5) Update Teacher${RESET}"
        echo -e "${CYAN}6) Delete Teacher${RESET}"
        echo -e "${CYAN}7) View Student Info${RESET}"
        echo -e "${CYAN}8) View Teacher Attendance${RESET}"
        echo -e "${CYAN}9) Search Teacher Attendance${RESET}"
        echo -e "${CYAN}10) View Login History${RESET}"
        echo -e "${CYAN}11) View Teacher Login History${RESET}"
        echo -e "${CYAN}12) View Student Login History${RESET}"
        echo -e "${CYAN}13) Generate Teacher Attendance CSV${RESET}"
	echo -e "${CYAN}14) Logout${RESET}"

        read -p "Select: " choice
        case $choice in
            1) print_table "$ADMIN_FILE" "ID Password Email" "Admin Info" ;;
            2) change_password ;;
            3)
                awk -F: '{print $1 ":" $2 ":" $3}' "$TEACHER_FILE" > temp_teacher.txt
                print_table "temp_teacher.txt" "ID Name Email" "Teacher List"
                rm -f temp_teacher.txt
                ;;
            4)
                read -p "Teacher ID: " tid
                read -p "Name: " tname
                read -p "Email: " temail
                read -p "Password: " tpass
                echo "$tid:$tname:$temail:$tpass" >> "$TEACHER_FILE"
                echo -e "${GREEN}✅ Teacher added successfully!${RESET}"
                ;;
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
                fi
                ;;
            6)
                read -p "Teacher ID to delete: " tid
                if grep -q "^$tid:" "$TEACHER_FILE"; then
                    sed -i "/^$tid:/d" "$TEACHER_FILE"
                    clean_file "$TEACHER_FILE" 
                    echo -e "${GREEN}✅ Teacher deleted successfully!${RESET}"
                else
                    echo -e "${RED}❌ Teacher ID not found!${RESET}"
                fi
                ;;
            7)
                awk -F: '{print $1 ":" $2 ":" $3}' "$STUDENT_FILE" > temp_student.txt
                print_table "temp_student.txt" "ID Name Email" "Student List"
                rm -f temp_student.txt
                ;;
            8) print_table "$TEACHER_ATT_FILE" "Date TeacherID Status" "Teacher Attendance" ;;
            9)
                read -p "Enter Teacher ID: " tid
                grep ":$tid:" "$TEACHER_ATT_FILE" > temp_search.txt
                if [ ! -s temp_search.txt ]; then
                    echo -e "${RED}❌ No record found${RESET}"
                else
                    print_table "temp_search.txt" "Date TeacherID Status" "Search Result"
                fi
                rm -f temp_search.txt
                ;;
            10)
                grep ":$username:" "$LOGIN_HISTORY_FILE" > temp_login.txt
                print_table "temp_login.txt" "Date Time Username Role Status Device" "Your Login History"
                rm -f temp_login.txt
                ;;
            11)
                grep ":Teacher:" "$LOGIN_HISTORY_FILE" > temp_teacher_login.txt
                print_table "temp_teacher_login.txt" "Date Time Username Role Status Device" "Teacher Login History"
                rm -f temp_teacher_login.txt
                ;;
            12)
                grep ":Student:" "$LOGIN_HISTORY_FILE" > temp_student_login.txt
                print_table "temp_student_login.txt" "Date Time Username Role Status Device" "Student Login History"
                rm -f temp_student_login.txt
                ;;
            13)
    		cp "$TEACHER_ATT_FILE" "teacher_attendance_$(date +%F).csv"
   		echo -e "${GREEN}✅ Teacher Attendance CSV Generated${RESET}"
		;;
	    14)
  		logout_user "$username" "$role"
		break
 		;;
            *)
                echo -e "${RED}Invalid option!${RESET}"
                ;;
        esac
    done
}

# ================= TEACHER DASHBOARD =================
teacher_dashboard() {
    teacher_name=$(echo $user_data | cut -d ":" -f2)
    draw_box "Welcome $teacher_name\nRole: Teacher"

    while true; do
        echo -e "\n${MAGENTA}===== TEACHER MENU =====${RESET}"
        echo -e "${MAGENTA}1) View My Info${RESET}"
        echo -e "${MAGENTA}2) View Teacher Info${RESET}"
        echo -e "${MAGENTA}3) Change Password${RESET}"
        echo -e "${MAGENTA}4) View Student Info${RESET}"
        echo -e "${MAGENTA}5) Add Student${RESET}"
        echo -e "${MAGENTA}6) Update Student${RESET}"
        echo -e "${MAGENTA}7) Delete Student${RESET}"
        echo -e "${MAGENTA}8) Mark Attendance${RESET}"
        echo -e "${MAGENTA}9) View Attendance${RESET}"
        echo -e "${MAGENTA}10) Update Attendance${RESET}"
        echo -e "${MAGENTA}11) Generate CSV Attendance${RESET}"
        echo -e "${MAGENTA}12) Search Attendance${RESET}"
        echo -e "${MAGENTA}13) Manage Announcements${RESET}"
        echo -e "${MAGENTA}14) View Login History${RESET}"
        echo -e "${MAGENTA}15) View Student Login History${RESET}"
        echo -e "${MAGENTA}16) Logout${RESET}"

        read -p "Select: " choice
        case $choice in
            1)
                echo "$user_data" > temp_myinfo.txt
                print_table "temp_myinfo.txt" "ID Name Email Password" "My Info"
                rm -f temp_myinfo.txt
                ;;
            2)
                awk -F: '{print $1 ":" $2 ":" $3}' "$TEACHER_FILE" > temp_teacher.txt
                print_table "temp_teacher.txt" "ID Name Email" "Teacher List"
                rm -f temp_teacher.txt
                ;;
            3) change_password ;;
            4)
read -p "Department: " d
read -p "Section: " s

d=$(echo "$d" | xargs)
s=$(echo "$s" | xargs)

awk -F: -v d="$d" -v s="$s" '
$5==d && $6==s {
    print $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6
}' "$STUDENT_FILE" > temp_student.txt

# Updated table headers
print_table "temp_student.txt" "ID Name Email Phone Dept Section" "Filtered Student List"

rm -f temp_student.txt
                ;;
            5)
                
                read -p "Student ID: " sid
		read -p "Name: " sname
		read -p "Email: " semail
		read -p "Phone: " sphone
		read -p "Department: " sdept
		read -p "Section: " ssection
		read -p "Password: " spass

		echo "$sid:$sname:$semail:$sphone:$sdept:$ssection:$spass" >> "$STUDENT_FILE"
		echo -e "${GREEN}✅ Student added successfully!${RESET}"
		;;
            6)
            
            read -p "Department: " d
read -p "Section: " s
read -p "Student ID: " sid

if awk -F: -v d="$d" -v s="$s" -v id="$sid" '$1==id && $5==d && $6==s' "$STUDENT_FILE" | grep -q .; then
    echo "Valid student"
else
    echo -e "${RED}❌ Student not in this Dept/Section${RESET}"
    return
fi
            

		if grep -q "^$sid:" "$STUDENT_FILE"; then
    		old_record=$(grep "^$sid:" "$STUDENT_FILE")

    		old_name=$(echo "$old_record" | cut -d ":" -f2)
    		old_email=$(echo "$old_record" | cut -d ":" -f3)
    		old_phone=$(echo "$old_record" | cut -d ":" -f4)
    		old_dept=$(echo "$old_record" | cut -d ":" -f5)
    		old_section=$(echo "$old_record" | cut -d ":" -f6)
    		old_pass=$(echo "$old_record" | cut -d ":" -f7)

    		echo "Press Enter to keep previous value"

    		read -p "New Name [$old_name]: " sname
    		read -p "New Email [$old_email]: " semail
    		read -p "New Phone [$old_phone]: " sphone
    		read -p "New Department [$old_dept]: " sdept
    		read -p "New Section [$old_section]: " ssection
    		read -p "New Password [$old_pass]: " spass

    		# If empty → keep old
    		sname=${sname:-$old_name}
    		semail=${semail:-$old_email}
    		sphone=${sphone:-$old_phone}
    		sdept=${sdept:-$old_dept}
    		ssection=${ssection:-$old_section}
    		spass=${spass:-$old_pass}

    		sed -i "/^$sid:/c\\$sid:$sname:$semail:$sphone:$sdept:$ssection:$spass" "$STUDENT_FILE"

    		echo -e "${GREEN}✅ Student updated successfully!${RESET}"
		else
    		echo -e "${RED}❌ Student ID not found!${RESET}"
		fi
                ;;
            7)            
                read -p "Department: " d
		read -p "Section: " s

		awk -F: -v d="$d" -v s="$s" '$5==d && $6==s {
    		print $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6
		}' "$STUDENT_FILE" > temp_student.txt

		if [ ! -s temp_student.txt ]; then
    		echo -e "${RED}❌ No student found${RESET}"
		else
    		print_table "temp_student.txt" "ID Name Email Phone Dept Section" "Filtered Students"

    		read -p "Enter Student IDs to delete (comma-separated): " sids
    		IFS=',' read -ra arr <<< "$sids"

    		for sid in "${arr[@]}"; do
        		if grep -q "^$sid:" "$STUDENT_FILE"; then
            		    sed -i "/^$sid:/d" "$STUDENT_FILE"
            		    echo -e "${GREEN}Deleted Student ID $sid${RESET}"
        		else
            		    echo -e "${RED}❌ Student ID $sid not found!${RESET}"
        		fi
    		done

    			clean_file "$STUDENT_FILE"
		fi

		rm -f temp_student.txt
                ;;
            8)
                echo -e "${YELLOW}===== MARK ATTENDANCE =====${RESET}"
                #awk -F: '{print $1 ":" $2 ":" $3}' "$STUDENT_FILE" > temp_student.txt
                
                read -p "Filter by Department: " fdept
		read -p "Filter by Section: " fsection

		awk -F: -v d="$fdept" -v s="$fsection" '$5==d && $6==s {
    		print $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6
		}' "$STUDENT_FILE" > temp_student.txt

		print_table "temp_student.txt" "ID Name Email Phone Dept Section" "Filtered Student List"
                
                
                #print_table "temp_student.txt" "ID Name Email" "Student List"
                read -p "Enter Student IDs to mark attendance (comma-separated): " sids_input
                sids_input=$(echo $sids_input | tr -d ' ')
                IFS=',' read -ra sids <<< "$sids_input"
                for sid in "${sids[@]}"; do
                    student_record=$(grep "^$sid:" "$STUDENT_FILE")
                    if [ -z "$student_record" ]; then
                        echo -e "${RED}❌ Student ID $sid not found!${RESET}"
                        continue
                    fi
                    sname=$(echo $student_record | cut -d ":" -f2)
                    while true; do
                        read -p "Status for $sname (P/A/L): " status
                        case $status in
                            P|p) status_full="Present"; break ;;
                            A|a) status_full="Absent"; break ;;
                            L|l) status_full="Late"; break ;;
                            *) echo -e "${RED}Invalid input! Enter P, A, or L${RESET}" ;;
                        esac
                    done
                    #date=$(date "+%Y-%m-%d %a %I:%M %p")
                    date=$(date "+%Y-%m-%d")
                    if grep -q "^$date:$sid:" "$ATTENDANCE_FILE" 2>/dev/null; then
                        echo -e "${RED}❌ Attendance already marked for $sname today!${RESET}"
                    else
                        echo "$date:$sid:$status_full" >> "$ATTENDANCE_FILE"
                        echo -e "${GREEN}✅ Attendance marked for $sname${RESET}"
                    fi
                done
                rm -f temp_student.txt
                ;;
            9) #print_table "$ATTENDANCE_FILE" "Date StudentID Status" "Attendance Record" ;;
            read -p "Department: " d
read -p "Section: " s

awk -F: -v d="$d" -v s="$s" '
FNR==NR {
    if ($5==d && $6==s) ids[$1]=1
    next
}
{
    sid=$2
    if (sid in ids)
        print
}
' "$STUDENT_FILE" "$ATTENDANCE_FILE" > temp_att.txt

if [ ! -s temp_att.txt ]; then
    echo -e "${RED}❌ No attendance found${RESET}"
else
    print_table "temp_att.txt" "Date StudentID Status" "Filtered Attendance"
fi

rm -f temp_att.txt
;;
10)
read -p "Department: " d
read -p "Section: " s

awk -F: -v d="$d" -v s="$s" '$5==d && $6==s {
    print $1 ":" $2
}' "$STUDENT_FILE" > temp_ids.txt

if [ ! -s temp_ids.txt ]; then
    echo -e "${RED}❌ No students found${RESET}"
    rm -f temp_ids.txt
    return
fi

print_table "temp_ids.txt" "ID Name" "Filtered Students"

read -p "Date: " date
read -p "Student ID: " sid
read -p "New Status (Present/Absent/Late): " status

# check valid student in that dept+section
if grep -q "^$sid:" temp_ids.txt; then
    sed -i "/^$date:$sid:/c\\$date:$sid:$status" "$ATTENDANCE_FILE"
    echo -e "${GREEN}✅ Attendance Updated${RESET}"
else
    echo -e "${RED}❌ Student not in selected Dept/Section${RESET}"
fi

rm -f temp_ids.txt
                ;;
            #11) cp "$ATTENDANCE_FILE" attendance.csv; echo -e "${GREEN}CSV Generated${RESET}" ;;
            11)
    		csv_file="attendance_$(date +%Y%m%d_%H%M%S).csv"
    		cp "$ATTENDANCE_FILE" "$csv_file"
    		echo -e "${GREEN}✅ CSV Generated: $csv_file${RESET}"
    		echo -e "${CYAN}📥 File saved in: $(pwd)/$csv_file${RESET}"
    		;;
            12)


read -p "Department: " d
read -p "Section: " s
read -p "Student ID (optional): " sid

d=$(echo $d | xargs)
s=$(echo $s | xargs)
sid=$(echo $sid | xargs)

awk -F: -v d="$d" -v s="$s" -v sid="$sid" '
FNR==NR {
    if ($5==d && $6==s) ids[$1]=1
    next
}
{
    student_id=$2
    if (student_id in ids) {
        if (sid=="" || student_id==sid)
            print
    }
}
' "$STUDENT_FILE" "$ATTENDANCE_FILE" > temp_search.txt

if [ ! -s temp_search.txt ]; then
    echo -e "${RED}❌ No record found${RESET}"
else
    print_table "temp_search.txt" "Date StudentID Status" "Search Result"
fi

rm -f temp_search.txt
                ;;
            13)
                echo -e "${CYAN}===== ANNOUNCEMENTS =====${RESET}"
                echo "1) Add Announcement"
                echo "2) Delete Announcement"
                echo "3) View Announcements"
                read -p "Select: " a_choice
                case $a_choice in
                    1)
                        read -p "Enter announcement text: " ann_text
                        date=$(date "+%Y-%m-%d %a %I:%M %p")
                        echo "$date:$teacher_name:$ann_text" >> "$ANNOUNCEMENT_FILE"
                        echo -e "${GREEN}✅ Announcement added${RESET}"
                        ;;
                    2)
                        read -p "Enter date to delete: " del_date
                        sed -i "/^$del_date:$teacher_name:/d" "$ANNOUNCEMENT_FILE"
                        echo -e "${GREEN}Deleted${RESET}"
                        ;;
                    3) print_table "$ANNOUNCEMENT_FILE" "Date Teacher Announcement" "Announcements" ;;
                esac
                ;;
            14)
                grep ":$username:" "$LOGIN_HISTORY_FILE" > temp_login.txt
                print_table "temp_login.txt" "Date Time Username Role Status Device" "Your Login History"
                rm -f temp_login.txt
                ;;
            15)
                grep ":Student:" "$LOGIN_HISTORY_FILE" > temp_student_login.txt
                print_table "temp_student_login.txt" "Date Time Username Role Status Device" "Student Login History"
                rm -f temp_student_login.txt
                ;;
            16)
                logout_user "$username" "$role"
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

# ================= STUDENT DASHBOARD =================
student_dashboard() {
    student_name=$(echo $user_data | cut -d ":" -f2)
    draw_box "Welcome $student_name\nRole: Student"

    while true; do
        echo -e "\n${YELLOW}1) View Info${RESET}"
        echo -e "${YELLOW}2) Change Password${RESET}"
        echo -e "${YELLOW}3) View Attendance${RESET}"
        echo -e "${YELLOW}4) View Announcements${RESET}"
        echo -e "${YELLOW}5) View Login History${RESET}"
        echo -e "${YELLOW}6) Logout${RESET}"

        read -p "Select: " c
        case $c in
            1)
                echo "$user_data" > temp_myinfo.txt
                print_table "temp_myinfo.txt" "ID Name Email Phone Dept Section Password" "My Info"
                rm -f temp_myinfo.txt
                ;;
            2) change_password ;;
            3)
                student_id=$(echo $user_data | cut -d ":" -f1)
                grep ":$student_id:" "$ATTENDANCE_FILE" > temp_att.txt
                if [ ! -s temp_att.txt ]; then
                    echo -e "${RED}❌ No attendance record found${RESET}"
                else
                    print_table "temp_att.txt" "Date StudentID Status" "Your Attendance"
                    total=$(wc -l < temp_att.txt)
                    present=$(grep -c ":$student_id:Present" temp_att.txt)
                    late=$(grep -c ":$student_id:Late" temp_att.txt)
                    absent=$(( total - present - late ))
                    percent=$(echo "scale=2; (($present + $late) / $total) * 100" | bc)
                    echo -e "Total Days:$total\nPresent:$present\nLate:$late\nAbsent:$absent\nAttendance %:$percent%" > temp_summary.txt
                    print_table "temp_summary.txt" "Category Value" "Attendance Summary"
                    rm -f temp_summary.txt
                fi
                rm -f temp_att.txt
                ;;
            4) print_table "$ANNOUNCEMENT_FILE" "Date Teacher Announcement" "Announcements" ;;
            5)
                grep ":$(echo $user_data | cut -d ":" -f1):" "$LOGIN_HISTORY_FILE" > temp_login.txt
                print_table "temp_login.txt" "Date Time Username Role Status Device" "Your Login History"
                rm -f temp_login.txt
                ;;
            6)
                logout_user "$username" "$role"
                break
                ;;
        esac
    done
}

# ================= MAIN MENU =================
while true; do
    clear
    draw_box "SYSTEM LOGIN MENU"
    echo -e "${GREEN}1) Admin${RESET}"
    echo -e "${GREEN}2) Teacher${RESET}"
    echo -e "${GREEN}3) Student${RESET}"
    echo -e "${GREEN}4) Forget Password${RESET}"
    echo -e "${GREEN}5) Exit${RESET}"

    read -p "Select: " ch
    case $ch in
        1) login_user admin && admin_dashboard ;;
        2) login_user teacher && teacher_dashboard ;;
        3) login_user student && student_dashboard ;;
        4) forget_password ;;
        5) exit ;;
        *) echo -e "${RED}Invalid option!${RESET}" ;;
    esac
done
