#!/bin/sh
set -ex

ARCH=$(dpkg --print-architecture) # amd64 or arm64

sudo apt-get update
sudo apt-get install -y unzip graphviz sysstat percona-toolkit # pt-query-digestは/usr/binに入る

# dstat: Ubuntu 24.04にはパッケージが無いので失敗しても続行する(代わりにsysstatのvmstat/iostat/sarを使う)
sudo apt-get install -y dstat || echo "dstat is not available. use vmstat/iostat instead."

# alp
ALP_VERSION=1.0.22
cd /var/tmp && wget -q https://github.com/tkuchiki/alp/releases/download/v${ALP_VERSION}/alp_linux_${ARCH}.tar.gz
tar -zxf alp_linux_${ARCH}.tar.gz alp
sudo mv ./alp /usr/local/bin

# ssh
# TODO: GitHubアカウント名に置き換える (https://github.com/<user>.keys で公開鍵を取得)
GITHUB_USERS=""
sudo mkdir -p /home/isucon/.ssh
sudo touch /home/isucon/.ssh/authorized_keys
for GITHUB_USER in $GITHUB_USERS
do
    curl -fsSL https://github.com/${GITHUB_USER}.keys | sudo tee -a /home/isucon/.ssh/authorized_keys > /dev/null
done
sudo chown -R isucon:isucon /home/isucon/.ssh/
sudo chmod 700 /home/isucon/.ssh
sudo chmod 600 /home/isucon/.ssh/authorized_keys
