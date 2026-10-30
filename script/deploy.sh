#!/bin/sh
set -ex

echo "Deploy script started."

# TODO: 当日の環境に合わせて書き換える
PROJECT_ROOT=/home/isucon/webapp
APP_DIR=go                     # PROJECT_ROOTからの相対パス
APP_BINARY=isucondition        # go buildの出力名 (systemdのExecStartと合わせる)
APP_SERVICE=isucondition.go.service

LOG_BACKUP_DIR=/var/log/isucon

USER=isucon
KEY_OPTION="-A"

# TODO: ~/.ssh/configのHost名
WEB_SERVERS="isu03"
APP_SERVERS="isu03"
DB_SERVER="isu02"

BACKUP_TARGET_LIST="/var/log/nginx/access.log /var/log/nginx/error.log"

BRANCH=$1
if [ -z "$BRANCH" ]; then
  echo "you must set branch"
  exit 1
fi

# sed -n -r 's/^(LogFormat.*)(" combined)/\1 %D\2/p' /etc/httpd/conf/httpd.conf
echo "Stop Web Server"
for WEB_SERVER in $WEB_SERVERS
do
cat <<EOS | ssh $KEY_OPTION $USER@$WEB_SERVER sh
sudo systemctl stop nginx
EOS
done

echo "Stop Application Server"
for APP_SERVER in $APP_SERVERS
do
cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
sudo systemctl stop $APP_SERVICE
EOS
done

echo "Stop DataBase Server"
cat <<EOS | ssh $KEY_OPTION $USER@$DB_SERVER sh
sudo systemctl stop mysql
EOS

echo "Get Current git hash"
for APP_SERVER in $APP_SERVERS
do
hash=`cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
cd $PROJECT_ROOT
git rev-parse --short HEAD
EOS`
echo "Current Hash: $hash"
done

set +e
LOG_DATE=`date +"%H%M%S"`
echo "Backup App Server LOG"
for LOG_PATH in $BACKUP_TARGET_LIST
do
    LOG_FILE=`basename $LOG_PATH`
for APP_SERVER in $APP_SERVERS
do
    cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
sudo mkdir -p ${LOG_BACKUP_DIR}
sudo mv $LOG_PATH ${LOG_BACKUP_DIR}/${LOG_FILE}_${LOG_DATE}_${hash}
EOS
done
done

cat <<EOS | ssh $KEY_OPTION $USER@$DB_SERVER sh
sudo rm -f /var/log/mysql/mysql-slow.log
EOS

set -e

echo "Current Hash: $hash"
echo "Update Project"
for APP_SERVER in $APP_SERVERS
do
cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
cd $PROJECT_ROOT
git clean -fd
git reset --hard
git fetch -p
git checkout $BRANCH
git pull --rebase
cd $APP_DIR
PATH=/home/isucon/local/go/bin:/usr/local/go/bin:/home/isucon/go/bin:/usr/bin go build -o $APP_BINARY .
EOS
done

cat <<EOS | ssh $KEY_OPTION $USER@$DB_SERVER sh
cd $PROJECT_ROOT
git clean -fd
git reset --hard
git fetch -p
git checkout $BRANCH
git pull --rebase
EOS

echo "Get new git hash"
for APP_SERVER in $APP_SERVERS
do
new_hash=`cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
cd $PROJECT_ROOT
git rev-parse --short HEAD
EOS`
echo "Current Hash: $new_hash"
done
echo "Start Database Server"
cat <<EOS | ssh $KEY_OPTION $USER@$DB_SERVER sh
sudo swapoff -a && sudo swapon -a
sudo systemctl start mysql
EOS
echo "Start App Server"
for APP_SERVER in $APP_SERVERS
do
cat <<EOS | ssh $KEY_OPTION $USER@$APP_SERVER sh
sudo swapoff -a && sudo swapon -a
sudo systemctl start $APP_SERVICE
EOS
done
echo "Start Web Server"
for WEB_SERVER in $WEB_SERVERS
do
cat <<EOS | ssh $KEY_OPTION $USER@$WEB_SERVER sh
sudo swapoff -a && sudo swapon -a
sudo systemctl start nginx
EOS
done
echo "Deploy script finished."
