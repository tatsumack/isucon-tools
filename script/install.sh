#!/bin/sh
set -ex

sudo apt-get install -y dstat unzip

# alp
cd /var/tmp/ && wget https://github.com/tkuchiki/alp/releases/download/v0.4.0/alp_linux_amd64.zip
unzip alp_linux_amd64.zip
sudo mv ./alp /usr/local/bin

# pt-query-digest
cd /var/tmp && wget https://www.percona.com/downloads/percona-toolkit/3.0.13/binary/tarball/percona-toolkit-3.0.13_x86_64.tar.gz
tar -zxvf percona-toolkit-3.0.13_x86_64.tar.gz
sudo mv ./percona-toolkit-3.0.13/bin/pt-query-digest /usr/local/bin

# slackcat
cd /var/tmp && wget https://github.com/bcicen/slackcat/releases/download/v1.6/slackcat-1.6-linux-amd64
sudo mv slackcat-1.6-linux-amd64 /usr/local/bin/slackcat
sudo chmod +x /usr/local/bin/slackcat

# ssh
cat << _EOS > /tmp/authorized_keys
ssh-rsa hoge
_EOS
sudo mkdir -p /home/isucon/.ssh
chmod 700 /home/isucon/.ssh
sudo cat /tmp/authorized_keys >> /home/isucon/.ssh/authorized_keys
sudo mv /tmp/authorized_keys /home/isucon/.ssh/
sudo chown -R isucon.isucon /home/isucon/.ssh/
sudo chmod 600 /home/isucon/.ssh/authorized_keys
