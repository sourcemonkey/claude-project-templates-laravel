# `laravel new` が `laravel/pao` を既定導入し、pint / phpstan / pest の出力が JSON になっている

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

Phase 1 Step 3 の `laravel new tmp-skeleton --no-interaction --pest` が生成した
スケルトンに、`docs/stack.md` のどの表にも記載のない `laravel/pao` が含まれていた。

このパッケージの影響で、Phase 1 Step 9 以降で実行する検証コマンドの出力形式が
人間可読なテーブルではなく **JSON 1 行**に変わっている。手順書の完了基準は
「違反 0」「エラー 0」「green」といった内容の判定なので実行自体は問題なく通るが、
手順書・`docs/stack.md` にはこの出力形式についての記載が一切ない。

## 根拠

`composer show laravel/pao` の出力（抜粋、原文）:

```
name     : laravel/pao
descrip. : Agent-optimized output for PHP testing tools
keywords : Agent, PHPStan, ai, dev, paratest, pest, php, phpunit, rector, testing
versions : * v1.1.2
released : 2026-06-22, 3 weeks ago
source   : [git] https://github.com/laravel/pao.git
requires
laravel/agent-detector ^2.0.2
php ^8.3
```

実際の出力（原文）:

```
$ vendor/bin/pint --test
{"tool":"pint","result":"passed"}

$ php artisan test
{"tool":"pest","result":"passed","tests":68,"passed":68,"assertions":129,"duration_ms":3130}

$ vendor/bin/phpstan analyse --memory-limit=512M
{"tool":"phpstan","result":"passed","errors":0}
```

生成された `laravel/framework` は `^13.8`（Phase 1 Step 3 のバージョン検証は通過）。

- 関連ファイル: `my-laravel-app/docs/stack.md` の「開発・テスト用」表
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:329`（Pint の確認手順）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「バージョン・環境の陳腐化」に当たる。フェーズは成功
しているため誤りの修正ではなく、`docs/stack.md` に記載するかどうかは方針判断。

## 選択肢

1. **`docs/stack.md` の「開発・テスト用」表に 1 行追加するだけ** — 影響: 記述と
   生成物のズレが解消する / 懸念: Phase 4 のカバレッジ判定（`php artisan test
   --coverage-html coverage`）で pao がどう出力するかは未検証のまま残る
2. **表に追加したうえで、Phase 4 のカバレッジ判定手順に「出力が JSON である前提」を
   書き込む** — 影響: Phase 4 の 80% 判定が確実になる / 懸念: Phase 4 を実際に
   走らせるまで正しい記述が書けない（本トライアルの対象は Phase 1〜2）
3. **`composer remove laravel/pao` してテンプレートから外す** — 影響: 出力が
   従来のテーブル形式に戻り、既存の記述がそのまま通じる / 懸念: `laravel new` の
   既定に逆らうことになり、Laravel 側の更新のたびに再度外す手間が生じる。また
   Claude Code がテスト結果を読む用途にはむしろ有利なパッケージである

## 推奨

案 1。Phase 4 未実行の段階で案 2 を書くと推測が入る。まず事実として表に載せ、
Phase 4 のトライアル時にカバレッジ出力を実測してから追記するのが安全。

## 決めてほしいこと

`docs/stack.md` の「開発・テスト用」表に `laravel/pao`（`laravel new` の既定に
含まれる、テストツールの Agent 向け出力）を追記してよいか。

## 暫定対応

なし（実行に支障がないためテンプレートへの変更は加えていない）。
