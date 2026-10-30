---
name: bench-analyze
description: ISUCONでベンチマーク実行中のサーバを計測し、終了後にボトルネックを分析して報告する。「ベンチ分析して」「/bench-analyze isu1」などで使う。
---

# ベンチマーク計測・分析

引数: 対象ホスト名 (`~/.ssh/config` のHost名。例: `isu1`)。省略時はユーザーに聞く。
DBを別ホストに分離している場合は `isu1 db=isu3` のようにDBホストも渡される。

## 前提
- リポジトリ直下の `bench-capture.sh` (isucon-toolsの `script/bench-capture.sh`) のTODOが埋まっていて、deploy.shで対象サーバに配布されていること
- アプリに `net/http/pprof` が仕込まれていること (無くてもalp/slow logだけで分析する)

## 手順

### 1. 計測を開始する
次のコマンドを **`run_in_background: true` で** 実行し、すぐにユーザーへ「計測を開始しました。ベンチを開始してください」と伝える。

```
ssh <host> /home/isucon/webapp/bench-capture.sh 70   # deploy.shのPROJECT_ROOTに合わせる
```

- 計測はベンチより少し長い70秒。ベンチ時間が違う場合はユーザーの指示に合わせる
- 完了通知が来るまで待つ。sleepやポーリングはしない
- 最終行に出力される結果ディレクトリ (例: `/home/isucon/bench/153012`) を控える

### 2. 結果を取得する
```
mkdir -p bench-results
scp -r <host>:<結果ディレクトリ> bench-results/<host>-<HHMMSS>
```

DBが別ホストの場合は、DBホストでslow logを集計して取得する。
```
ssh <dbhost> "sudo pt-query-digest --limit 15 /var/log/mysql/mysql-slow.log" > bench-results/<host>-<HHMMSS>/slow.txt
```

### 3. 分析する
次の順で読む。生ログ (access.log, mysql-slow.log) は読まない。

1. `pidstat.txt` / `vmstat.txt` — どのプロセス (mysqld / アプリ / nginx) がCPUを使っているか、CPUが張り付いているか、iowaitがあるか
2. `alp.txt` — SUM (合計時間) が大きいエンドポイント上位。COUNTとAVGも見て「遅い」のか「多い」のかを区別する
3. `slow.txt` — Rank上位のクエリ。Rows examine / Rows sent の比が大きいものはインデックス不足を疑う
4. `pprof_cum.txt` / `pprof_flat.txt` — アプリ内で時間を使っている関数。`main.` で始まるものに注目する

その後、上位のエンドポイント・クエリ・関数についてアプリのコードを読み、原因箇所を `file:line` で特定する。
必要なら `ssh <host> "go tool pprof -list 'main\.<関数名>' <APP_BINARY> <結果ディレクトリ>/cpu.pb.gz"` で行単位の内訳を見る。

`bench-results/` に前回の結果がある場合は比較し、改善・悪化したものを示す。

### 4. 報告する
次の形式で `bench-results/<host>-<HHMMSS>/report.md` に保存し、同じ内容をユーザーに出力する。

```
## 概況
- ボトルネックの所在: DB / アプリCPU / nginx / 外部待ち など (根拠の数値つき)
- 前回比: (前回がある場合)

## ボトルネック上位 (最大5件、効果が大きい順)
### 1. <短いタイトル>
- 根拠: alp/slow/pprofの数値
- 原因箇所: file:line
- 対策案: 具体的な変更内容
- 期待効果: 大/中/小 とその理由
- リスク: 仕様を壊す可能性、整合性の注意点 (キャッシュの無効化タイミングなど)
```

## 守ること
- **分析だけ行い、コードの変更・デプロイはしない。** 対策をどれから入れるかは人間が決める
- サーバ上でサービスの再起動、設定変更、`/initialize` の実行をしない
- 数値の根拠がない推測は「推測」と明記する
- 計測が失敗したもの (pprof_error.txt がある、ファイルが空など) は報告の冒頭で伝える
