sudo tee /etc/yum.repos.d/swifteam.repo > /dev/null <<'EOF'
[swifteam]
name=Swifteam Repository
baseurl=https://swif-linux-package.s3.ap-southeast-1.amazonaws.com/fedora/beta/x86_64
enabled=1
gpgcheck=0
EOF

sudo dnf makecache
sudo dnf install swifteam

curl -OL https://cdn.swifteam.com/st-agent-linux/v1.300.0/swifteam_x64
sudo chmod +x swifteam_x64
sudo mv swifteam_x64 /usr/bin/swifteam

sudo /usr/bin/swifteam -doEnroll -teamId $TEAM_ID 