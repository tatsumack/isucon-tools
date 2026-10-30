#!/bin/bash
# ベンチ実行中の計測をまとめて行う (アプリサーバ上で実行する)
# 使い方: bench-capture.sh [計測秒数]
#   実行直後にベンチを開始する。終了後に結果ディレクトリのパスを出力する
set -eu

# TODO: 当日の環境に合わせて書き換える
APP_BINARY=/home/isucon/webapp/go/isucondition
PPROF_URL=http://localhost:6060/debug/pprof/profile
# TODO: パスパラメータを含むURIは -m でまとめる (analyze.shと揃える)
ALP_MATCHING_GROUPS=""
export PATH=/home/isucon/local/go/bin:/usr/local/go/bin:/home/isucon/go/bin:${PATH}

DURATION=${1:-70}
OUT=/home/isucon/bench/$(date "+%H%M%S")
mkdir -p ${OUT}

# 前回までのログが混ざらないようにリセットする
sudo truncate -s 0 /var/log/nginx/access.log
if [ -f /var/log/mysql/mysql-slow.log ]; then
    sudo truncate -s 0 /var/log/mysql/mysql-slow.log
fi

# 計測 (CPU全体 / プロセス別CPU / Goのプロファイル)
vmstat 1 ${DURATION} > ${OUT}/vmstat.txt &
pidstat -u 5 $((DURATION / 5)) > ${OUT}/pidstat.txt &
curl -s -o ${OUT}/cpu.pb.gz "${PPROF_URL}?seconds=${DURATION}" || echo "pprof failed" > ${OUT}/pprof_error.txt &
wait

# 集計
sudo /usr/local/bin/alp ltsv --file /var/log/nginx/access.log --sort sum -r ${ALP_MATCHING_GROUPS:+-m "$ALP_MATCHING_GROUPS"} > ${OUT}/alp.txt
if [ -f /var/log/mysql/mysql-slow.log ]; then
    sudo pt-query-digest --limit 15 /var/log/mysql/mysql-slow.log > ${OUT}/slow.txt
fi
if [ -s ${OUT}/cpu.pb.gz ]; then
    go tool pprof -top -cum -nodecount=40 ${APP_BINARY} ${OUT}/cpu.pb.gz > ${OUT}/pprof_cum.txt 2>&1
    go tool pprof -top -nodecount=40 ${APP_BINARY} ${OUT}/cpu.pb.gz > ${OUT}/pprof_flat.txt 2>&1
fi

echo ${OUT}
