#!/bin/sh
set -x

# 前提
#  SSHのパスなし認証が通ること

# memo
# ssh -i ~/.ssh/isucon isucon@118.27.32.14
# ssh -i ~/.ssh/isucon isucon@118.27.29.82
# ssh -i ~/.ssh/isucon isucon@118.27.5.40    

echo "Deploy script started."

PROJECT_ROOT=/home/isucon/torb/webapp

LOG_BACKUP_DIR=/var/log/isucon

USER=isucon
KEY_OPTION="-i ~/.ssh/isucon8-qual"

WEB_SERVER=150.95.133.1
APP_SERVER=150.95.133.1
DB_SERVER=150.95.133.1

BACKUP_TARGET_LIST="/var/lib/mysql/mysqld-slow.log /var/log/h2o/access.log /var/log/h2o/error.log"

# echo "Update Project"
# cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
# cd $PROJECT_ROOT
# cd go
# # export PATH=/home/isucon/local/go/bin:/home/isucon/go/bin:$PATH
# # export GOROOT=/home/isucon/local/go
# PATH=/home/isucon/local/go/bin:/home/isucon/go/bin go version
# PATH=/home/isucon/local/go/bin:/home/isucon/go/bin:/usr/bin make build
# EOS
# exit

# sed -n -r 's/^(LogFormat.*)(" combined)/\1 %D\2/p' /etc/httpd/conf/httpd.conf
echo "Stop Web Server"
cat <<EOS | ssh $KEY_OPTION $USER@$WEB_SERVER sh
sudo systemctl stop h2o
EOS

echo "Stop Application Server"
cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
sudo systemctl stop torb.go
EOS

echo "Stop DataBase Server"
cat <<EOS | ssh $KEY_OPTION $USER@$DB_SERVER sh
sudo systemctl stop mariadb
EOS

echo "Get Current git hash"
hash=`cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
cd $PROJECT_ROOT
git rev-parse --short HEAD
EOS`
echo "Current Hash: $hash"

# LOG_DATE=`date +"%Y%m%d%H%M%S"`
LOG_DATE=`date +"%H%M%S"`
echo "Backup App Server LOG"
for LOG_PATH in $BACKUP_TARGET_LIST
do
    LOG_FILE=`basename $LOG_PATH`
    cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
sudo mkdir -p ${LOG_BACKUP_DIR}
sudo mv $LOG_PATH ${LOG_BACKUP_DIR}/${LOG_FILE}_${LOG_DATE}_${hash}
EOS
done

echo "Current Hash: $hash"

echo "Update Project"
cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
cd $PROJECT_ROOT
# git clean -fd
# git reset --hard
git pull origin master
cd go
PATH=/home/isucon/local/go/bin:/home/isucon/go/bin:/usr/bin make build
EOS

echo "Get new git hash"
new_hash=`cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
cd $PROJECT_ROOT
git rev-parse --short HEAD
EOS`
echo "Current Hash: $new_hash"


echo "Start Database Server"
cat <<EOS | ssh $KEY_OPTION $USER@$DB_SERVER sh
sudo systemctl start mariadb
EOS

echo "Start Database Server"
cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
sudo systemctl start torb.go
EOS

echo "Start Database Server"
cat <<EOS | ssh $KEY_OPTION $USER@$WEB_SERVER sh
sudo systemctl start h2o
EOS

echo "Deploy script finished."
