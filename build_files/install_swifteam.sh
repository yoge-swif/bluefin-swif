echo "TEAM_ID: $TEAM_ID"
echo "GROUP_ID: $GROUP_ID"
echo "LEVEL: $LEVEL"
echo "AGENT_URL: $AGENT_URL"
echo "SYSCHECK_URL: $SYSCHECK_URL"

########################################################
# Install Swifteam
########################################################

sudo tee /etc/yum.repos.d/swifteam.repo > /dev/null <<EOF
[swifteam]
name=Swifteam Repository
baseurl=https://swif-linux-package.s3.amazonaws.com/fedora/$LEVEL/x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://swif-linux-package.s3.amazonaws.com/RPM-GPG-KEY-swifteam.pub
EOF

sudo dnf makecache
sudo dnf install swifteam -y
sudo dnf upgrade swifteam -y

if [ -n "$AGENT_URL" ]; then
    echo "Downloading agent from AGENT_URL..."
    sudo curl -L "$AGENT_URL" -o /usr/bin/swifteam
    sudo chmod +x /usr/bin/swifteam
fi

if [ -n "$SYSCHECK_URL" ]; then
    echo "Downloading syscheck from SYSCHECK_URL..."
    sudo curl -L "$SYSCHECK_URL" -o /usr/bin/systemcheck
    sudo chmod +x /usr/bin/systemcheck
fi

########################################################
# Run Swifteam
########################################################

sudo /usr/bin/swifteam -oneShot -teamId $TEAM_ID -groupIds $GROUP_ID


########################################################
# Create Startup Service
########################################################

# Install the move script
sudo tee /etc/swifteam/move_swifteam_files.sh > /dev/null <<'EOF'
#!/bin/bash

# Script to move files from /etc/swifteam/{path} to {path}
# This script is called by the systemd service on boot

set -euo pipefail

SWIFTEAM_DIR="/etc/swifteam"

# Check if /etc/swifteam directory exists
if [ ! -d "$SWIFTEAM_DIR" ]; then
    echo "Directory $SWIFTEAM_DIR does not exist, nothing to move."
    exit 0
fi

# Find all files and directories in /etc/swifteam
# and move them to their corresponding paths in the root filesystem
find "$SWIFTEAM_DIR" -mindepth 1 -maxdepth 1 | while read -r item; do
    # Get the relative path (remove /etc/swifteam prefix)
    relative_path="${item#$SWIFTEAM_DIR/}"
    target_path="/$relative_path"
    
    # Create parent directory if it doesn't exist
    target_parent=$(dirname "$target_path")
    if [ ! -d "$target_parent" ]; then
        mkdir -p "$target_parent"
    fi
    
    # Move the file or directory
    if [ -e "$item" ]; then
        echo "Moving $item to $target_path"
        mv -f "$item" "$target_path"
    fi
done

echo "Finished moving files from $SWIFTEAM_DIR"
EOF
sudo chmod +x /etc/swifteam/move_swifteam_files.sh

# Install the systemd service
sudo tee /etc/systemd/system/swifteam-move.service > /dev/null <<'EOF'
[Unit]
Description=Move files from /etc/swifteam to root filesystem
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/etc/swifteam/move_swifteam_files.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable the service to run on boot
sudo systemctl enable swifteam-move.service


########################################################
# Prepare swifteam files
########################################################

# Function to move files from source directory to target prefix
# Usage: move_files_to_swifteam <source_dir> <target_prefix>
move_files_to_swifteam() {
    local source_dir="$1"
    local target_prefix="$2"
    
    if [ ! -d "$source_dir" ]; then
        echo "Source directory $source_dir does not exist, skipping."
        return 0
    fi
    
    for f in "$source_dir"/*; do
        if [ -e "$f" ]; then
            # Remove source_dir prefix and add target_prefix
            relative_path="${f#$source_dir}"
            target="${target_prefix}${relative_path}"
            
            echo "Moving $f to $target"
            if [ -d "$f" ]; then
                sudo mkdir -p "$target"
            else
                sudo mkdir -p "$(dirname "$target")"
            fi
            sudo mv -f "$f" "$target"
        fi
    done
}

# Define source directories and their target prefixes
# Format: "source_dir:target_prefix"
# Add more paths here as needed
MOVE_PATHS=(
    "/var/lib/swifteam:/etc/swifteam"
    # Add more paths here, for example:
    # "/opt/swifteam:/etc/swifteam"
    # "/tmp/swifteam:/etc/swifteam"
)

# Process all defined paths
for path_mapping in "${MOVE_PATHS[@]}"; do
    source_dir="${path_mapping%%:*}"
    target_prefix="${path_mapping##*:}"
    move_files_to_swifteam "$source_dir" "$target_prefix"
done

echo "Finished moving files"
