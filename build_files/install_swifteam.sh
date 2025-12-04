echo "TEAM_ID: $TEAM_ID"
echo "GROUP_ID: $GROUP_ID"
echo "LEVEL: $LEVEL"
echo "AGENT_URL: $AGENT_URL"

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

sudo /usr/bin/swifteam -oneShot -teamId $TEAM_ID -groupIds $GROUP_ID
