# 技術スタック

## ランタイム

| 項目 | バージョン | 備考 |
|---|---|---|
| PHP | 8.4.23 | `.tool-versions`（asdf）で固定 |
| Laravel | 13.x | フルスタック構成 |
| Node.js | 22.x (Active LTS) | Vite ビルド用 |
| MySQL | 8.x | 開発は Docker (`compose.yaml`)、本番はマネージド |
| Docker | 24.x 以上 | 開発時の DB 起動に必須 |
| Docker Compose | v2 (`docker compose` コマンド) | `docker-compose` (旧 v1) は使わない |

## フレームワーク・主要パッケージ

「手動追加」列が ✅ のパッケージは `laravel new` で自動追加されないため手動で `composer require` する。— は `laravel new my-laravel-app --database=mysql` で自動追加される、または PHP 標準拡張として利用する。

| パッケージ | 用途 | 手動追加 | 種別 |
|---|---|---|---|
| `laravel/framework` (^13.0) | フレームワーク本体 | — | — |
| `ext-pdo_mysql` | MySQL アダプタ（PHP 拡張） | — | — |
| `laravel/vite-plugin` | フロントビルド | — | — |
| `livewire/livewire` | Hotwire (Turbo) 相当のサーバー駆動 UI | ✅ | ルート |
| `laravel/breeze` | 認証（Blade スタック） | ✅ | `--dev`（scaffold 実行後は通常依存に降格） |
| `laravel-lang/lang` | 日本語バリデーションメッセージ・Breeze ビュー翻訳 | ✅ | ルート |
| `spatie/laravel-query-builder` | 検索・絞り込み（Ransack 相当） | ✅ | ルート |

Alpine.js は Livewire に同梱される（`livewire/livewire` インストール時に自動的に読み込まれる）ため、別途 npm パッケージとしての追加は不要。

### 開発・テスト用

| パッケージ | 用途 | 手動追加 | 種別 |
|---|---|---|---|
| `laravel/pint` | Lint（コードスタイル） | — | `laravel new` の既定に含まれる |
| `larastan/larastan` | 静的解析（PHPStan の Laravel 版） | ✅ | `require-dev` |
| `pestphp/pest` | テストフレームワーク | ✅（`--pest` オプションで導入） | `require-dev` |
| `pestphp/pest-plugin-laravel` | Pest の Laravel 統合 | ✅（`--pest` に同梱） | `require-dev` |
| `laravel/dusk` | システムテスト（Capybara + Selenium 相当） | ✅ | `require-dev` |
| `pcov/clobber` または php.ini の `pcov` 拡張 | テストカバレッジ計測ドライバ | ✅（拡張として） | ローカル環境 |

`factory_bot` 相当は Laravel 標準の Model Factory（`database/factories/`）、`faker` 相当は `fakerphp/faker`（Laravel の依存関係に標準で含まれる）を使う。追加インストール不要。

> **注意**: 当初 `enlightn/enlightn`（セキュリティ・パフォーマンス静的解析）の採用を検討していたが、Laravel 13.x に対応するバージョンが存在しない（最新の v2.10.0 でも `laravel/framework ^9.0|^10.0|^11.0` までのサポート）ため、型・コード品質の静的解析ツールである `larastan/larastan` に変更した。Enlightn が提供していた Laravel 特化のセキュリティ・パフォーマンスチェック（本番での `APP_DEBUG` 有効化検知等）は代替ツールがないため、`team-rules/security.md` のチェックリストに沿った手動レビューでカバーする。

## メール確認（letter_opener 相当）

追加コンテナを増やさない方針のため、開発環境では `MAIL_MAILER=log` を使う。送信されたメールの内容は `storage/logs/laravel.log` に出力される。`php artisan pail` でリアルタイムにログを追えるため、実質的に letter_opener に近い確認体験になる。

## ジョブ・キャッシュ・ブロードキャスト

Laravel 標準の Queue（database ドライバ）・Cache（database/file ドライバ）・Broadcasting（Reverb）が
`laravel new` で選択可能だが、**本プロジェクトでは現時点で利用しない**。

- 非同期ジョブ・キャッシュ・リアルタイム通信を必要とする機能は本フェーズでは作らない
- ただし将来の拡張に備えて、`laravel new` が生成した Queue 関連のファイル・
  マイグレーション（`jobs`, `job_batches`, `failed_jobs` テーブル）は**削除せずそのまま残す**
- `CACHE_STORE` は development では `database`、test では `array` を使う（Laravel の既定に準拠）
- メール送信（Breeze のパスワード再発行等）は同期送信で良い。
  development では `MAIL_MAILER=log` で確認するため非同期化は不要
- `composer.json` の `dev` スクリプトに Queue ワーカー（`php artisan queue:listen`）は**追加しない**。
  `laravel new` が既定で追加する場合は削除する
- Redis / Laravel Horizon / Reverb などの追加導入もしない

## ビュー / フロント

- Blade + Livewire（Turbo Frames / Turbo Streams 相当のサーバー駆動 UI 更新）
- 軽い動的処理（ドロップダウン、モーダル、タブ切り替え）は Alpine.js
- CSS は Tailwind ユーティリティ中心
- アイコンは `blade-ui-kit/blade-heroicons` 経由で Heroicons をコンポーネントとして利用

## 起動・開発コマンド

| コマンド | 用途 |
|---|---|
| `docker compose up -d db` | 開発用 DB コンテナ起動 |
| `docker compose down` | DB コンテナ停止 |
| `docker compose down -v` | DB を完全初期化（ボリュームごと削除） |
| `bin/setup` | 初回セットアップ（DB 起動 + composer/npm install + migrate --seed） |
| `bin/dev` | 開発サーバー起動（`php artisan serve` + `npm run dev`） |
| `php artisan test` | 単体・機能テスト（Pest） |
| `php artisan dusk` | システムテスト |
| `vendor/bin/pint --test` | Lint（チェックのみ） |
| `vendor/bin/pint` | Lint（自動修正） |
| `vendor/bin/phpstan analyse` | 静的解析（larastan/larastan） |

## bin/dev（正規形）

`bin/dev` は `php artisan serve` と `npm run dev`（Vite）を並行起動するシェルスクリプト。`laravel new` 既定の `composer.json` の `dev` スクリプトには Queue ワーカーと `pail` の起動が含まれるが、本プロジェクトでは Queue を使わないため以下の 2 プロセスのみに絞る。

```sh
#!/usr/bin/env bash
set -euo pipefail
trap 'kill 0' EXIT
php artisan serve &
npm run dev &
wait
```

`php artisan queue:listen` の行は含めない。

## ディレクトリ規約

標準 Laravel 構成に加えて以下を使う:

- `app/Actions/` — 複数モデルにまたがる業務ロジック（Rails 版の Service オブジェクト相当）
- `app/Policies/` — 認可ポリシー
- `app/Livewire/` — Livewire コンポーネント
- `resources/views/components/` — Blade コンポーネント

## 環境変数

`.env` で管理。`.env.example` を必ず同期する。

```
DB_USERNAME=app
DB_PASSWORD=app_password
DB_HOST=127.0.0.1
DB_PORT=3306
APP_KEY=（php artisan key:generate で生成される値）
DEFAULT_FROM_EMAIL=no-reply@example.local
```

> **注意**: `DATABASE_URL` は設定しない。`config/database.php` は `DB_*` の個別変数で接続情報を受け取る設計。`DATABASE_URL` と個別変数を混在させると優先順位が複雑になりデバッグが困難になる。

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

`bookkeeper_test` は Phase 1 で手動作成する（Laravel の `migrate` はデータベース自体の作成は行わないため）。

## MySQL 固有の注意（実装時）

- `boolean` 型は MySQL では `tinyint(1)` として保存される（Eloquent からは透過的）。
- JSON 型はマイグレーションで `$table->json()` を使う。検索クエリは `->` 演算子（`whereJsonContains` 等）で行う。
- 一意制約付きインデックスのカラム長制限に注意（utf8mb4 では 1 カラム最大 768 文字相当）。
- `ENUM` 型は使わず、Laravel の Enum キャスト（`enum` 属性キャスト、PHP 8.1+ のネイティブ enum クラス）を使い、DB カラムは integer で保存する。

## MySQL 設定の規約

### `config/database.php`

`mysql` 接続に以下の設定を必ず含める:

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

`.env` の `DB_DATABASE` は development では `bookkeeper`、test 実行時は `phpunit.xml` の環境変数で `bookkeeper_test` に切り替える。

## テストカバレッジ設定（正規形）

カバレッジ計測には PCOV を使う（Xdebug よりテスト実行が高速なため）。`phpunit.xml` に以下を設定する。

```xml
<coverage>
    <report>
        <html outputDirectory="coverage"/>
    </report>
</coverage>
<source>
    <include>
        <directory suffix=".php">app</directory>
    </include>
</source>
```

実行コマンド:

```sh
php artisan test --coverage-html coverage
```

PCOV 拡張がローカル環境にインストールされている前提。`php -m | grep pcov` で確認できる。
