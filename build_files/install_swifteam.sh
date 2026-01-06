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

########################################################
# Run Swifteam
########################################################

sudo /usr/bin/swifteam -oneShot -teamId $TEAM_ID -groupIds $GROUP_ID

########################################################
# Prepare swifteam files
########################################################

# Function to move files from a source path to a target prefix/path
# - If source is a directory, all files inside are moved, preserving structure
# - If source is a file, that single file is moved to the target path
# Usage: move_files_to_swifteam <source_path> <target_prefix_or_path>
move_files_to_swifteam() {
    local source_path="$1"
    local target_prefix="$2"

    # If source is a directory, move all contents preserving structure
    if [ -d "$source_path" ]; then
        for f in "$source_path"/*; do
            if [ -e "$f" ]; then
                # Remove source_path prefix and add target_prefix
                relative_path="${f#$source_path}"
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
        return 0
    fi

    # If source is a file, move that single file
    if [ -f "$source_path" ]; then
        local target="$target_prefix"
        echo "Moving file $source_path to $target"
        sudo mkdir -p "$(dirname "$target")"
        sudo mv -f "$source_path" "$target"
        return 0
    fi

    echo "Source $source_path does not exist, skipping."
    return 0
}

# Define source paths and their target prefixes/paths
# Format: "source_path:target_prefix_or_path"
# Add more paths here as needed
# Process all defined paths
MOVE_PATHS=(
    "/var/lib/swifteam:/etc/swifteam/var/lib/swifteam"
)
for path_mapping in "${MOVE_PATHS[@]}"; do
    source_dir="${path_mapping%%:*}"
    target_prefix="${path_mapping##*:}"
    move_files_to_swifteam "$source_dir" "$target_prefix"
done

echo "Finished moving files"


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

# Find all files in /etc/swifteam recursively and move them to their corresponding paths
SCRIPT_PATH="$SWIFTEAM_DIR/move_swifteam_files.sh"
# Use -type f to only find files, not directories
find "$SWIFTEAM_DIR" -mindepth 1 -type f | while read -r item; do
    # Skip moving the script itself
    if [ "$item" = "$SCRIPT_PATH" ]; then
        continue
    fi
    
    # Get the relative path (remove /etc/swifteam prefix)
    relative_path="${item#$SWIFTEAM_DIR/}"
    target_path="/$relative_path"
    
    # If target file already exists, skip it
    if [ -f "$target_path" ]; then
        echo "Target file $target_path already exists, skipping $item"
        continue
    fi
    
    # Create parent directory if it doesn't exist
    target_parent=$(dirname "$target_path")
    if [ ! -d "$target_parent" ]; then
        mkdir -p "$target_parent"
    fi
    
    # Move the file
    if [ -f "$item" ]; then
        echo "Copying $item to $target_path"
        cp -f "$item" "$target_path"
    fi
done

echo "Finished copying files from $SWIFTEAM_DIR"
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
# Install Systemcheck
########################################################

SWIFTEAM_VERSION=$(/usr/bin/swifteam -version 2>&1 | head -n 1 | awk '{print $NF}')
echo "Detected swifteam version: $SWIFTEAM_VERSION"

# ----------------------------
# Config
# ----------------------------
SWIFTEAM_VERSION="${SWIFTEAM_VERSION:?SWIFTEAM_VERSION is not set}"
ARCH="x64"
NAME="systemcheck"
RPM_RELEASE="1"
WORKDIR="$(pwd)/systemcheck-build"

SYSTEMCHECK_URL="https://cdn.swifteam.com/st-agent-linux/v${SWIFTEAM_VERSION}/systemcheck_${ARCH}"

echo "▶ Swifteam version: ${SWIFTEAM_VERSION}"
echo "▶ Download URL: ${SYSTEMCHECK_URL}"
echo "▶ Working dir: ${WORKDIR}"

# ----------------------------
# Prepare build environment
# ----------------------------
dnf install -y \
  rpm-build \
  rpmdevtools \
  curl \
  systemd

rpmdev-setuptree

mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# ----------------------------
# Download binary
# ----------------------------
echo "▶ Downloading systemcheck binary"
curl -fL -o systemcheck "${SYSTEMCHECK_URL}"
chmod 0755 systemcheck

# ----------------------------
# Prepare RPM sources
# ----------------------------
cp systemcheck ~/rpmbuild/SOURCES/systemcheck

# ----------------------------
# Generate RPM spec
# ----------------------------
SPEC_FILE=~/rpmbuild/SPECS/systemcheck.spec

cat > "${SPEC_FILE}" <<EOF
Name:           systemcheck
Version:        ${SWIFTEAM_VERSION}
Release:        ${RPM_RELEASE}%{?dist}
Summary:        Swifteam system health check binary

License:        Proprietary
URL:            https://swifteam.com
Source0:        systemcheck

BuildArch:      x86_64
Requires:       systemd

%description
System health check binary used by Swifteam agent.

%prep
# nothing

%build
# nothing

%install
install -D -m 0755 %{SOURCE0} %{buildroot}/usr/bin/systemcheck

%files
/usr/bin/systemcheck

%changelog
* $(date +"%a %b %d %Y") Swifteam CI <ci@swifteam.com> - ${SWIFTEAM_VERSION}-${RPM_RELEASE}
- CI built RPM
EOF

# ----------------------------
# Build RPM
# ----------------------------
echo "▶ Building RPM"
rpmbuild -ba "${SPEC_FILE}"

RPM_PATH=$(ls ~/rpmbuild/RPMS/x86_64/systemcheck-"${SWIFTEAM_VERSION}"-"${RPM_RELEASE}"*.rpm)

echo "▶ RPM built: ${RPM_PATH}"

# ----------------------------
# Install RPM (image-level)
# ----------------------------
echo "▶ Installing RPM into image"
dnf install -y "${RPM_PATH}"

# ----------------------------
# Verify installation
# ----------------------------
echo "▶ Verifying installation"

echo "Binary path:"
which systemcheck

echo "Permissions:"
ls -l /usr/bin/systemcheck

echo "SELinux context:"
ls -Z /usr/bin/systemcheck

echo "RPM ownership:"
rpm -qf /usr/bin/systemcheck

echo "▶ systemcheck installation complete"