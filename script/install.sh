#!/bin/sh
set -ex

# nginx
sudo yum install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx

# alp
cd /var/tmp/ && wget https://github.com/tkuchiki/alp/releases/download/v0.4.0/alp_linux_amd64.zip
unzip alp_linux_amd64.zip
mv ./alp /usr/local/bin

# pt-query-digest
cd /var/tmp && wget https://www.percona.com/downloads/percona-toolkit/3.0.13/binary/tarball/percona-toolkit-3.0.13_x86_64.tar.gz
tar -zxvf percona-toolkit-3.0.13_x86_64.tar.gz
mv ./percona-toolkit-3.0.13/bin/pt-query-digest /usr/local/bin

# ssh
cat << _EOS > /tmp/authorized_keys
ssh-rsa hogehoge
_EOS
sudo cat /home/isucon/.ssh/authorized_keys >> /tmp/authorized_keys
sudo mkdir -p /home/isucon/.ssh
sudo mv /tmp/authorized_keys /home/isucon/.ssh/
sudo chown -R isucon.isucon /home/isucon/.ssh/
sudo chmod 600 /home/isucon/.ssh/authorized_keys
