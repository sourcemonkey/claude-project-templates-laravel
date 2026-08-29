# セットアップ（Phase 1）

Laravel 雛形の生成・依存パッケージの導入・開発 DB・環境変数の規約。**Phase 1 でのみ読む**
（全フェーズで読むのは `docs/stack.md`）。

## フレームワーク・主要パッケージ

「手動追加」列が ✅ のパッケージは手動で `composer require` する。— は `laravel/laravel` に既定で含まれる、または PHP 標準拡張として利用する。

**アプリの生成は `composer create-project laravel/laravel:^13.0` で行う（`laravel new` はバージョンを固定できないため使わない）。** 手順の詳細は `.claude/commands/scaffold-phase1-skeleton.md` の Step 3 参照。

| パッケージ | 用途 | 手動追加 | 種別 |
|---|---|---|---|
| `laravel/framework` (^13.0) | フレームワーク本体 | — | — |
| `ext-pdo_mysql` | MySQL アダプタ（PHP 拡張） | — | — |
| `laravel-vite-plugin` | フロントビルド（**npm パッケージ**。`package.json` の `devDependencies`） | — | — |
| `livewire/livewire` | Hotwire (Turbo) 相当のサーバー駆動 UI | —（`breeze:install livewire` が `^3.6.4` で追加する） | ルート |
| `livewire/volt` | Livewire の単一ファイルコンポーネント記法 | — | ルート（`breeze:install livewire` が追加する） |
| `laravel/breeze` | 認証（Livewire スタック） | ✅ | `require-dev`（scaffold 生成後は実行時に不要） |
| `laravel-lang/lang` | 日本語バリデーションメッセージ・Breeze ビュー翻訳 | ✅ | `require-dev`（`lang:add ja` で翻訳ファイルを publish 済みのため実行時に不要） |
| `spatie/laravel-query-builder` | 検索・絞り込み（Ransack 相当） | ✅ | ルート |
| `blade-ui-kit/blade-heroicons` | アイコン（Heroicons の Blade コンポーネント） | ✅ | ルート |

Alpine.js は Livewire に同梱されるため、別途 npm パッケージとしての追加は不要。

> **Livewire は v3 系を使う。** 上流の最新は v4 系だが、`breeze:install livewire` が
> `^3.6.4` の制約を書き込む。**これは意図した状態であり、v3 を「古い」と判断して
> 上げないこと。** `composer require livewire/livewire`（制約なし）を後から実行すると
> この制約を上書きして v4 が入る。

`livewire/livewire` / `livewire/volt` は手動追加せず、`breeze:install livewire`（Phase 1）が `require` へ追加する（`^3.6.4` / `^1.7.0`）。Breeze はこれを使って認証画面を単一ファイルコンポーネント（`resources/views/livewire/pages/auth/*.blade.php`）として生成する。

### 公式スターターキット・公式プレイブックとの関係

**本プロジェクトは公式スターターキット（Livewire / React / Vue）を採用せず、素の Laravel に
Breeze を後入れする。** Laravel 公式がエージェント向けに配布するインストール手順
（[laravel.com/for/agents](https://laravel.com/for/agents)）のプロンプトも使わない。

**`composer.json` に Breeze があるのを「メンテナンスが止まったパッケージ」と判断して
公式スターターキットへ差し替えないこと。** 根拠は `docs/decisions.md`。

### 開発・テスト用

| パッケージ | 用途 | 手動追加 | 種別 |
|---|---|---|---|
| `laravel/pint` | Lint（コードスタイル） | — | `laravel/laravel` の既定に含まれる |
| `laravel/pao` | テストツール（pint / pest / phpstan）の実行結果を Agent 向けの JSON 1 行で出力する | — | `laravel/laravel` の既定に含まれる |
| `larastan/larastan` | 静的解析（PHPStan の Laravel 版） | ✅ | `require-dev` |
| `pestphp/pest` | テストフレームワーク | ✅（Phase 1 で PHPUnit と入れ替える） | `require-dev` |
| `pestphp/pest-plugin-laravel` | Pest の Laravel 統合 | ✅（Pest と同時に導入） | `require-dev` |
| `pestphp/pest-plugin-drift` | PHPUnit 記法から Pest 記法への変換 | ✅（変換後に取り除く一時的な依存） | `require-dev` |
| `laravel/dusk` | システムテスト（Capybara + Selenium 相当） | ✅ | `require-dev` |
| `laravel/boost` | AI エージェント向けの MCP サーバー（DB スキーマ・ログ・ドキュメント検索）と AI ガイドライン生成 | ✅ | `require-dev` |

> **`laravel/pao` は `^1.1.3` 以上に固定する**（Phase 1 の Step 8 で引き上げる。**下げないこと**）。
> **v1.1.2 以前は全件パスでも `php artisan test` の終了コードが 1 になる**ため、完了基準を
> 終了コードで判定する本プロジェクトでは green のテストを失敗と誤認する。
>
> **ただし pao の JSON の `result` フィールドは信用しない**（`docs/stack.md` の「80% 判定の規約」参照）。

> **`laravel/boost` の導入範囲**: Phase 1 の `boost:install --mcp --guidelines` で `.mcp.json` と `docs/boost-guidelines.md` だけを生成する。**Agent Skills（`--skills`）は導入しない**（出力先の `.claude/` はヘッドレス実行で書き込めないため）。
>
> ガイドラインの出力先は `config/boost.php` で `CLAUDE.md` から `docs/` へ退避させ、方針と衝突する 2 つは `.ai/guidelines/` で上書きしている。

> | 上書きファイル | 対象 | 理由 |
> |---|---|---|
> | `.ai/guidelines/volt/core.blade.php` | `volt/core rules` | 新規コンポーネントに Volt を使わない方針 |
> | `.ai/guidelines/boost/core.blade.php` | `boost rules` | v2.5.0 の `## Project Rules` が、**存在しない `.ai/rules/index.md` を開くことを MUST として要求する**ため。ルールの置き場を増やさず `team-rules/` と `docs/` に一本化する |
>
> 上書きファイルのパスは Boost 内部のガイドラインキーに対応する（`boost` 節は `boost/core.blade.php`）。**節見出しの名前（`=== boost rules ===`）とは一致しない**ので、パスは `vendor/laravel/boost/src/Install/GuidelineComposer.php` の対応表で確認すること。上書き時は Boost 側の有用な記述（MCP ツールの説明等）を書き写して維持する。
>
> **`docs/*.md` と `team-rules/` が優先、Boost は補完**という関係を保つこと。

`factory_bot` 相当は Laravel 標準の Model Factory（`database/factories/`）、`faker` 相当は `fakerphp/faker`（Laravel の依存関係に標準で含まれる）を使う。追加インストール不要。

## メール確認（letter_opener 相当）

追加コンテナを増やさない方針のため、開発環境では `MAIL_MAILER=log` を使う。送信されたメールの内容は `storage/logs/laravel.log` に出力される。`php artisan pail` でリアルタイムにログを追えるため、実質的に letter_opener に近い確認体験になる。

## ジョブ・キャッシュ・ブロードキャスト

Laravel 標準の Queue（database ドライバ）・Cache（database/file ドライバ）・Broadcasting（Reverb）は
**本プロジェクトでは現時点で利用しない**。

- 非同期ジョブ・キャッシュ・リアルタイム通信を必要とする機能は本フェーズでは作らない
- ただし将来の拡張に備えて、生成された Queue 関連のファイル・
  マイグレーション（`jobs`, `job_batches`, `failed_jobs` テーブル）は**削除せずそのまま残す**
- `CACHE_STORE` は development では `database`、test では `array` を使う（Laravel の既定に準拠）
- メール送信（Breeze のパスワード再発行等）は同期送信で良い。
  development では `MAIL_MAILER=log` で確認するため非同期化は不要
- 開発サーバー（`composer run dev`）で Queue ワーカー（`php artisan queue:listen`）を**起動しない**。
  除外の方法は次節「開発サーバー起動（正規形）」参照
- Redis / Laravel Horizon / Reverb などの追加導入もしない

## 開発サーバー起動（正規形）

開発サーバーは `laravel/laravel` 既定の `composer.json` の `dev` スクリプト（`composer run dev`）で起動する。**同内容の自前スクリプト（`bin/dev` 等）は作らない**（`composer.json` 側との二重管理になるため）。

**Laravel 13.17 以降、`dev` スクリプトは `@php artisan dev` への委譲になっている。** 起動するプロセスは `Illuminate\Foundation\DevCommands::registerDefaults()` が登録する 4 つ — `server`（`artisan serve`）/ `queue`（`queue:listen`）/ `logs`（`pail`）/ `vite`（`npm run dev`）。

本プロジェクトは Queue を使わない方針（前述）に従い、**`queue` だけを除外する**。除外は `composer.json` ではなく `app/Providers/AppServiceProvider.php` の `boot()` で行う:

```php
use Illuminate\Foundation\DevCommands;

DevCommands::except('queue');
```

対象は `php artisan dev:list` で確認できる（除外後は `server` / `logs` / `vite` の 3 つ）。

> **`composer.json` の `dev` を `concurrently` 直書きへ書き換えないこと。**

## 初回セットアップ（正規形）

初回セットアップも `laravel/laravel` 既定の `composer.json` の `setup` スクリプト（`composer run setup`）を使う。**同内容の自前スクリプト（`bin/setup` 等）は作らない**（開発サーバー起動と同じ理由で、`composer.json` 側との二重管理になるため）。

既定の生成物に対して本プロジェクトが加える変更は 2 点:

- **先頭に `docker compose up -d --wait db` を足す** — DB を Docker で動かす構成のため、後続の `migrate` の前にコンテナを healthy にする必要がある
- **`migrate --force` を `migrate --seed --force` にする** — `docs/seeds.md` のサンプルデータ投入まで含めて「クローンして 1 コマンドで動く」状態にする

`npm install --ignore-scripts` は既定のまま残す（`.npmrc` の `ignore-scripts=true` と方針が一致するため）。具体的な JSON は `.claude/commands/scaffold-phase1-skeleton.md` の Step 8 参照。

## 採用しなかった開発環境ツール（Herd / Sail / Valet）

ローカル開発環境は「ホスト側 PHP（asdf / mise）+ DB のみ Docker」の構成を採る。
Herd / Sail / Valet を検討したうえで選ばなかった理由は `docs/decisions.md` 参照。

## 環境変数

`.env` で管理。`.env.example` を必ず同期する。

```
DB_USERNAME=app
DB_PASSWORD=app_password
DB_HOST=127.0.0.1
DB_PORT=3306
APP_KEY=（php artisan key:generate で生成される値）
MAIL_FROM_ADDRESS=no-reply@example.local
```

> **注意**: 接続文字列方式の `DB_URL` は設定しない。`config/database.php` は `DB_*` の個別変数で接続情報を受け取る設計。URL 方式と個別変数を混在させると優先順位が複雑になりデバッグが困難になる。なお Laravel 13 の既定 `mysql` 接続が参照する変数名は `'url' => env('DB_URL')` であり、`DATABASE_URL` ではない。

## 開発 DB（Docker）

開発環境の MySQL はリポジトリ同梱の `compose.yaml` で起動する。

| 操作 | コマンド |
|---|---|
| 起動 | `docker compose up -d db` |
| 停止 | `docker compose down` |
| 完全初期化（データ消去）| `docker compose down -v` |
| ログ確認 | `docker compose logs -f db` |
| MySQL CLI 接続 | `docker compose exec db mysql -uapp -papp_password bookkeeper` |
| 疎通確認 | `docker compose exec db mysqladmin ping -uroot -proot_password` |

### 設計方針

- **Laravel 本体はホスト側で動かす**。アプリまでコンテナ化はしない（エディタ統合・ファイル同期・パフォーマンスの観点から）。
- **DB のみ Docker で起動する**。各開発者のホスト環境を MySQL のバージョンや設定で汚さないため。
- データは名前付きボリューム `db-data` に永続化される。
- ポートはセキュリティのため `127.0.0.1:3306` にバインドする（外部公開しない）。

### 接続情報

| 項目 | 値 |
|---|---|
| ホスト | `127.0.0.1` |
| ポート | `3306` |
| データベース | `bookkeeper` / `bookkeeper_test` |
| アプリ用ユーザ | `app` / `app_password` |
| root ユーザ | `root` / `root_password` |

Laravel の `migrate` はデータベース自体の作成を行わないため、**両データベースとも DB コンテナの初回起動時に作成する**。`bookkeeper` は `compose.yaml` の `MYSQL_DATABASE`、`bookkeeper_test` は `docker/mysql/initdb/01-create-test-database.sql`（`docker-entrypoint-initdb.d` にマウント）が担当する。これにより、クローン直後に `composer run setup` を実行するだけで `php artisan test` まで動く。

> `docker-entrypoint-initdb.d` のスクリプトは**データディレクトリが空のときにしか実行されない**。init スクリプトを追加・変更した場合は `docker compose down -v` でボリュームを作り直さないと反映されない。

## MySQL 設定の規約

### `config/database.php`

`mysql` 接続は **`laravel/laravel` が生成する構造をそのまま使い、`env()` の第 2 引数（既定値）だけを本プロジェクトの値に揃える**。接続情報はすべて `env()` 経由で統一し、一部だけハードコードにはしない。

下記が調整後の正規形。生成物との差分は `database` / `username` / `password` / `collation` の既定値 4 つだけである:

```php
'mysql' => [
    'driver' => 'mysql',
    'url' => env('DB_URL'),
    'host' => env('DB_HOST', '127.0.0.1'),
    'port' => env('DB_PORT', '3306'),
    'database' => env('DB_DATABASE', 'bookkeeper'),          // 既定は 'laravel'
    'username' => env('DB_USERNAME', 'app'),                 // 既定は 'root'
    'password' => env('DB_PASSWORD', 'app_password'),        // 既定は ''
    'unix_socket' => env('DB_SOCKET', ''),
    'charset' => env('DB_CHARSET', 'utf8mb4'),
    'collation' => env('DB_COLLATION', 'utf8mb4_0900_ai_ci'), // 既定は 'utf8mb4_unicode_ci'
    'prefix' => '',
    'prefix_indexes' => true,
    'strict' => true,
    'engine' => null,
    'options' => extension_loaded('pdo_mysql') ? array_filter([
        Mysql::ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
    ]) : [],
],
```

`url` / `unix_socket` / `prefix_indexes` / `options` は生成されたまま残す（消す理由がなく、Laravel 更新時の差分も増える）。ただし **`DB_URL` は `.env` に設定しない** — 理由は次項の注意参照。

`.env` の `DB_DATABASE` は development では `bookkeeper`、test 実行時は `phpunit.xml` の環境変数で `bookkeeper_test` に切り替える。
