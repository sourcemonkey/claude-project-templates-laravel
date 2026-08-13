# `php artisan serve --env=dusk.local` が稀に開発用 DB（`bookkeeper`）を参照する

- フェーズ: Phase 5
- 状態: 未分類
- 初回観測: 2026-08-14
- 実行モデル: claude-sonnet-5

## 何が起きたか

Phase 5 で Dusk シナリオを追加した後、`php artisan serve --env=dusk.local` を起動して
`php artisan dusk` を実行したところ、新規追加した `tests/Browser/AuthorizationTest.php` の
2 件が `signInAs()`（ログイン）の時点で失敗した（`Waited 5 seconds for location [/].`、
スクリーンショットには「認証に失敗しました。」というログインフォームのバリデーション
エラーが写っていた）。

原因調査のため `App\Livewire\Forms\LoginForm::authenticate()` に一時的に
`Log::debug()` を追加し、`config('database.connections.mysql.database')` を
記録したところ、失敗した 1 件だけ `"db":"bookkeeper"`（開発用 DB）を参照しており、
それ以外の全リクエスト（同じ `php artisan serve --env=dusk.local` プロセスに対する
別タイミングのリクエスト）は `"db":"bookkeeper_test"`（テスト用 DB、期待値）を
参照していた。Dusk のテストプロセス側は `phpunit.xml` の `DB_DATABASE=bookkeeper_test`
で一貫してテスト用 DB にユーザーを作成しているため、served 側が開発用 DB を見た
瞬間だけ「該当ユーザーが存在せず認証失敗」になる。

`php artisan serve` プロセスを一度停止し（`TaskStop` でバックグラウンドタスクを終了）、
新しいプロセスとして起動し直したところ、同じ Dusk スイート（9 件）を 3 回連続で
実行してもすべて green だった。再現条件を人為的に再現できておらず、原因は未特定。

## 根拠

```
{"tool":"pest","result":"failed","tests":9,"passed":8,"assertions":7,"duration_ms":38564,"errors":1,"error_details":[{"test":"P\\Tests\\Browser\\AuthorizationTest::__pest_evaluable_...","file":".../vendor/php-webdriver/webdriver/lib/WebDriverWait.php","line":71,"message":"Waited 5 seconds for location [/]."}]}
```

デバッグログ（`storage/logs/laravel.log`、一時的に追加した `Log::debug` の出力。該当 1 件のみ抜粋）:

```
[2026-08-13 23:41:56] local.DEBUG: DEBUG_AUTH_ATTEMPT {"email":"mai70@test.local","db":"bookkeeper","user_exists":false,"user_password":null}
```

同じログ機構で、直後の別実行では全リクエストが `"db":"bookkeeper_test"` になっていることを確認済み（後続 10 件はすべて `bookkeeper_test`）。

- 関連ファイル: `my-laravel-app/.env.dusk.local`（`APP_ENV=local` を明示的に設定している）
- 関連コード: `vendor/laravel/framework/src/Illuminate/Foundation/Console/ServeCommand.php`
  の `$passthroughVariables`（`APP_ENV` のみ子プロセスへ引き継がれ、`DB_DATABASE` 等は
  引き継がれない）と `vendor/laravel/framework/src/Illuminate/Foundation/Bootstrap/LoadEnvironmentVariables.php`
  の `checkForSpecificEnvironmentFile()`（`runningInConsole()` が偽になる `php -S`
  子プロセスでは `--env` 引数を見る経路が働かず、`Env::get('APP_ENV')` の値を使って
  `.env.{APP_ENV}` を探しに行く。`.env.local` は存在しないため、本来は素の `.env`
  にフォールバックするはずだが、大半のリクエストでは正しく `.env.dusk.local` 相当の
  `bookkeeper_test` を参照していた）。上記の理論は「常に発生する」ことを説明できて
  おらず、1 回しか観測できていない事象に対する**未検証の仮説**として書く。

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の振り分け基準のうち、「再現条件が不確か、または 1 回しか
観測できておらず、原因の特定に至っていない」に該当する。加えてテンプレートの
スコープを超える可能性がある（`php artisan serve --env=X` の子プロセスへの環境変数
引き継ぎという Laravel フレームワーク自体の挙動が絡む）。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

`.claude/commands/scaffold-phase4-ui-tests.md` / `scaffold-phase5-finalize.md` の
「Dusk 実行時の前提」に、「`php artisan serve --env=dusk.local` のログイン系テストが
原因不明のまま失敗した場合はサーバープロセスを再起動して切り分ける」旨の注意書きを
足すべきか。それとも 1 回しか再現していない事象として静観すべきか。

## 暫定対応

`php artisan serve --env=dusk.local` のバックグラウンドプロセスを一度停止し、
新しいプロセスとして起動し直すことで解消した（テンプレート本体への差分なし）。
