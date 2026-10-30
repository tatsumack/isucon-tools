---
name: isucon-setup
description: ISUCONの競技開始直後に、サーバ上のアプリのコードとミドルウェアの設定ファイルを当日のGitHubリポジトリに上げ、全サーバと手元を同じリポジトリで管理できる状態にする。「初動セットアップして」「/isucon-setup」などで使う。
---

# 競技開始直後のリポジトリ作成

## 前提 (ユーザーが済ませておくこと)
- `~/.ssh/config` の `isu1` `isu2` `isu3` の HostName をポータルのIPに書き換えてある (User isucon, ForwardAgent yes)
- 当日のリポジトリ: `git@github.com:tatsumack/isucon2026.git` (private, 空)
- 手元のcloneパス: `~/git/github.com/tatsumack/isucon2026`

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

**2-2. .gitignore を作る**

- Goのビルド成果物 (systemdの ExecStart のバイナリ名)
- Go以外の実装ディレクトリ (`node/`, `ruby/`, `php/`, `python/`, `rust/`, `perl/` など)。Claudeが読むコードを減らすため
- `node_modules/`, `.DS_Store`, `*.log`
- **50MB以上のファイル** (`find . -size +50M -not -path './.git/*'` で探す。GitHubは100MB超を拒否する)。初期データのSQLダンプなどが該当しやすい。除外したファイルは報告する

**2-3. commitしてpushする**

```
ssh -o StrictHostKeyChecking=accept-new -T git@github.com   # 認証確認 (exit code 1でも "successfully authenticated" なら可)
cd /home/isucon/webapp
git init -b main
git config user.name isucon && git config user.email isucon@example.com
git add -A && git status --short | head -50
git commit -m "initial"
git remote add origin git@github.com:tatsumack/isucon2026.git
git push -u origin main
```

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
git status --short
```

- `git status` が空なら isu1 と同じ状態。`git checkout -B main origin/main` で追跡ブランチを設定する
- 差分がある場合 (env.shのホスト固有の値など) は内容をユーザーに報告し、判断を仰ぐ。勝手に破棄しない

### 4. 手元にcloneしてClaude用の設定を入れる
```
git clone git@github.com:tatsumack/isucon2026.git ~/git/github.com/tatsumack/isucon2026
cd ~/git/github.com/tatsumack/isucon2026
mkdir -p .claude/skills
cp -r <isucon-toolsのパス>/dot/claude/skills/bench-analyze .claude/skills/
echo "bench-results/" >> .gitignore
git add -A && git commit -m "Claude Code用のスキルを追加" && git push
```

その後、全サーバで `git pull` して手元と揃える。

### 5. 報告する
次をまとめてユーザーに出力する。
- 環境調査の結果 (OS, CPU, メモリ, 言語, DB, サービス名, アプリのポート)
- リポジトリの構成と、.gitignore で除外したもの
- isu2/isu3 の差分の有無
- isucon-toolsの `script/deploy.sh` / `script/bench-capture.sh` / `etc/*` のTODOに入れるべき値 (サービス名、バイナリ名、パス)

## 守ること
- `/etc` 配下の設定を書き換えない。サービスの再起動もしない (このスキルは記録だけ)
- `git reset --hard`、`git clean`、`git push --force` を使わない
- 秘密鍵をサーバにコピーしない (GitHubへはForwardAgentで認証する)
- 想定外の状況ではその場で止まってユーザーに確認する
