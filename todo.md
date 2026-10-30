# 方針
- 1台1人で割り当てて並行開発する(各自Claudeで実装 → 自分のマシンで検証)
- 役割はふんわり分けてオーバーラップOK。マージ・ベンチはMeet/Slackで声かけしながら進める
- 複数台構成への切り替えは遅めにするが、12時台に一度お試し分離して手順を確立しておく
- 午前中に誰か1人はマニュアル・スコア計算・ベンチログを深く読む(上位チームの差はマッチングなど仕様理解だった)
- 1案に時間を溶かしすぎない(1時間で効果が見えなければ撤退を検討)

## 作業宣言ルール(必須)
着手前に必ずSlackに1行流す。撤退も書く。

```
[着手] isu1 / feat/nearby-chairs-n1 / nearby-chairs の N+1 解消
[結果] isu1 / feat/nearby-chairs-n1 / 12,300 → 15,800 ✅ マージ可
[撤退] isu2 / feat/matching-v2 / スコア変化なし、理由: ◯◯
```

## Claude運用
- Claudeは手元で動かし、deploy.shで反映する(サーバ上での利用はレギュレーションで許可されている場合のみ)
- 1施策 = 1ブランチ = 1セッション
- 生ログではなく alp.log / pt-query-digest / `go tool pprof -top` などのテキストを渡す
- `/initialize` の挙動やレスポンスJSONの形を変えさせない。キャッシュは無効化タイミングを確認する
- ベンチが通ったら `git tag good-HHMM` を打つ

# 開始直後

## 全員
- [ ] レギュレーションを読む
  - AI利用・外部通信のルール
  - サーバ台数・スペック
  - ベンチの同時実行数、対象サーバの選び方
  - 再起動試験・追試の条件
- [ ] 当日マニュアルを読み、スコア計算とベンチマーカーのログに出るヒントを確認する
- [ ] マシンの割り当てを決める(isu1/isu2/isu3 → 誰)

## インフラ担当
- [ ] 何もせずにベンチマークを流す
- [ ] Go実装に切り替えてベンチマークを流す
- [ ] アプリケーション配下、/etc/配下をgit init
- [ ] コードをリポジトリにpushする
- [ ] ssh鍵を登録する
- [ ] alpをインストール
- [ ] pt-query-digestをインストール
- [ ] access_logをltsvにする
- [ ] alp, slowqueryの計測する
- [ ] デプロイスクリプトを使えるようにする 
  - https://github.com/tatsumack/isucon-tools/blob/master/script/deploy.sh
- [ ] 秘伝のタレを適用する
- [ ] ハードウェアの構成を調べる(CPU、メモリ)
- [ ] 環境を確認してdeploy.sh/nginx.conf/my.cnfのTODOを埋める
  - OSバージョン/アーキテクチャ(`cat /etc/os-release`, `dpkg --print-architecture`)
  - Goのバージョンとパス(`which go`)
  - MySQLかMariaDBか(`mysql --version`)とslow logの設定場所
  - アプリのsystemdサービス名(`systemctl list-units --type=service | grep isu`)とポート
  - nginxでTLS終端しているか(`listen 443 ssl`)
- [ ] 動作しているプロセスを確認しておおよその構成を理解する
  - DB側でworker/matcherなどが動いていないか(複数台化でハマるポイント)
- [ ] 3台すべてで同じ状態から各自が作業できるようにする
- [ ] SEE ALSO: https://gist.github.com/south37/d4a5a8158f49e067237c17d13ecab12a

## アプリケーション担当1
- [ ] データサイズ確認 https://github.com/tatsumack/isucon-tools/blob/master/cmd/mysql
- [ ] コードを読む(Claudeにエンドポイント・テーブル・重い処理の一覧を作らせる)
- [ ] 実際に使ってみる
- [ ] パスの一覧を共有
- [ ] スキーマ一覧を共有
- [ ] キーになる関数があれば特定する
- [ ] pprofを仕込む https://github.com/tatsumack/isucon-tools/blob/master/cmd/pprof
- [ ] ベンチ分析をClaudeに任せられるようにする
  - [ ] 当日リポジトリの `bench-capture.sh` のTODOを埋めてdeploy.shで配布する (スキル・`.gitignore` は当日リポジトリに準備済み)
  - 使い方: Claudeに `/bench-analyze isu1` → 「計測を開始しました」と出たらベンチを開始

## アプリケーション担当2
- [ ] ローカルで開発環境を構築(30分以上かかるなら諦める)

# 12時台
- [ ] 複数台構成をお試しで分離する(Claudeに手順書/スクリプトを作らせる)
  - [ ] ベンチが通ることを確認
  - [ ] 手順を残して並行開発の体制に戻す

# 15:00〜16:00
- [ ] 複数台構成に本番切り替え
- [ ] 複数台向けにnginx/MySQL/コネクション数の設定を見直す

# 終盤
- [ ] 17:15 機能的な変更のマージを締め切り
- [ ] 17:15 アクセスログを切る
- [ ] 17:15 slow queryを切る
- [ ] 17:15 フレームワークのdebugモードをOFF
- [ ] 17:15〜17:40 パラメータ調整のみ(ポーリング間隔、プール数など)
- [ ] 17:40 再起動をしてベンチを実行せずにアプリケーションが動くことを確認する
- [ ] 17:40 再起動をしてベンチが通ることを確認する(最終ベンチ。終了間際はキューが混むので早めに)
- [ ] 17:50以降は何も触らない
