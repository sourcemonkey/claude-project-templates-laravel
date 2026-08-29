# 技術スタック

## ランタイム

| 項目 | バージョン | 備考 |
|---|---|---|
| PHP | 8.4.23 | `.tool-versions`（asdf / mise）で固定 |
| Composer | 2.x 以上 | アプリの生成（`composer create-project`）と依存管理に使う。バージョン差で成果物が変わらないため `.tool-versions` では固定しない |
| Laravel | 13.x | フルスタック構成 |
| Node.js | 24.x (Active LTS) | `.tool-versions`（asdf / mise）で固定。Vite ビルド用 |
| MySQL | 8.x | 開発は Docker (`compose.yaml`)、本番はマネージド |
| Docker | 24.x 以上 | 開発時の DB 起動に必須 |
| Docker Compose | v2 以上（`docker compose` サブコマンド形式） | `docker-compose` (旧 v1) は使わない。Docker Desktop 同梱版はすでに v5 系に達しているため、上限は設けない |
| PCOV（PHP 拡張） | 1.0 以上 | **カバレッジ計測時のみ必要**（アプリの実行・`php artisan test` 単体には不要）。`php -m \| grep pcov` で確認。未導入時の導入手順は「テストカバレッジ設定（正規形）」節 |

> **PCOV は `.tool-versions` で固定できない。PHP を入れ直すと失われ、`composer install` でも
> 復元されない。** 各開発者が一度手で導入し、`php -m | grep pcov` が空になったら再導入する。

## ビュー / フロント

- Blade + Livewire（Turbo Frames / Turbo Streams 相当のサーバー駆動 UI 更新）
- 軽い動的処理（ドロップダウン、モーダル、タブ切り替え）は Alpine.js
- CSS は Tailwind ユーティリティ中心
- アイコンは `blade-ui-kit/blade-heroicons` 経由で Heroicons をコンポーネントとして利用
- 新規に書く Livewire コンポーネントは Volt 記法ではなくクラスベース（`app/Livewire/`）に揃える（`docs/architecture.md` のディレクトリ規約参照）

> **Alpine.js は Livewire に同梱されるが、読み込まれるのはそのページが Livewire
> コンポーネントを描画したときだけ。** 1 つも持たない画面では Alpine が読み込まれず、
> `x-data` / `x-on:submit` が**エラーも出さずに無効化される**（削除確認が効かず、確認なしで
> 削除される）。**Livewire コンポーネントを持たない画面がありうるレイアウトには
> `@livewireScripts` を明示的に書くこと**（本プロジェクトでは `layouts/admin.blade.php` が
> 該当。`layouts/app.blade.php` は `<livewire:layout.navigation />` を含むため自動注入が働く）。

> **Alpine の読み込みとは別に、`x-on:` を書くフォームには `x-data`（空でよい）が要る。**
> Alpine v3 は `x-data` スコープ内の要素しか処理しないため、`x-data` の無い素の
> `<form x-on:submit="...">` は**エラーも出さず無視され、確認ダイアログが出ないまま
> 実行される**（Dusk は `Waited 5 seconds for dialog.` で失敗する）。必ず
> `<form x-data x-on:submit="...">` の形にすること。ナビの `x-data="{ open: false }"` は
> nav 要素にスコープされるため、その外側のフォームには効かない。

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
| `vendor/bin/phpstan analyse --memory-limit=512M` | 静的解析（larastan/larastan）。**`--memory-limit` を省略しない**（PHP の既定 128M では並列ワーカーが `Child process error (exit code 255)` で落ちる） |

## Eloquent の strict 設定

`AppServiceProvider::boot()` で次を有効にする。

```php
Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction());
```

`$fillable` に無い列を mass assignment すると、既定では**例外も警告も出ずに捨てられる**。
これを非 production でのみ `MassAssignmentException` にする。捨てられた列名が例外文に出る。

**`Model::shouldBeStrict()` は使わない。** 同時に有効になる `preventLazyLoading` と
`preventAccessingMissingAttributes` は本プロジェクトでは採らない。

この設定に依存する書き方が 2 つある。

- **モデルファクトリは影響を受けない**（`Illuminate\...\Factories\Factory` がモデル生成を
  `Model::unguarded()` で包むため）。`User::factory()->admin()` のように非 fillable の列を
  ファクトリで設定する形はそのまま使える
- **NOT NULL 制約のテストで `Model::create($model::factory()->raw([...]))` と書かない。**
  `raw()` は非 fillable を含む全列を返すため、DB へ到達する前に例外になる。
  `Model::factory()->create(['col' => null])` を使う

## ディレクトリ規約

標準 Laravel 構成に加えて以下を使う:

- `app/Actions/` — 複数モデルにまたがる業務ロジック（Rails 版の Service オブジェクト相当）
- `app/Policies/` — 認可ポリシー
- `app/Livewire/` — Livewire コンポーネント
- `resources/views/components/` — Blade コンポーネント

## MySQL 固有の注意（実装時）

- `boolean` 型は MySQL では `tinyint(1)` として保存される（Eloquent からは透過的）。
- JSON 型はマイグレーションで `$table->json()` を使う。検索クエリは `->` 演算子（`whereJsonContains` 等）で行う。
- 一意制約付きインデックスのカラム長制限に注意（utf8mb4 では 1 カラム最大 768 文字相当）。
- `ENUM` 型は使わず、Laravel の Enum キャスト（`enum` 属性キャスト、PHP 8.1+ のネイティブ enum クラス。クラスは `app/Enums/` に置く）を使い、DB カラムは integer で保存する。

## テストカバレッジ設定（正規形）

カバレッジ計測には PCOV を使う（Xdebug よりテスト実行が高速なため）。`phpunit.xml` に以下を設定する。

> **composer パッケージでは代替できない。** カバレッジ計測には PHP 拡張が必須で、
> `pcov/clobber` は PHPUnit 5〜7 向けの互換シムなので**導入してはならない**。

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

### 80% 判定の規約

**判定は `vendor/bin/pest --coverage --min=80` の終了コードで行う**（未達なら 1、達していれば 0）。

```sh
vendor/bin/pest --coverage --min=80
```

> **`laravel/pao` が整形する JSON の `result` フィールドは信用してはならない。**
> `--min` 未達でも `{"tool":"pest","result":"passed",...}` を返す。**終了コードと `raw` 配列
> （末尾に `Total: NN.N %`）は正しい**ので、そちらで判定する。

HTML レポート（`coverage/index.html`）は数値の内訳を見るために使う。合否判定の一次情報ではない。

具体的な実行手順と出力例は `.claude/commands/scaffold-phase5-finalize.md` の手順 6-3 参照。

未導入の場合の導入手順（**PHP ランタイム全体に影響する変更のため、必ず事前にユーザーへ確認する**）:

```sh
pecl install pcov
# php --ini で表示される conf.d 配下の ini に extension=pcov.so を追記する
php -m | grep pcov   # 追記後、pcov が出れば有効
```

バージョンマネージャ（asdf / mise 等）で PHP を管理している場合、拡張はその PHP
インストールに紐づく。**PHP を入れ直すと拡張も失われる**ため、再導入が必要になる。
