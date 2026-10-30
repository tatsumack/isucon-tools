#!/bin/bash
set -ex

LOG_DIR=/home/isucon/log
mkdir -p ${LOG_DIR}

# alp
# TODO: パスパラメータを含むURIは -m でまとめる (例: -m "^/api/users/[0-9]+$,^/api/events/[^/]+$")
ALP_MATCHING_GROUPS=""
if [ -f ${LOG_DIR}/alp.log ]; then
    sudo mv ${LOG_DIR}/alp.log ${LOG_DIR}/alp.log.$(date "+%Y%m%d_%H%M%S")
fi
sudo /usr/local/bin/alp ltsv --file /var/log/nginx/access.log --sort sum -r ${ALP_MATCHING_GROUPS:+-m "$ALP_MATCHING_GROUPS"} > ${LOG_DIR}/alp.log

# slow query
if [ -f ${LOG_DIR}/mysql-slow.log ]; then
    sudo mv ${LOG_DIR}/mysql-slow.log ${LOG_DIR}/mysql-slow.log.$(date "+%Y%m%d_%H%M%S")
fi
sudo pt-query-digest /var/log/mysql/mysql-slow.log > ${LOG_DIR}/mysql-slow.log
