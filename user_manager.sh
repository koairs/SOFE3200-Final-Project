#!/bin/bash

##############################################
#   USER ACCOUNT MANAGEMENT SCRIPT
##############################################

LOGFILE="./logs/script.log"

mkdir -p logs

root_check() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root."
        exit 1
    fi
}

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

user_exists() {
    id "$1" &>/dev/null
    return $?
}

add_user() {
    echo "------ Add New User ------"
    read -p "Enter username: " username

    if user_exists "$username"; then
        echo "ERROR: User already exists."
        return
    fi

    read -p "Enter full name: " fullname
    read -s -p "Enter password: " password
    echo
    read -p "Enter shell (default /bin/bash): " shell
    [[ -z "$shell" ]] && shell="/bin/bash"

    useradd -m -c "$fullname" -s "$shell" "$username"
    echo "$username:$password" | chpasswd

    echo "User '$username' added successfully."
    log_action "Added user: $username"
}

delete_user() {
    echo "------ Delete User ------"
    read -p "Enter username: " username

    if ! user_exists "$username"; then
        echo "ERROR: User does not exist."
        return
    fi

    read -p "Delete home dir also? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        userdel -r "$username"
    else
        userdel "$username"
    fi

    echo "User '$username' deleted."
    log_action "Deleted user: $username"
}

modify_user() {
    echo "------ Modify User ------"
    read -p "Enter username: " username

    if ! user_exists "$username"; then
        echo "ERROR: User does not exist."
        return
    fi

    while true; do
        echo
        echo "1. Change password"
        echo "2. Change full name"
        echo "3. Change shell"
        echo "4. Add to group"
        echo "5. Remove from group"
        echo "6. Return to main menu"
        read -p "Enter option: " opt

        case $opt in
            1)
                read -s -p "Enter new password: " newpass
                echo
                echo "$username:$newpass" | chpasswd
                echo "Password updated."
                log_action "Password changed for $username"
                ;;
            2)
                read -p "Enter new full name: " newname
                chfn -f "$newname" "$username"
                echo "Full name updated."
                log_action "Fullname changed for $username"
                ;;
            3)
                read -p "Enter new shell: " newshell
                usermod -s "$newshell" "$username"
                echo "Shell updated."
                log_action "Shell changed for $username"
                ;;
            4)
                read -p "Enter group to add: " group
                usermod -aG "$group" "$username"
                echo "Added to group."
                log_action "Added $username to $group"
                ;;
            5)
                read -p "Enter group to remove: " group
                gpasswd -d "$username" "$group"
                echo "Removed from group."
                log_action "Removed $username from $group"
                ;;
            6) return ;;
            *) echo "Invalid option" ;;
        esac
    done
}

list_users() {
    echo "------ System Users ------"
    cat /etc/passwd
    log_action "Listed users"
}

main_menu() {
    while true; do
        echo
        echo "============================="
        echo "  USER ACCOUNT MANAGEMENT"
        echo "============================="
        echo "1. Add User"
        echo "2. Delete User"
        echo "3. Modify User"
        echo "4. List Users"
        echo "5. Exit"
        read -p "Enter choice: " choice

        case $choice in
            1) add_user ;;
            2) delete_user ;;
            3) modify_user ;;
            4) list_users ;;
            5) exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

root_check
main_menu
