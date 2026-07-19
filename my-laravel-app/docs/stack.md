# 技術スタック

## ランタイム

| 項目 | バージョン | 備考 |
|---|---|---|
| PHP | 8.4.23 | `.tool-versions`（asdf）で固定 |
| Laravel | 13.x | フルスタック構成 |
| Node.js | 22.x (Active LTS) | Vite ビルド用 |
| MySQL | 8.x | 開発は Docker (`compose.yaml`)、本番はマネージド |
| Docker | 24.x 以上 | 開発時の DB 起動に必須 |
| Docker Compose | v2 以上（`docker compose` サブコマンド形式） | `docker-compose` (旧 v1) は使わない。Docker Desktop 同梱版はすでに v5 系に達しているため、上限は設けない |
| PCOV（PHP 拡張） | 1.0 以上 | **カバレッジ計測時のみ必要**（アプリの実行・`php artisan test` 単体には不要）。`php -m \| grep pcov` で確認。未導入時の導入手順は「テストカバレッジ設定（正規形）」節 |

> **PCOV は `.tool-versions` で固定できない。** PHP 拡張はバージョンマネージャ（asdf / mise）
> が管理する PHP インストールに紐づくため、**PHP を入れ直すと失われる**。`composer install`
> でも復元されない。各開発者が一度手で導入し、`php -m | grep pcov` が空になったら
> 再導入する必要がある。この非再現性を解消したい場合は、カバレッジ判定を CI
> （コンテナ内で決定論的に導入できる）へ移すのが本筋。

## フレームワーク・主要パッケージ

「手動追加」列が ✅ のパッケージは `laravel new` で自動追加されないため手動で `composer require` する。— は `laravel new`（Phase 1 の実行形は一時ディレクトリへの `laravel new tmp-skeleton --no-interaction --pest`。Laravel Installer 5.x はカレントディレクトリ指定と `--force` の併用を拒否するため、一時ディレクトリに生成して直下へ移動する。手順の詳細は `.claude/commands/scaffold-phase1-skeleton.md` 参照）で自動追加される、または PHP 標準拡張として利用する。

| パッケージ | 用途 | 手動追加 | 種別 |
|---|---|---|---|
| `laravel/framework` (^13.0) | フレームワーク本体 | — | — |
| `ext-pdo_mysql` | MySQL アダプタ（PHP 拡張） | — | — |
| `laravel-vite-plugin` | フロントビルド（**npm パッケージ**。`package.json` の `devDependencies`） | — | — |
| `livewire/livewire` | Hotwire (Turbo) 相当のサーバー駆動 UI | ✅ | ルート |
| `livewire/volt` | Livewire の単一ファイルコンポーネント記法 | — | ルート（`breeze:install livewire` が追加する） |
| `laravel/breeze` | 認証（Livewire スタック） | ✅ | `require-dev`（scaffold 生成後は実行時に不要） |
| `laravel-lang/lang` | 日本語バリデーションメッセージ・Breeze ビュー翻訳 | ✅ | `require-dev`（`lang:add ja` で翻訳ファイルを publish 済みのため実行時に不要） |
| `spatie/laravel-query-builder` | 検索・絞り込み（Ransack 相当） | ✅ | ルート |
| `blade-ui-kit/blade-heroicons` | アイコン（Heroicons の Blade コンポーネント） | ✅ | ルート |

Alpine.js は Livewire に同梱される（`livewire/livewire` インストール時に自動的に読み込まれる）ため、別途 npm パッケージとしての追加は不要。

`livewire/volt` は手動追加せず、`breeze:install livewire`（Phase 1）が依存として追加する。Breeze はこれを使って認証画面を単一ファイルコンポーネント（`resources/views/livewire/pages/auth/*.blade.php`）として生成する。本プロジェクトで新規に書く Livewire コンポーネントは Volt 記法ではなくクラスベース（`app/Livewire/`）に揃える（`docs/architecture.md` のディレクトリ規約参照）。

### 開発・テスト用

| パッケージ | 用途 | 手動追加 | 種別 |
|---|---|---|---|
| `laravel/pint` | Lint（コードスタイル） | — | `laravel new` の既定に含まれる |
| `larastan/larastan` | 静的解析（PHPStan の Laravel 版） | ✅ | `require-dev` |
| `pestphp/pest` | テストフレームワーク | ✅（`--pest` オプションで導入） | `require-dev` |
| `pestphp/pest-plugin-laravel` | Pest の Laravel 統合 | ✅（`--pest` に同梱） | `require-dev` |
| `laravel/dusk` | システムテスト（Capybara + Selenium 相当） | ✅ | `require-dev` |

カバレッジ計測ドライバの **PCOV は composer パッケージではなく PHP 拡張**のため、この表ではなく「ランタイム」表に記載している（マシン側の前提条件であり、`composer install` では導入されない）。

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
| `composer run setup` | 初回セットアップ（DB 起動 + composer/npm install + key:generate + migrate --seed + npm run build） |
| `composer run dev` | 開発サーバー起動（`php artisan serve` + `php artisan pail` + `npm run dev` を並行起動） |
| `php artisan test` | 単体・機能テスト（Pest） |
| `php artisan dusk` | システムテスト |
| `vendor/bin/pint --test` | Lint（チェックのみ） |
| `vendor/bin/pint` | Lint（自動修正） |
| `vendor/bin/phpstan analyse` | 静的解析（larastan/larastan） |

## 開発サーバー起動（正規形）

開発サーバーは `laravel new` 既定の `composer.json` の `dev` スクリプト（`composer run dev`）で起動する。concurrently により `php artisan serve` / `php artisan pail` / `npm run dev`（Vite）が並行起動する。**同内容の自前スクリプト（`bin/dev` 等）は作らない**（`composer.json` 側との二重管理になるため）。

ただし `laravel new` の既定生成物には `php artisan queue:listen --tries=1` が含まれる。本プロジェクトでは Queue を使わない方針（前述）に従い、`dev` スクリプトから **`queue:listen` の要素を削除する**。`--names` と `-c`（色指定）からも `queue` に対応する要素を落とすこと（残すと名前と実プロセスの対応がずれる）。

## 初回セットアップ（正規形）

初回セットアップも `laravel new` 既定の `composer.json` の `setup` スクリプト（`composer run setup`）を使う。**同内容の自前スクリプト（`bin/setup` 等）は作らない**（開発サーバー起動と同じ理由で、`composer.json` 側との二重管理になるため）。

既定の生成物に対して本プロジェクトが加える変更は 2 点:

- **先頭に `docker compose up -d --wait db` を足す** — DB を Docker で動かす構成のため、後続の `migrate` の前にコンテナを healthy にする必要がある
- **`migrate --force` を `migrate --seed --force` にする** — `docs/seeds.md` のサンプルデータ投入まで含めて「クローンして 1 コマンドで動く」状態にする

`npm install --ignore-scripts` は既定のまま残す（`.npmrc` の `ignore-scripts=true` と方針が一致するため）。具体的な JSON は `.claude/commands/scaffold-phase1-skeleton.md` の Step 8 参照。

## 採用しなかった開発環境ツール（Herd / Sail / Valet）

ローカル開発環境として以下の公式・準公式ツールを検討した上で、「ホスト側 PHP（asdf）+ DB のみ Docker」の構成を採っている。知らずに外したのではなく、選ばなかった理由は次のとおり。

- **Laravel Herd**: GUI アプリのためバージョンや設定をリポジトリ内で固定・共有できず、CI やヘッドレスの自動検証に組み込めない。MySQL 等の DB サービスは有料の Pro 機能であり、チーム標準の前提に置けない。
- **Laravel Sail**: PHP ごとコンテナ化するため全コマンドが `sail` ラッパー経由になり、IDE 統合や実行速度（macOS のバインドマウント）で不利。`php` / `composer` をホストで直接実行できる現構成を優先する。
- **Laravel Valet**: macOS 専用で、位置づけとして Herd に後継されている。新規採用する理由がない。

なお、開発者個人が Herd を併用すること自体は本構成と衝突しない（Herd がアプリを配信し、DB は本リポジトリの `compose.yaml` を使う形で共存できる）。ただしチーム共通の手順・CI・自動検証は本構成（`composer run dev` ベース）を正とする。

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

`bookkeeper_test` は Phase 1 で手動作成する（Laravel の `migrate` はデータベース自体の作成は行わないため）。

## MySQL 固有の注意（実装時）

- `boolean` 型は MySQL では `tinyint(1)` として保存される（Eloquent からは透過的）。
- JSON 型はマイグレーションで `$table->json()` を使う。検索クエリは `->` 演算子（`whereJsonContains` 等）で行う。
- 一意制約付きインデックスのカラム長制限に注意（utf8mb4 では 1 カラム最大 768 文字相当）。
- `ENUM` 型は使わず、Laravel の Enum キャスト（`enum` 属性キャスト、PHP 8.1+ のネイティブ enum クラス。クラスは `app/Enums/` に置く）を使い、DB カラムは integer で保存する。

## MySQL 設定の規約

### `config/database.php`

`mysql` 接続は **`laravel new`（Laravel 13.x）が生成する構造をそのまま使い、`env()` の第 2 引数（既定値）だけを本プロジェクトの値に揃える**。接続情報はすべて `env()` 経由で統一し、一部だけハードコードにはしない（どれが環境変数で上書きできるのかを読み手が推測せずに済むため）。

下記が調整後の正規形。`laravel new` の生成物との差分は `database` / `username` / `password` / `collation` の既定値 4 つだけである:

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

## テストカバレッジ設定（正規形）

カバレッジ計測には PCOV を使う（Xdebug よりテスト実行が高速なため）。`phpunit.xml` に以下を設定する。

> **前提（composer パッケージでは代替できない）**: PHP のカバレッジ計測には実行トレースを行う
> **PHP 拡張が必須**で、選択肢は実質 PCOV か Xdebug の 2 つ（phpdbg は php-code-coverage 側で
> サポート廃止済み）。composer パッケージの `pcov/clobber` は PHPUnit 5〜7 向けの互換シムであり
> （最終リリース 2019 年、作者自身が PHPUnit 8 以降では不要と明記）、本プロジェクトの PHPUnit では
> **導入してはならない**。

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

未導入の場合の導入手順（**PHP ランタイム全体に影響する変更のため、必ず事前にユーザーへ確認する**）:

```sh
pecl install pcov
# php --ini で表示される conf.d 配下の ini に extension=pcov.so を追記する
php -m | grep pcov   # 追記後、pcov が出れば有効
```

バージョンマネージャ（asdf / mise 等）で PHP を管理している場合、拡張はその PHP
インストールに紐づく。**PHP を入れ直すと拡張も失われる**ため、再導入が必要になる。
