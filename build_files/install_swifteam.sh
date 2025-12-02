sudo tee /etc/yum.repos.d/swifteam.repo > /dev/null <<'EOF'
[swifteam]
name=Swifteam Repository
baseurl=https://swif-linux-package.s3.amazonaws.com/fedora/beta/x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://swif-linux-package.s3.amazonaws.com/RPM-GPG-KEY-swifteam.pub
EOF



sudo dnf makecache
sudo dnf install swifteam -y
sudo dnf upgrade swifteam -y

sudo /usr/bin/swifteam -oneShot -teamId $TEAM_ID -groupIds $GROUP_ID
