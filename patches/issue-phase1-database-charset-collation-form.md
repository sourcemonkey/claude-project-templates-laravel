# `config/database.php` の charset / collation を「ハードコード」と「env 既定値」のどちらで書くかが一意に読めない

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

Phase 1 手順書 Step 4「config/database.php の調整」を実行する際、`charset` / `collation` を
**ハードコードするのか、`env()` の第 2 引数（既定値）を書き換えるのか**が判断できず、
2 つの記述を突き合わせて解釈を決める必要があった。手順書・docs のいずれにも誤りは
ないが、素直に読むと逆の結論に到達しうる。

## 根拠

`docs/stack.md`「MySQL 設定の規約」のサンプルは `env()` を使わずハードコードしている:

```php
'mysql' => [
    'driver' => 'mysql',
    'host' => env('DB_HOST', '127.0.0.1'),
    'port' => env('DB_PORT', '3306'),
    'database' => env('DB_DATABASE', 'bookkeeper'),
    'username' => env('DB_USERNAME', 'app'),
    'password' => env('DB_PASSWORD', 'app_password'),
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_0900_ai_ci',
    'prefix' => '',
    'strict' => true,
    'engine' => null,
],
```

手順書 Step 4 の本文もこれを受けて「明示」と書く:

> `docs/stack.md` の「MySQL 設定の規約」セクションに記載のサンプル通りに `mysql` 接続設定を修正する。要点:
>
> - `charset: utf8mb4` / `collation: utf8mb4_0900_ai_ci` を明示

一方、同じ Step 4 の補足は `env()` の第 2 引数を揃えろと書く:

> `docs/stack.md` の規約に合わせて `env()` の第 2 引数（既定値）も `bookkeeper` / `app` / `app_password` / `utf8mb4_0900_ai_ci` に揃えておく。

`laravel new`（Laravel Framework 13.20.0）が実際に生成する `mysql` 接続は、
サンプルに無い `url` / `unix_socket` / `prefix_indexes` / `options` を持ち、
`charset` / `collation` も `env()` 経由である:

```php
        'mysql' => [
            'driver' => 'mysql',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => env('DB_CHARSET', 'utf8mb4'),
            'collation' => env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                Mysql::ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
            ]) : [],
        ],
```

つまり「サンプル通りに修正する」を字義どおり取ると、`url` や `options` を削除して
サンプルの形へ置き換えることになる。手順書には `url` の行を残してよい旨の記述が
別途あるため最終的には解釈できたが、`charset` / `collation` の書き方については
どちらとも読める状態が残る。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:97`
- 関連ファイル: `my-laravel-app/docs/stack.md`（「MySQL 設定の規約」節）

## なぜ自動で直さなかったか

手順 4 の「フェーズが成功していても申し送るもの → 手順書は正しいが誤読した箇所」に当たる。
加えて、どちらの形を正とするかは方針の選択（環境変数で上書きできる余地を残すか、
プロジェクトで固定するか）であり、一意に定まらない。

## 選択肢

1. **`env()` 経由を正とする** — 影響: 生成物の構造をそのまま活かし、既定値だけ
   `utf8mb4` / `utf8mb4_0900_ai_ci` に揃える。`docs/stack.md` のサンプルを Laravel 13 の
   実際の形に合わせて書き直す / 懸念: `.env` に `DB_COLLATION` を置けば規約を迂回できる
2. **ハードコードを正とする** — 影響: `charset` / `collation` から `env()` を外し、
   プロジェクトで固定する。`docs/stack.md` のサンプルは現状のままでよい / 懸念:
   `laravel new` の生成物からの差分が増え、Laravel の更新時に追従判断が要る

## 推奨

案 1。`host` / `database` / `username` / `password` はすでに `env()` 経由で統一されており、
`charset` / `collation` だけをハードコードにする理由が説明できない。あわせて
`docs/stack.md` のサンプルを Laravel 13 の実際の生成形（`url` / `unix_socket` /
`prefix_indexes` / `options` を含む）に更新すれば、「サンプル通りに修正する」が
文字どおり実行可能になり、Step 4 の補足も不要になる。

## 決めてほしいこと

`charset` / `collation` を `env()` の既定値として持つ形（案 1）に統一し、
`docs/stack.md` のサンプルを Laravel 13 の生成形に合わせて書き直してよいか。

## 暫定対応

Step 4 の補足を優先し、`env()` の第 2 引数のみを次のように書き換えた
（`url` / `unix_socket` / `prefix_indexes` / `options` は生成されたまま残した）:

```php
'database' => env('DB_DATABASE', 'bookkeeper'),
'username' => env('DB_USERNAME', 'app'),
'password' => env('DB_PASSWORD', 'app_password'),
'unix_socket' => env('DB_SOCKET', ''),
'charset' => env('DB_CHARSET', 'utf8mb4'),
'collation' => env('DB_COLLATION', 'utf8mb4_0900_ai_ci'),
```

`php artisan migrate` / `php artisan test` はこの形で通っている。
テンプレート本体への差分はなし（`config/database.php` は git 管理外の生成物）。
