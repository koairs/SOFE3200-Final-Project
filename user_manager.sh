#!/bin/bash
# USER ACCOUNT MANAGEMENT SCRIPT

# Configuration & Setup
LOGFILE="./logs/script.log"
mkdir -p logs

# Helper Functions
# Function to display script introduction and usage
script_introduction() {
    echo "Welcome to the User Account Management System!"
    echo "This script provides an interactive menu for managing local"
    echo "user and group accounts on a Linux system."
    echo ""
    echo "USAGE NOTES:"
    echo "* This script **must** be run as the root user."
    echo "* All changes are logged to $LOGFILE."
    echo "========================================================"
    read -r -p "Press [ENTER] to continue to the Main Menu..."
}

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

group_exists() {
    getent group "$1" &>/dev/null
    return $?
}

add_user() {
    echo "------ Add New User ------"
    read -p "Enter username: " username

    if [[ -z "$username" ]]; then
        echo "ERROR: Username cannot be empty."
        return 1
    fi

    if user_exists "$username"; then
        echo "ERROR: User '$username' already exists."
        return 1
    fi

    read -p "Enter full name: " fullname
    read -s -p "Enter password: " password
    echo
    read -p "Enter shell (default /bin/bash): " shell
    [[ -z "$shell" ]] && shell="/bin/bash"

    # Execute useradd and check return code
    useradd -m -c "$fullname" -s "$shell" "$username"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create user '$username'."
        log_action "FAILURE: Failed to create user $username"
        return 1
    fi
    
    echo "$username:$password" | chpasswd
    if [[ $? -ne 0 ]]; then
        echo "WARNING: User created, but failed to set password."
        log_action "WARNING: User $username created, but password set failed."
    else
        echo "User '$username' added successfully."
        log_action "Added user: $username"
    fi
}

delete_user() {
    echo "------ Delete User ------"
    read -p "Enter username: " username

    if [[ -z "$username" ]]; then
        echo "ERROR: Username cannot be empty."
        return 1
    fi

    if ! user_exists "$username"; then
        echo "ERROR: User '$username' does not exist."
        return 1
    fi

    read -p "Delete home dir also? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        userdel -r "$username"
    else
        userdel "$username"
    fi

    if [[ $? -eq 0 ]]; then
        echo "User '$username' deleted."
        log_action "Deleted user: $username (Removed home: $confirm)"
    else
        echo "ERROR: Failed to delete user '$username'."
        log_action "FAILURE: Failed to delete user $username"
    fi
}

modify_user() {
    echo "------ Modify User ------"
    read -p "Enter username: " username

    if ! user_exists "$username"; then
        echo "ERROR: User '$username' does not exist."
        return 1
    fi

    while true; do
        echo
        echo "--- Modify '$username' ---"
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
                if [[ $? -eq 0 ]]; then
                    echo "Password updated."
                    log_action "Password changed for $username"
                else
                    echo "ERROR: Failed to update password."
                    log_action "FAILURE: Password change failed for $username"
                fi
                ;;
            2)
                read -p "Enter new full name: " newname
                chfn -f "$newname" "$username"
                 if [[ $? -eq 0 ]]; then
                    echo "Full name updated."
                    log_action "Fullname changed for $username"
                else
                    echo "ERROR: Failed to change full name."
                fi
                ;;
            3)
                read -p "Enter new shell: " newshell
                usermod -s "$newshell" "$username"
                if [[ $? -eq 0 ]]; then
                    echo "Shell updated."
                    log_action "Shell changed for $username"
                else
                    echo "ERROR: Failed to change shell."
                fi
                ;;
            4)
                read -p "Enter group to add: " group
                if ! group_exists "$group"; then
                    echo "ERROR: Group '$group' does not exist. Create it first."
                    continue
                fi
                usermod -aG "$group" "$username"
                if [[ $? -eq 0 ]]; then
                    echo "Added to group '$group'."
                    log_action "Added $username to $group"
                else
                    echo "ERROR: Failed to add user to group."
                fi
                ;;
            5)
                read -p "Enter group to remove: " group
                if ! group_exists "$group"; then
                    echo "ERROR: Group '$group' does not exist."
                    continue
                fi
                gpasswd -d "$username" "$group"
                if [[ $? -eq 0 ]]; then
                    echo "Removed from group '$group'."
                    log_action "Removed $username from $group"
                else
                    echo "ERROR: Failed to remove user from group."
                fi
                ;;
            6) return ;;
            *) echo "Invalid option" ;;
        esac
    done
}

add_group() {
    echo "------ Add New Group ------"
    read -p "Enter new group name: " groupname

    if group_exists "$groupname"; then
        echo "ERROR: Group '$groupname' already exists."
        return 1
    fi
    
    groupadd "$groupname"
    
    if [[ $? -eq 0 ]]; then
        echo "Group '$groupname' created successfully."
        log_action "Added group: $groupname"
    else
        echo "ERROR: Failed to create group '$groupname'."
        log_action "FAILURE: Failed to create group $groupname"
    fi
}

group_menu() {
    while true; do
        echo
        echo "  GROUP MANAGEMENT  "
        echo "1. Create New Group"
        echo "2. List Standard Groups (GID >= 1000)"
        echo "3. Return to Main Menu"
        read -p "Enter choice: " choice

        case $choice in
            1) add_group ;;
            2) 
                echo "------ Standard Groups (GID >= 1000) ------"
                # Filter groups where the GID ($3) is 1000 or greater.
                awk -F: '($3 >= 1000) { print $1 }' /etc/group | sort
                log_action "Listed standard groups (GID >= 1000)" 
                ;;
            3) return ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

manage_permissions() {
    echo "------ Manage File Permissions ------"
    read -p "Enter file or directory path: " target
    
    if [[ ! -e "$target" ]]; then
        echo "ERROR: Path '$target' does not exist."
        return 1
    fi
    
    read -p "Enter new permissions (such as 755 or u+x): " perms
    
    chmod "$perms" "$target"
    
    if [[ $? -eq 0 ]]; then
        echo "Permissions for '$target' set to '$perms'."
        log_action "Set permissions $perms on $target"
    else
        echo "ERROR: Failed to set permissions for '$target'. Check syntax."
        log_action "FAILURE: Failed to set permissions $perms on $target"
    fi
}

list_users() {
    echo "------ All User Accounts   ------"
    # Use 'cat' as specified in the project requirements
    cat /etc/passwd
    log_action "Listed all users from /etc/passwd (raw)"
}

main_menu() {
    while true; do
        echo
        echo "  USER ACCOUNT MANAGEMENT  "
        echo "1. Add User"
        echo "2. Delete User"
        echo "3. Modify User Attributes"
        echo "4. Group Management"
        echo "5. List Users"
        echo "6. Manage Permissions"
        echo "7. Exit"
        read -p "Enter choice: " choice

        case $choice in
            1) add_user ;;
            2) delete_user ;;
            3) modify_user ;;
            4) group_menu ;;
            5) list_users ;; 
            6) manage_permissions ;; 
            7) exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

# Execution Start
root_check
script_introduction
main_menu
