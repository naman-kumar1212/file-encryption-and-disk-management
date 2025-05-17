#!/bin/bash

# Detect package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# Install missing dependencies
install_dependencies() {
    local missing_deps=("$@")
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    if [[ "$pkg_manager" == "unknown" ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="No supported package manager found (apt, dnf).\nPlease install the following dependencies manually:\n$(printf '• %s\n' "${missing_deps[@]}")" \
            --button="Exit:1"
        log_message "No supported package manager found for installing dependencies"
        exit 1
    fi
    
    # Map dependencies to package names
    local pkg_names=()
    for dep in "${missing_deps[@]}"; do
        case "$dep" in
            yad|gpg|zip|unzip|ncdu|watch|xterm|steghide)
                pkg_names+=("$dep")
                ;;
            df|du)
                pkg_names+=("coreutils")
                ;;
        esac
    done
    
    # Prompt user for confirmation
    yad --center --title="Install Dependencies" --image="dialog-question" \
        --text="The following dependencies are missing:\n$(printf '• %s\n' "${missing_deps[@]}")\n\nWould you like to install them using $pkg_manager?\nThis may require sudo privileges." \
        --button="Yes:0" --button="No:1"
    
    if [[ $? -ne 0 ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Dependency installation cancelled.\nPlease install the following dependencies manually:\n$(printf '• %s\n' "${missing_deps[@]}")" \
            --button="Exit:1"
        log_message "User cancelled dependency installation"
        exit 1
    fi
    
    # Install dependencies based on package manager
    log_message "Attempting to install dependencies: ${missing_deps[*]}"
    case "$pkg_manager" in
        apt)
            sudo apt update && sudo apt install -y "${pkg_names[@]}" 2>"$APP_DIR/install_error.log"
            ;;
        dnf)
            sudo dnf install -y "${pkg_names[@]}" 2>"$APP_DIR/install_error.log"
            ;;
    esac
    
    INSTALL_RESULT=$?
    if [[ $INSTALL_RESULT -eq 0 ]]; then
        log_message "Successfully installed dependencies: ${missing_deps[*]}"
        yad --center --title="Success" --image="dialog-information" \
            --text="Dependencies installed successfully!" --button="OK:0"
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Failed to install dependencies:\n$(cat "$APP_DIR/install_error.log")\nPlease install them manually." \
            --button="Exit:1"
        log_message "Failed to install dependencies. Error: $(cat "$APP_DIR/install_error.log")"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    for dep in yad gpg zip unzip df du watch xterm steghide; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Optional dependency: ncdu
    if ! command -v ncdu &> /dev/null; then
        missing_deps+=("ncdu")
        NCDU_AVAILABLE=false
    else
        NCDU_AVAILABLE=true
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        install_dependencies "${missing_deps[@]}"
    fi
}

# Create a temporary directory for the application
APP_DIR="$HOME/.file_locker"
mkdir -p "$APP_DIR"
touch "$APP_DIR/log.txt"
chmod 600 "$APP_DIR/log.txt"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$APP_DIR/log.txt"
}

# Hide data using steganography
hide_data_steg() {
    local image_file="$1"
    local data_file="$2"
    local text_input="$3"
    
    # Validate image file
    if [[ -z "$image_file" || ! -f "$image_file" || ! "$image_file" =~ \.(jpg|jpeg|png|bmp)$ ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Please select a valid image file (JPG, JPEG, PNG, or BMP)." --button="OK:0"
        return
    fi

    # Prepare data to hide
    local data_to_hide
    if [[ -n "$data_file" && -f "$data_file" ]]; then
        data_to_hide="$data_file"
    elif [[ -n "$text_input" ]]; then
        data_to_hide="$APP_DIR/steg_temp.txt"
        echo "$text_input" > "$data_to_hide"
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Please provide a data file or text to hide." --button="OK:0"
        return
    fi
    
    # Show progress dialog
    (
        echo "30"; echo "# Hiding data in image..."
        
        # Perform steganography
        steghide embed -cf "$image_file" -ef "$data_to_hide" -p "$PASS" -f 2>"$APP_DIR/steg_error.log"
        STEG_RESULT=$?
        
        # Clean up temporary file if created
        [[ -f "$data_to_hide" && "$data_to_hide" == "$APP_DIR/steg_temp.txt" ]] && rm -f "$data_to_hide"
        
        if [[ $STEG_RESULT -eq 0 ]]; then
            echo "100"; echo "# Data hidden successfully!"
            log_message "Successfully hid data in: $image_file"
        else
            echo "100"; echo "# Hiding data failed!"
            log_message "Failed to hide data in: $image_file. Error: $(cat "$APP_DIR/steg_error.log")"
        fi
    ) | yad --center --progress --title="Hiding Data" --width=300 --auto-close --auto-kill
    
    # Show result
    if [[ $STEG_RESULT -eq 0 ]]; then
        yad --center --title="Success" --image="dialog-information" \
            --text="Data hidden successfully in:\n$image_file" --button="OK:0"
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Failed to hide data:\n$(cat "$APP_DIR/steg_error.log")" --button="OK:0"
    fi
}

# Extract data using steganography
extract_data_steg() {
    local image_file="$1"
    
    # Validate image file
    if [[ -z "$image_file" || ! -f "$image_file" || ! "$image_file" =~ \.(jpg|jpeg|png|bmp)$ ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Please select a valid image file (JPG, JPEG, PNG, or BMP)." --button="OK:0"
        return
    fi
    
    # Create output directory
    local output_dir="$APP_DIR/steg_output"
    mkdir -p "$output_dir"
    
    # Show progress dialog
    (
        echo "30"; echo "# Extracting data from image..."
        
        # Perform steganography extraction
        steghide extract -sf "$image_file" -p "$PASS" -xf "$output_dir/extracted_data" -f 2>"$APP_DIR/steg_error.log"
        STEG_RESULT=$?
        
        if [[ $STEG_RESULT -eq 0 ]]; then
            echo "100"; echo "# Data extracted successfully!"
            log_message "Successfully extracted data from: $image_file to $output_dir/extracted_data"
        else
            echo "100"; echo "# Extraction failed!"
            log_message "Failed to extract data from: $image_file. Error: $(cat "$APP_DIR/steg_error.log")"
        fi
    ) | yad --center --progress --title="Extracting Data" --width=300 --auto-close --auto-kill
    
    # Show result
    if [[ $STEG_RESULT -eq 0 ]]; then
        yad --center --title="Success" --image="dialog-information" \
            --text="Data extracted successfully to:\n$output_dir/extracted_data" \
            --button="OK:0" --button="Open Folder:1"
        [[ $? -eq 1 ]] && xdg-open "$output_dir" &
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Failed to extract data:\n$(cat "$APP_DIR/steg_error.log")" --button="OK:0"
    fi
}

# GUI-based disk usage monitoring
show_disk_usage_gui() {
    log_message "GUI-based disk usage monitoring started"
    
    # Script to display disk usage
    DISPLAY_SCRIPT="$APP_DIR/disk_usage_display.sh"
    cat > "$DISPLAY_SCRIPT" << 'EOF'
#!/bin/bash
clear
echo "=== File Locker: Disk Usage Dashboard ==="
echo "Updated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Partition usage with df
echo "Partition Usage (df):"
echo "---------------------"
warning=false
while IFS= read -r line; do
    if [[ "$line" =~ ^/dev/ ]]; then
        filesystem=$(echo "$line" | awk '{print $1}')
        used=$(echo "$line" | awk '{print $3}')
        available=$(echo "$line" | awk '{print $4}')
        use_percent=$(echo "$line" | awk '{print $5}' | tr -d '%')
        mount=$(echo "$line" | awk '{print $6}')
        
        if [[ -n "$use_percent" && "$use_percent" =~ ^[0-9]+$ ]]; then
            bar_length=20
            filled=$((use_percent * bar_length / 100))
            empty=$((bar_length - filled))
            progress_bar=$(printf "%${filled}s" | tr ' ' '#')
            progress_bar+=$(printf "%${empty}s" | tr ' ' '-')
            
            echo "$mount ($filesystem): $use_percent% [$progress_bar]"
            
            if [[ $use_percent -gt 80 ]]; then
                warning=true
                echo "WARNING: $mount is over 80% full!"
            fi
        else
            echo "Skipping $mount: Invalid usage data"
        fi
    fi
done < <(df -h --output=source,used,avail,pcent,target 2>/dev/null | grep -v '^tmpfs\|^devtmpfs')

echo ""

# Directory usage with du
echo "Top 5 Directories in $HOME (du):"
echo "--------------------------------"
du -sh "$HOME"/* 2>/dev/null | sort -hr | head -n 5 | while read -r size path; do
    echo "$size  $path"
done

echo ""

# Warning and cleanup advice
if [[ $warning == true ]]; then
    echo "⚠️ High disk usage detected! Consider cleaning up unnecessary files:"
    echo "- Delete temporary files in /tmp"
    echo "- Clear old logs in /var/log"
    echo "- Remove unused applications"
fi
EOF
    
    chmod +x "$DISPLAY_SCRIPT"
    
    # Check for ncdu and show option if available
    if [[ $NCDU_AVAILABLE == true ]]; then
        yad --center --title="Disk Usage Options" --image="dialog-information" \
            --text="Choose an action for disk usage monitoring:" \
            --button="View Dashboard:0" --button="Launch ncdu:1" --button="Cancel:2"
        
        RESPONSE=$?
        if [[ $RESPONSE -eq 1 ]]; then
            log_message "Launching ncdu in GUI terminal"
            xterm -hold -e "ncdu $HOME" &
            return
        elif [[ $RESPONSE -eq 2 ]]; then
            log_message "Disk usage monitoring cancelled"
            return
        fi
    fi
    
    # Check for high usage and show warning
    local high_usage=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^/dev/ ]]; then
            use_percent=$(echo "$line" | awk '{print $5}' | tr -d '%')
            if [[ -n "$use_percent" && "$use_percent" =~ ^[0-9]+$ && $use_percent -gt 80 ]]; then
                high_usage=true
                break
            fi
        fi
    done < <(df -h --output=source,used,avail,pcent,target 2>/dev/null | grep -v '^tmpfs\|^devtmpfs')
    
    if [[ $high_usage == true ]]; then
        yad --center --title="Warning" --image="dialog-warning" \
            --text="One or more partitions are over 80% full!\nConsider cleaning up unnecessary files to maintain system efficiency." \
            --button="Continue:0" --button="Cancel:1"
        [[ $? -eq 1 ]] && return
    fi
    
    # Launch GUI terminal with watch
    log_message "Launching disk usage dashboard in GUI terminal"
    xterm -hold -e "watch -n 5 $DISPLAY_SCRIPT" &
}

# Start the application
start_app() {
    log_message "Application started"
    
    # Main menu
    while true; do
        ACTION=$(yad --center --title="File Locker" --width=600 --height=400 \
            --text="<b>File Locker</b>\nSecure your files with encryption, hide data in images, or monitor disk usage" \
            --image="dialog-password" --form \
            --field="Action:CB" \
            --field="Encryption Method:CB" \
            --field="File Selection:FL" \
            --field="Image Selection:FL" \
            --field="Data File:FL" \
            --field="Text Input:TXT" \
            --button="About:2" --button="Disk Usage:3" --button="Exit:1" --button="Continue:0" \
            "Lock!Unlock!Hide Data!Extract Data" "GPG (Strong)!ZIP (Simple)" "" "" "" "")
        
        EXIT_CODE=$?
        
        # Handle different button responses
        if [[ $EXIT_CODE -eq 1 || $EXIT_CODE -eq 252 ]]; then
            log_message "Application closed"
            exit 0
        elif [[ $EXIT_CODE -eq 2 ]]; then
            show_about
            continue
        elif [[ $EXIT_CODE -eq 3 ]]; then
            show_disk_usage_gui
            continue
        elif [[ $EXIT_CODE -ne 0 ]]; then
            log_message "Application closed with unexpected exit code: $EXIT_CODE"
            exit 0
        fi
        
        # Parse form data
        IFS='|' read -r ACTION METHOD FILE_PATH IMAGE_PATH DATA_FILE TEXT_INPUT <<< "$ACTION"
        
        # Process based on selected action
        case "$ACTION" in
            "Lock"|"Unlock")
                if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
                    yad --center --title="Error" --image="dialog-error" \
                        --text="Please select a valid file to $ACTION." --button="OK:0"
                    continue
                fi
                if [[ "$METHOD" != "GPG (Strong)" && "$METHOD" != "ZIP (Simple)" ]]; then
                    yad --center --title="Error" --image="dialog-error" \
                        --text="Please select a valid encryption method (GPG or ZIP)." --button vincitore
                    continue
                fi
                if [[ "$ACTION" == "Lock" ]]; then
                    log_message "Lock operation: $FILE_PATH"
                    [[ "$METHOD" == "GPG (Strong)" ]] && lock_file_gpg "$FILE_PATH" || lock_file_zip "$FILE_PATH"
                else
                    log_message "Unlock operation: $FILE_PATH"
                    [[ "$METHOD" == "GPG (Strong)" ]] && unlock_file_gpg "$FILE_PATH" || unlock_file_zip "$FILE_PATH"
                fi
                ;;
            "Hide Data")
                log_message "Hide data operation: $IMAGE_PATH"
                hide_data_steg "$IMAGE_PATH" "$DATA_FILE" "$TEXT_INPUT"
                ;;
            "Extract Data")
                log_message "Extract data operation: $IMAGE_PATH"
                extract_data_steg "$IMAGE_PATH"
                ;;
        esac
    done
}

# Lock file using GPG
lock_file_gpg() {
    local file="$1"
    local filename=$(basename "$file")
    local output_file="${file}.gpg"
    
    # Get password
    PASSWORD=$(yad --center --title="Set Password for GPG Encryption" --image="dialog-password" \
        --text="Set a strong password to encrypt the file:\n<b>$filename</b>" \
        --form --field="Password:H" --field="Confirm Password:H" "" "")
    
    EXIT_CODE=$?
    [[ $EXIT_CODE -ne 0 ]] && return
    
    IFS='|' read -r PASS CONFIRM <<< "$PASSWORD"
    
    # Check if passwords match
    if [[ "$PASS" != "$CONFIRM" ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Passwords do not match!" --button="OK:0"
        return
    fi
    
    # Check if password is empty
    if [[ -z "$PASS" ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Password cannot be empty!" --button="OK:0"
        return
    fi
    
    # Show progress dialog
    (
        echo "30"; echo "# Encrypting file with GPG..."
        
        # Perform GPG encryption
        echo "$PASS" | gpg --batch --yes --passphrase-fd 0 -c --cipher-algo AES256 -o "$output_file" "$file" 2>"$APP_DIR/gpg_error.log"
        GPG_RESULT=$?
        
        if [[ $GPG_RESULT -eq 0 ]]; then
            echo "100"; echo "# Encryption complete!"
            log_message "Successfully encrypted: $file to $output_file"
        else
            echo "100"; echo "# Encryption failed!"
            log_message "Failed to encrypt: $file. Error: $(cat "$APP_DIR/gpg_error.log")"
        fi
    ) | yad --center --progress --title="Encrypting File" --width=300 --auto-close --auto-kill
    
    # Show result
    if [[ $GPG_RESULT -eq 0 ]]; then
        yad --center --title="Success" --image="dialog-information" \
            --text="File encrypted successfully!\nOutput: $output_file" \
            --button="OK:0" --button="Delete Original:2"
        
        if [[ $? -eq 2 ]]; then
            rm -f "$file"
            log_message "Original file deleted: $file"
            yad --center --title="File Deleted" --image="dialog-information" \
                --text="Original file has been deleted." --button="OK:0"
        fi
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Failed to encrypt the file:\n$(cat "$APP_DIR/gpg_error.log")" \
            --button="OK:0"
    fi
}

# Unlock file using GPG
unlock_file_gpg() {
    local file="$1"
    local filename=$(basename "$file")
    local output_file="${file%.gpg}"
    
    # Check if file has .gpg extension
    if [[ "$file" != *.gpg ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="The selected file does not appear to be a GPG encrypted file.\nIt should have a .gpg extension." \
            --button="OK:0"
        return
    fi
    
    # Get password
    PASSWORD=$(yad --center --title="Enter Password" --image="dialog-password" \
        --text="Enter the password to decrypt the file:\n<b>$filename</b>" \
        --form --field="Password:H" "")
    
    EXIT_CODE=$?
    [[ $EXIT_CODE -ne 0 ]] && return
    
    IFS='|' read -r PASS <<< "$PASSWORD"
    
    # Check if password is empty
    if [[ -z "$PASS" ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Password cannot be empty!" --button="OK:0"
        return
    fi
    
    # Show progress dialog
    (
        echo "30"; echo "# Decrypting file with GPG..."
        
        # Perform GPG decryption
        echo "$PASS" | gpg --batch --yes --passphrase-fd 0 -d -o "$output_file" "$file" 2>"$APP_DIR/gpg_error.log"
        GPG_RESULT=$?
        
        if [[ $GPG_RESULT -eq 0 ]]; then
            echo "100"; echo "# Decryption complete!"
            log_message "Successfully decrypted: $file to $output_file"
        else
            echo "100"; echo "# Decryption failed!"
            log_message "Failed to decrypt: $file. Error: $(cat "$APP_DIR/gpg_error.log")"
        fi
    ) | yad --center --progress --title="Decrypting File" --width=300 --auto-close --auto-kill
    
    # Show result
    if [[ $GPG_RESULT -eq 0 ]]; then
        yad --center --title="Success" --image="dialog-information" \
            --text="File decrypted successfully!\nOutput: $output_file" \
            --button="OK:0" --button="Delete Encrypted:2"
        
        if [[ $? -eq 2 ]]; then
            rm -f "$file"
            log_message "Encrypted file deleted: $file"
            yad --center --title="File Deleted" --image="dialog-information" \
                --text="Encrypted file has been deleted." --button="OK:0"
        fi
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Failed to decrypt the file:\n$(cat "$APP_DIR/gpg_error.log")" \
            --button="OK:0"
    fi
}

# Lock file using ZIP
lock_file_zip() {
    local file="$1"
    local filename=$(basename "$file")
    local dir=$(dirname "$file")
    local output_file="${dir}/${filename%.zip}.zip"
    
    # Get password
    PASSWORD=$(yad --center --title="Set Password for ZIP Encryption" --image="dialog-password" \
        --text="Set a password to encrypt the file:\n<b>$filename</b>" \
        --form --field="Password:H" --field="Confirm Password:H" "" "")
    
    EXIT_CODE=$?
    [[ $EXIT_CODE -ne 0 ]] && return
    
    IFS='|' read -r PASS CONFIRM <<< "$PASSWORD"
    
    # Check if passwords match
    if [[ "$PASS" != "$CONFIRM" ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Passwords do not match!" --button="OK:0"
        return
    fi
    
    # Check if password is empty
    if [[ -z "$PASS" ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Password cannot be empty!" --button="OK:0"
        return
    fi
    
    # Show progress dialog
    (
        echo "10"; echo "# Preparing to create encrypted ZIP..."
        
        # Create temporary password file
        PASS_FILE=$(mktemp "$APP_DIR/tmp_pass_XXXXXX")
        chmod 600 "$PASS_FILE"
        echo "$PASS" > "$PASS_FILE"
        
        echo "50"; echo "# Creating encrypted ZIP file..."
        
        # Create encrypted ZIP
        zip -j -e --password "$(cat "$PASS_FILE")" "$output_file" "$file" 2>"$APP_DIR/zip_error.log"
        ZIP_RESULT=$?
        
        # Clean up password file
        rm -f "$PASS_FILE"
        
        if [[ $ZIP_RESULT -eq 0 ]]; then
            echo "100"; echo "# Encryption complete!"
            log_message "Successfully created encrypted ZIP: $output_file"
        else
            rm -f "$output_file" 2>/dev/null
            echo "100"; echo "# Encryption failed!"
            log_message "Failed to create encrypted ZIP: $output_file. Error: $(cat "$APP_DIR/zip_error.log")"
        fi
    ) | yad --center --progress --title="Creating Encrypted ZIP" --width=300 --auto-close --auto-kill
    
    # Show result
    if [[ $ZIP_RESULT -eq 0 ]]; then
        yad --center --title="Success" --image="dialog-information" \
            --text="File encrypted successfully!\nOutput: $output_file" \
            --button="OK:0" --button="Delete Original:2"
        
        if [[ $? -eq 2 ]]; then
            rm -f "$file"
            log_message "Original file deleted: $file"
            yad --center --title="File Deleted" --image="dialog-information" \
                --text="Original file has been deleted." --button="OK:0"
        fi
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Failed to create encrypted ZIP:\n$(cat "$APP_DIR/zip_error.log")" \
            --button="OK:0"
    fi
}

# Unlock file using ZIP
unlock_file_zip() {
    local file="$1"
    local filename=$(basename "$file")
    local dir=$(dirname "$file")
    
    # Check if file has .zip extension
    if [[ "$file" != *.zip ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="The selected file does not appear to be a ZIP file.\nIt should have a .zip extension." \
            --button="OK:0"
        return
    fi
    
    # Get password
    PASSWORD=$(yad --center --title="Enter Password" --image="dialog-password" \
        --text="Enter the password to extract the ZIP file:\n<b>$filename</b>" \
        --form --field="Password:H" "")
    
    EXIT_CODE=$?
    [[ $EXIT_CODE -ne 0 ]] && return
    
    IFS='|' read -r PASS <<< "$PASSWORD"
    
    # Check if password is empty
    if [[ -z "$PASS" ]]; then
        yad --center --title="Error" --image="dialog-error" \
            --text="Password cannot be empty!" --button="OK:0"
        return
    fi
    
    # Show progress dialog
    (
        echo "30"; echo "# Extracting ZIP file..."
        
        # Create temporary password file
        PASS_FILE=$(mktemp "$APP_DIR/tmp_pass_XXXXXX")
        chmod 600 "$PASS_FILE"
        echo "$PASS" > "$PASS_FILE"
        
        # Extract ZIP file to the same directory
        unzip -o -P "$(cat "$PASS_FILE")" "$file" -d "$dir" 2>"$APP_DIR/unzip_error.log"
        UNZIP_RESULT=$?
        
        # Clean up password file
        rm -f "$PASS_FILE"
        
        if [[ $UNZIP_RESULT -eq 0 ]]; then
            echo "100"; echo "# Extraction complete!"
            log_message "Successfully extracted ZIP: $file to $dir"
        else
            echo "100"; echo "# Extraction failed!"
            log_message "Failed to extract ZIP: $file. Error: $(cat "$APP_DIR/unzip_error.log")"
        fi
    ) | yad --center --progress --title="Extracting ZIP" --width=300 --auto-close --auto-kill
    
    # Show result
    if [[ $UNZIP_RESULT -eq 0 ]]; then
        yad --center --title="Success" --image="dialog-information" \
            --text="ZIP file extracted successfully!\nFiles extracted to: $dir" \
            --button="OK:0" --button="Delete ZIP:2" --button="Open Folder:3"
        
        RESPONSE=$?
        if [[ $RESPONSE -eq 2 ]]; then
            rm -f "$file"
            log_message "ZIP file deleted: $file"
            yad --center --title="File Deleted" --image="dialog-information" \
                --text="ZIP file has been deleted." --button="OK:0"
        elif [[ $RESPONSE -eq 3 ]]; then
            xdg-open "$dir" &
        fi
    else
        yad --center --title="Error" --image="dialog-error" \
            --text="Failed to extract the ZIP file:\n$(cat "$APP_DIR/unzip_error.log")" \
            --button="OK:0"
    fi
}

# Show about dialog
show_about() {
    yad --center --title="About File Locker" \
        --image="dialog-password" \
        --text="<b>File Locker</b>\nVersion 1.0\n\nA simple GUI tool to lock/unlock files using GPG or ZIP, hide/extract data in images using steganography, and monitor disk usage.\n\nSupports:\n• GPG encryption (stronger security)\n• ZIP password protection (wider compatibility)\n• Steganography with steghide (hide data in images)\n• Disk usage monitoring with du, df, and ncdu (if installed)" \
        --button="Close:0"
}

# Main function
main() {
    # Check dependencies
    check_dependencies
    
    # Parse command line arguments
    case "$1" in
        "--about")
            show_about
            exit 0
            ;;
        "--disk-usage")
            show_disk_usage_gui
            exit 0
            ;;
        "--hide-steg")
            shift
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 --hide-steg <image_file> <data_file> [text_input]"
                exit 1
            fi
            hide_data_steg "$1" "$2" "$3"
            exit 0
            ;;
        "--extract-steg")
            shift
            if [[ $# -lt 1 ]]; then
                echo "Usage: $0 --extract-steg <image_file>"
                exit 1
            fi
            extract_data_steg "$1"
            exit 0
            ;;
    esac
    
    # Start the main application
    start_app
}

# Run the main function
main "$@"
