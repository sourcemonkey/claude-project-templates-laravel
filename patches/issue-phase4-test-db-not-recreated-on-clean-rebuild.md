# クリーン再構築（down -v → composer run setup）後にテスト DB が存在せず php artisan test が落ちる

- フェーズ: Phase 4
- 状態: 未解決
- 初回観測: 2026-07-22

## 何が起きたか

Phase 4 手順書「6. 最終チェック」の手順 1〜2 を順に実行すると、手順 2 で
`php artisan test` が実行できない。

- 手順 1: `docker compose down -v` で DB をボリュームごと破棄 → `composer run setup`
- 手順 2: `php artisan test`

`docker compose down -v` は名前付きボリューム `db-data` を削除する。この時点で、
Phase 1 手順書 Step 9-1 で**手動作成した `bookkeeper_test` データベースも一緒に消える**。
続く `composer run setup` が作成するのは `compose.yaml` の `MYSQL_DATABASE=bookkeeper`
（開発用 DB）だけで、**`bookkeeper_test` は再作成されない**。

その結果、`phpunit.xml` が `DB_DATABASE=bookkeeper_test` を指しているため、手順 2 の
`php artisan test` が「Unknown database 'bookkeeper_test'」相当で全滅する。

同じことは**新規クローンの初回セットアップ**でも起きる。`composer run setup` を実行した
だけの状態では `bookkeeper_test` が無く、`php artisan test` が動かない。

## 根拠

`compose.yaml` は開発用 DB しか作らない（`bookkeeper_test` の作成は含まれない）:

- 関連ファイル: `my-laravel-app/compose.yaml`（`MYSQL_DATABASE: bookkeeper`）
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:314-318`
  （`bookkeeper_test` を `docker compose exec` で手動作成している）
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase4-finalize.md:83-92`
  （down -v → setup の直後に `php artisan test` を要求しているが、テスト DB の
  再作成手順が無い）

実際のトライアルでは、`docker compose down -v` → `composer run setup` の後に

```
SHOW DATABASES LIKE 'bookkeeper_test';
```

が空を返した（テスト DB が存在しない）。手動で再作成してから `php artisan test`（87 件）
が green になった。

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の振り分け基準のうち「妥当な解が複数あり、どれを採るかが方針の
選択になる」に当たる。`bookkeeper_test` を恒久的に用意する方法が複数あり、どれも
`compose.yaml`（テンプレート同梱・利用者の本番プロジェクトへ配布される）か
`composer run setup` の設計に踏み込むため、ヘッドレスの単独判断で選べない。

## 選択肢

1. **`compose.yaml` の初期化スクリプトで両 DB を作る** — `docker/mysql/` に
   `docker-entrypoint-initdb.d` 用の `init.sql`（`CREATE DATABASE bookkeeper_test ...`
   + `GRANT`）を置き、`compose.yaml` でマウントする。
   影響: 新規ボリュームなら常に両 DB が揃い、Phase 1 の手動作成手順（Step 9-1）も
   `composer run setup` 後の追加作業も不要になる。
   懸念: テスト用 DB が開発用 compose に載る。ただし本プロジェクトは「開発は Docker」
   前提なので齟齬は小さい。既存ボリュームには init スクリプトが効かない点に注意
   （`down -v` で作り直すクリーン再構築の文脈では問題にならない）。
2. **`composer run setup` にテスト DB 作成ステップを足す** — setup の先頭付近で
   `docker compose exec` により `bookkeeper_test` を作成する。
   影響: setup 一発で test DB まで揃う。
   懸念: setup（本番でも流用しうる初期化スクリプト）にテスト専用 DB の作成が混じる。
   `docker compose exec` を setup スクリプト内に書くと、Bash ツールの制約（複数操作・
   変数展開）に触れないか手順書側の検証が要る。
3. **手順書に「down -v 後は Phase 1 Step 9-1 の test DB 作成を再実行」と明記** —
   仕組みは変えず手順で補う。
   影響: 最小変更。
   懸念: 新規クローンの利用者が毎回手作業する必要が残り、「1 コマンドで動く」思想から外れる。

## 推奨

案 1。`docker-entrypoint-initdb.d` で両 DB を作れば、Phase 1 の手動作成も down -v 後の
再作成も不要になり、「クローンして 1 コマンドで動く」思想と最も整合する。あわせて
Phase 1 手順書 Step 9-1 の手動作成手順と `bookkeeper_test` 前提の記述を見直す必要がある。

## 決めてほしいこと

`bookkeeper_test` の作成を `compose.yaml` の初期化スクリプト（案 1）に移してよいか？
（Yes なら Phase 1 Step 9-1 の手動作成手順も削除・更新する）

## 暫定対応

トライアルを先に進めるため、`docker compose down -v` → `composer run setup` の後に
Phase 1 Step 9-1 と同じコマンドで `bookkeeper_test` を手動再作成した（テンプレート本体
への変更ではなく、その場の DB 操作のみ）。テンプレートには差分を入れていない。
