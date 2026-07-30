# `laravel/pao` の「全件パスでも終了コード 1」は v1.1.3 で上流修正済み。手順書と docs/stack.md の記述が陳腐化している

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-30

## 何が起きたか

Phase 1 手順書 Step 9-4 は「`php artisan test` は全件パスでも終了コードが 1 になる（`laravel/pao`
上流のバグ）」を**既知事象として断定**し、`docs/stack.md` も「`laravel/pao` は `laravel new` の
既定生成物で、v1.1.2（Packagist の最新版）で未修正。上げて回避することはできない」と書いている。

2026-07-30 のトライアルでは `laravel new` が `laravel/pao` **v1.1.3**（2026-07-29 リリース）を
引き、`php artisan test` は**終了コード 0** で完了した。pao は有効（出力が Agent 向け JSON 1 行）
なので、無効化により再現しなかったわけではない。

## 根拠

`php artisan test` の出力（Bash ツールはエラー終了時に `Exit code N` を付けるが、付かなかった
＝終了コード 0）:

```
{"tool":"pest","result":"passed","tests":26,"passed":26,"assertions":76,"duration_ms":2151}
```

インストールされた版:

```
$ composer show laravel/pao | head -20
name     : laravel/pao
descrip. : Agent-optimized output for PHP testing tools
versions : * v1.1.3
released : 2026-07-29, this week
```

上流に重複ガードが入っている（手順書が「pao 側にだけ無い」と書いていたもの）:

```
$ grep -rn "no-output" vendor/laravel/pao/src/
vendor/laravel/pao/src/Drivers/Pest/Plugin.php:32:        if (! in_array('--no-output', $arguments, true)) {
vendor/laravel/pao/src/Drivers/Pest/Plugin.php:33:            $arguments[] = '--no-output';
vendor/laravel/pao/src/Drivers/Phpunit/Starter.php:36:        if (! in_array('--no-output', $argv, true)) {
vendor/laravel/pao/src/Drivers/Phpunit/Starter.php:37:            $argv[] = '--no-output';
```

`composer.json` に `laravel new` が書いた制約は `"laravel/pao": "^1.0.6"`（下限が v1.1.3 未満）。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:389`（Step 9-4 の
  既知事象ブロック）、同 `:448`（完了基準「終了コードでは判定しない」）
- 関連ファイル: `my-laravel-app/docs/stack.md`（「`laravel/pao` の既知の不具合（v1.1.2 時点）」の段落）
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase4-finalize.md`（カバレッジ `--min`
  の失敗が握りつぶされる、という同根の記述がある場合は同時に見直しが必要）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の**バージョン・環境の陳腐化**に当たる。記述を消すか、制約の下限を
`^1.1.3` に引き上げるかは方針判断であり、下限を上げると `laravel new` 既定の生成物へ手を
入れることになる（Phase 1 の「やらないこと」との兼ね合いも要る）。

## 選択肢

1. **記述を「v1.1.2 以前の既知事象」として過去形に書き換えるだけ**（制約は既定のまま `^1.0.6`）
   — 影響: 手順書・`docs/stack.md`・完了基準の 3 か所の文言修正のみ。/ 懸念: `composer.lock` を
   持たない新規クローンや `composer update` の巻き戻しで v1.1.2 が入る余地が残り、そのときは
   終了コード 1 が再発する。ただし記述が残っているので原因はたどれる。
2. **Step 5 に `composer require laravel/pao:^1.1.3 --dev` 相当を追加して下限を固定し、記述を
   削除する** — 影響: 終了コードで合否判定できるようになり、手順書から例外規定が消える。/
   懸念: `laravel new` 既定の依存へ手を入れる前例になる。Laravel 側が pao の制約を上げた時点で
   このピン留めが冗長になる。
3. **記述をそのまま残す** — 影響: 変更なし。/ 懸念: 「終了コードでは判定しない」という誤った
   指示が残り、本物の失敗を Claude Code が見逃す経路になる（今後は終了コードが信頼できるため、
   ここを無視する運用は害の方が大きい）。

## 推奨

案 1。上流が修正済みなら追随の主体は Laravel 側で、テンプレートが依存制約をピン留めして
面倒を抱える理由が薄い。記述を残して原因の追跡可能性だけ確保するのが費用対効果が高い。

## 決めてほしいこと

案 1（記述を過去形に直すだけ）で進めてよいか。それとも案 2（`laravel/pao` の下限を `^1.1.3` に
ピン留めして記述を削除）にするか。

## 暫定対応

なし。終了コード 0 で通ったため回避策は不要で、テンプレート本体には手を入れていない
（Phase 1 の合否判定は手順書どおり JSON の `"result":"passed"` と件数で行った）。
