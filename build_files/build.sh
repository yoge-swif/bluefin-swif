#!/bin/bash

set -ouex pipefail

echo "TEAM_ID: $TEAM_ID"
echo "NAME: $NAME"
echo "SURNAME: $SURNAME"
echo "EMAIL: $EMAIL"

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

curl -s -o /etc/swifteam.rpm https://swif-linux-package.s3.amazonaws.com/fedora/beta/x86_64/swifteam-1.297.0-beta.x86_64.rpm
sudo rpm -ivh /etc/swifteam.rpm