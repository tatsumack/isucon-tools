---
name: isucon-setup
description: ISUCONの競技開始直後に、サーバ上のアプリのコードとミドルウェアの設定ファイルを当日のGitHubリポジトリに上げ、全サーバと手元を同じリポジトリで管理してdeploy.shでデプロイできる状態にする。「初動セットアップして」「/isucon-setup」などで使う。
---

# 競技開始直後のリポジトリ作成

## 前提 (ユーザーが済ませておくこと)
- `~/.ssh/config` の `isu1` `isu2` `isu3` の HostName をポータルのIPに書き換えてある (User isucon, ForwardAgent yes)
- 当日のリポジトリ: `git@github.com:tatsumack/isucon2026.git` (private)
  - mainには事前に `CLAUDE.md`、`.claude/skills/bench-analyze/`、`deploy.sh`、`bench-capture.sh`、`.gitignore` が入っている。サーバのコードはこれに追加する形で取り込む

前提を満たしていなければ、ユーザーに伝えて止まる。

## 手順

### 1. 接続確認と環境調査 (読み取りのみ)
全ホストに `ssh <host> hostname` が通ることを確認する。続けて `isu1` で以下を調べ、結果を表にしてユーザーに報告する。

```
cat /etc/os-release | head -2; dpkg --print-architecture; nproc; free -h
ls -la /home/isucon /home/isucon/webapp
du -sh /home/isucon/webapp/* | sort -h
systemctl list-units --type=service --state=running | grep -E 'isu|nginx|mysql|maria|redis|memcached|h2o|envoy'
cat /etc/systemd/system/isu*.service
cat /home/isucon/env.sh 2>/dev/null
mysql --version; nginx -v; which go && go version
ls /etc/nginx/sites-enabled /etc/mysql /etc/mysql/*.d 2>/dev/null
```

- アプリのディレクトリ (通常 `/home/isucon/webapp`)、実装言語ごとのディレクトリ、systemdのサービス名、env.shの場所を特定する
- 想定と違う構成 (webappが無い、DBがMariaDB/PostgreSQL、nginx以外のプロキシなど) なら、以降の手順を読み替えてユーザーに確認する

### 2. isu1でリポジトリを作る
リポジトリのルートは `/home/isucon/webapp` とする。

**2-1. 設定ファイルをリポジトリにコピーする** (`/etc` 側は変更しない)

```
cd /home/isucon/webapp
mkdir -p etc/nginx etc/mysql etc/systemd
sudo cp -rL /etc/nginx/. etc/nginx/
sudo cp -rL /etc/mysql/. etc/mysql/
sudo cp /etc/systemd/system/isu*.service etc/systemd/
cp /home/isucon/env.sh etc/ 2>/dev/null || true
sudo chown -R isucon:isucon etc
```

手順1で見つかった他のミドルウェア (redis等) の設定も同様に `etc/<name>/` に入れる。

**2-2. リポジトリの既存の中身を取り込む**

```
ssh -o StrictHostKeyChecking=accept-new -T git@github.com   # 認証確認 (exit code 1でも "successfully authenticated" なら可)
cd /home/isucon/webapp
git init -b main
git config user.name isucon && git config user.email isucon@example.com
git remote add origin git@github.com:tatsumack/isucon2026.git
git fetch origin
git reset origin/main                       # --hard は使わない。作業ツリー (サーバのファイル) はそのまま
git ls-files -d | xargs -r git checkout --  # リポジトリにだけあるファイル (deploy.sh等) を展開する
git status --short | grep '^ M'             # サーバとリポジトリの両方にあるファイル
```

`M` と出たファイル (`.gitignore`、`README.md` など) はサーバ版が作業ツリーに残っている。`git show origin/main:<ファイル>` と見比べて、両方の内容を残す形でマージする。どちらかを捨てない。

**2-3. .gitignore に追記する**

- Goのビルド成果物 (systemdの ExecStart のバイナリ名)
- Go以外の実装ディレクトリ (`node/`, `ruby/`, `php/`, `python/`, `rust/`, `perl/` など)。Claudeが読むコードを減らすため
- `node_modules/`, `.DS_Store`, `*.log`
- **50MB以上のファイル** (`find . -size +50M -not -path './.git/*'` で探す。GitHubは100MB超を拒否する)。初期データのSQLダンプなどが該当しやすい。除外したファイルは報告する

**2-4. commitしてpushする**

```
git add -A && git status --short | head -50
git commit -m "サーバのコードと設定ファイルを取り込む"
git push -u origin main
```

origin/mainの上にコミットしているので通常のpushで通る。rejectされたら (誰かがmainにpushした)、`git pull --rebase` してから再度pushする。

pushの前に `git count-objects -vH` でサイズを確認し、100MBを大きく超える場合は止めてユーザーに相談する。

### 3. isu2, isu3 を同じリポジトリに紐づける
各サーバの初期状態は同じはずだが、上書きはしない。

```
cd /home/isucon/webapp
mkdir -p etc/nginx etc/mysql etc/systemd   # 2-1と同じコピーをする
(2-1のコピーコマンド)
git init -b main
git config user.name isucon && git config user.email isucon@example.com
git remote add origin git@github.com:tatsumack/isucon2026.git
git fetch origin
git reset origin/main          # --hard は使わない
git ls-files -d | xargs -r git checkout --   # リポジトリにだけあるファイルを展開する
git status --short
```

- `git status` が空なら isu1 と同じ状態。`git branch -u origin/main` で追跡ブランチを設定する
- 差分がある場合 (env.shのホスト固有の値など) は内容をユーザーに報告し、判断を仰ぐ。勝手に破棄しない

### 4. 手元にcloneしてdeploy.shとbench-capture.shのTODOを埋める
クローン先はユーザーに確認する。

```
git clone git@github.com:tatsumack/isucon2026.git <クローン先>
cd <クローン先>
```

`deploy.sh` や `bench-capture.sh` がリポジトリに無ければ (事前準備のPRが未マージなど)、isucon-toolsの `script/` からコピーし、`.claude/skills/bench-analyze` も `dot/claude/skills/` からコピーする。

`deploy.sh` の先頭のTODOを手順1の調査結果で埋める。
- `PROJECT_ROOT`: アプリのディレクトリ (通常 `/home/isucon/webapp`)
- `APP_DIR`: Go実装のディレクトリ (`PROJECT_ROOT` からの相対パス)
- `APP_BINARY`: systemdの `ExecStart` のバイナリ名と一致させる
- `APP_SERVICE`: Go実装のsystemdサービス名
- DBのサービス名が `mysql` 以外 (`mariadb` など) なら `systemctl stop/start mysql` の箇所も直す

`bench-capture.sh` の `APP_BINARY` もフルパス (`<PROJECT_ROOT>/<APP_DIR>/<APP_BINARY>`) で埋める。

```
git add -A && git commit -m "deploy.shとbench-capture.shを当日の環境に合わせる" && git push
```

### 5. デプロイが動くことを確認する
1台ずつ実行する。deploy.shはサーバ上で `git reset --hard` するので、手順3で差分が残っているホストには実行しない。

```
./deploy.sh main isu1
```

成功したら、そのホストで次を確認する。
```
ssh isu1 "systemctl is-active nginx mysql <APP_SERVICE>; cd /home/isucon/webapp && git log -1 --oneline && git status --short"
ssh isu1 "curl -sk -o /dev/null -w '%{http_code}\n' http://localhost/"   # nginxがTLSのみなら https://localhost/
```

- 3つとも `active`、`git log` が手元の最新コミット、`git status` が空、HTTPステータスが200系/300系であればOK
- isu2, isu3 にも同様に実行する
- 失敗したら、どこで止まったか (git / 設定反映 / `nginx -t` / go build / サービス起動) を特定して報告する。deploy.shは途中で失敗するとサービスが停止したままになるので、原因を直して再実行するか、`sudo systemctl start` で戻す
- 最後にユーザーへ「ポータルからisu1にベンチを流して、初期スコアと同程度で通るか確認してください」と伝える (ベンチはClaudeからは実行できない)

### 6. 報告する
次をまとめてユーザーに出力する。
- 環境調査の結果 (OS, CPU, メモリ, 言語, DB, サービス名, アプリのポート)
- リポジトリの構成と、.gitignore で除外したもの
- isu2/isu3 の差分の有無
- 各ホストのデプロイ結果
- isucon-toolsの `etc/*` (秘伝のタレ) のTODOに入れるべき値 (サービス名、バイナリ名、パス)

## 守ること
- 手順1〜4では `/etc` 配下の設定を書き換えない。サービスの再起動もしない (反映は手順5のdeploy.shだけで行う)
- deploy.sh以外で `git reset --hard`、`git clean`、`git push --force` を使わない
- 秘伝のタレ (isucon-toolsの `etc/*`) の適用はこのスキルではしない。初期状態のままデプロイが通ることだけを確認する
- 秘密鍵をサーバにコピーしない (GitHubへはForwardAgentで認証する)
- 想定外の状況ではその場で止まってユーザーに確認する
