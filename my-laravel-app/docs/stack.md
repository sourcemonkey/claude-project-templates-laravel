# 技術スタック

## ランタイム

| 項目 | バージョン | 備考 |
|---|---|---|
| PHP | 8.4.23 | `.tool-versions`（asdf / mise）で固定 |
| Composer | 2.x 以上 | `laravel new` が内部で `composer create-project` を呼ぶため必須。バージョン差で成果物が変わらないため `.tool-versions` では固定しない |
| Laravel | 13.x | フルスタック構成 |
| Node.js | 24.x (Active LTS) | `.tool-versions`（asdf / mise）で固定。Vite ビルド用 |
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
| `livewire/livewire` | Hotwire (Turbo) 相当のサーバー駆動 UI | —（`breeze:install livewire` が `^3.6.4` で追加する） | ルート |
| `livewire/volt` | Livewire の単一ファイルコンポーネント記法 | — | ルート（`breeze:install livewire` が追加する） |
| `laravel/breeze` | 認証（Livewire スタック） | ✅ | `require-dev`（scaffold 生成後は実行時に不要） |
| `laravel-lang/lang` | 日本語バリデーションメッセージ・Breeze ビュー翻訳 | ✅ | `require-dev`（`lang:add ja` で翻訳ファイルを publish 済みのため実行時に不要） |
| `spatie/laravel-query-builder` | 検索・絞り込み（Ransack 相当） | ✅ | ルート |
| `blade-ui-kit/blade-heroicons` | アイコン（Heroicons の Blade コンポーネント） | ✅ | ルート |

Alpine.js は Livewire に同梱されるため、別途 npm パッケージとしての追加は不要。

> **ただし「自動的に読み込まれる」のはページ単位の条件付きである。** Livewire v3 は
> **そのページが Livewire コンポーネントを実際に描画したときだけ** `livewire.js`
> （Alpine を同梱する）をレスポンスへ注入する。Livewire コンポーネントを 1 つも
> 持たないレイアウト・画面では Alpine が読み込まれず、`x-data` / `x-on:submit` が
> **エラーも出さずに無効化される**。削除確認（`x-on:submit="confirm(...) || ..."`）が
> 効かなくなり、確認なしで削除が実行される。
>
> `resources/js/app.js` は `laravel new` の生成物では実質空で Alpine を import して
> いないため、この経路での補完も効かない。**Livewire コンポーネントを持たない画面が
> ありうるレイアウトには `@livewireScripts` を明示的に書くこと**（本プロジェクトでは
> `resources/views/layouts/admin.blade.php` が該当する。`layouts/app.blade.php` は
> `<livewire:layout.navigation />` を含むため自動注入が働く）。

> **Alpine の読み込みとは別に、`x-on:` を書くフォームには `x-data`（空でよい）が要る。**
> Alpine v3 は `x-data` スコープ内の要素しか `x-on:` / `x-bind:` 等のディレクティブを
> 処理しない。`livewire.js` が読み込まれ Alpine が起動していても、`x-data` の無い素の
> `<form x-on:submit="confirm(...) || $event.preventDefault()">` は**エラーも出さず無視され、
> 確認ダイアログが出ないまま削除・却下・返却が実行される**。削除確認等のフォームは
> 必ず `<form x-data x-on:submit="...">` の形にすること（`layouts/app.blade.php` を使う
> `lendings/show` の返却フォームでも、`@livewireScripts` を持つ管理画面でも、いずれも
> `x-data` が無ければ発火しない。Phase 3 のトライアルで Dusk が
> `Waited 5 seconds for dialog.` で失敗して判明）。ナビの `x-data="{ open: false }"` は
> nav 要素にスコープされるため、その外側にあるフォームには効かない。

> **Livewire は v3 系を使う。** 上流の最新は v4 系だが、`breeze:install livewire` が
> `composer require livewire/livewire:^3.6.4` を実行して制約を書き込むため
> （`vendor/laravel/breeze/src/Console/InstallsLivewireStack.php`）。**これは意図した状態であり、
> `composer.json` に v3 が入っているのを「古い」と判断して上げないこと。**
>
> なお `livewire/volt` 自身の制約は `^3.6.1|^4.0` で v4 も許容している。**volt が v3 を
> 強制しているわけではない**ため、`composer require livewire/livewire`（制約なし）を
> 後から実行すると Breeze の `^3.6.4` を上書きして v4 が入ってしまう。v4 へ移行する場合は
> Breeze 側の対応を確認したうえで、Phase 3 の Livewire コンポーネントの記法差分を
> 検証すること。

`livewire/livewire` と `livewire/volt` はどちらも手動追加せず、`breeze:install livewire`（Phase 1）が `composer.json` の `require` へ追加する（`livewire/livewire:^3.6.4` / `livewire/volt:^1.7.0`）。いずれもトップレベルの依存として入るため、自前の Livewire コンポーネントを書くうえで別途 `composer require` する必要はない。Breeze はこれを使って認証画面を単一ファイルコンポーネント（`resources/views/livewire/pages/auth/*.blade.php`）として生成する。本プロジェクトで新規に書く Livewire コンポーネントは Volt 記法ではなくクラスベース（`app/Livewire/`）に揃える（`docs/architecture.md` のディレクトリ規約参照）。

### 公式スターターキットを採用しない理由

Laravel 12 以降、`laravel new` は公式スターターキット（Livewire / React / Vue）を選択できる。**本プロジェクトではこれを採用せず、素の Laravel に Breeze を後入れする**（Phase 1 の `--no-interaction` がキット選択をスキップするのは意図した挙動）。

公式 Livewire スターターキット（`laravel/livewire-starter-kit`、2026-07-19 時点）の構成と、本プロジェクトの方針との差:

| パッケージ | 差分 |
|---|---|
| `laravel/fortify` | 認証ロジックが vendor 側にあり、Controller / Form Request / ビューが publish されない |
| `livewire/flux` | UI コンポーネントライブラリ。`team-rules/coding-standards.md` の「Tailwind のユーティリティを基本とし、共通化は Blade コンポーネント」と競合する。Pro 版は有料 |
| `livewire/livewire ^4.1` | 本プロジェクトは v3 系（前掲の理由による） |
| `phpunit/phpunit` | 本プロジェクトは Pest |

採用しない理由は次の 2 点。

1. **本プロジェクトは Laravel の学習を兼ねる。** Breeze は認証の Controller・Form Request・ビューを `app/` と `resources/` へ publish するため、コードを読んで変更できる。Fortify はそれを vendor に隠し、設定で振る舞いを変える形になるため、認証の流れを追う教材にならない。
2. **Flux を入れると Blade コンポーネントと Tailwind を自分で組む機会が失われる。** `docs/screens.md` のレイアウト定義も `team-rules/coding-standards.md` の CSS 方針も、素の Blade + Tailwind を前提にしている。

> **`laravel/breeze` は非推奨でもアーカイブでもない。** 2026-07-19 時点の最新 v2.4.2（2026-05-14 リリース）が `illuminate/* ^11.0|^12.0|^13.0` として Laravel 13 を明示サポートしており、`breeze:install livewire` も現行の 2.x に存在する。`composer.json` に Breeze があるのを「メンテナンスが止まったパッケージ」と判断して公式スターターキットへ差し替えないこと。

### 公式のエージェント向けプレイブックとの差分

Laravel 公式は AI コーディングエージェント向けの手順書を
[laravel.com/for/agents](https://laravel.com/for/agents) で配布しており、インストールガイドは
「このページを取得して source of truth として扱え」というプロンプトをエージェントに
貼ることを勧めている。

**本プロジェクトではこのプロンプトを使わない。** 前提が複数の点で食い違っており、
そのまま従うと下表の決定がすべて上書きされる。2026-08-05 時点の記述との対比。

| 項目 | 公式プレイブック | 本プロジェクト | 理由 |
| --- | --- | --- | --- |
| 生成コマンド | `laravel new example-app --database=sqlite --react --npm --boost --no-interaction` | `laravel new tmp-skeleton --no-interaction --pest` | 差分の内訳は以下の各行 |
| スターターキット | **React が既定**（Vue / Livewire / Svelte は要求時） | 採用しない。素の Laravel + Breeze を後入れ | 前節参照。`CLAUDE.md` の「JS フレームワークを導入しない」とも衝突する |
| データベース | `--database=sqlite` | MySQL（Docker） | MySQL 固有の DDL（`docs/db-schema.md` の CHECK 制約）を使う。`phpunit.xml` の SQLite 既定も書き換える |
| PHP の導入 | `php.new` で 8.5 を入れる | `.tool-versions` で 8.4.23 を固定 | 開発者間でバージョンを揃えるため |
| Laravel Boost | `laravel new --boost` | `composer require --dev` → `boost:install --mcp --guidelines` | ガイドラインの出力先を `config/boost.php` で `docs/boost-guidelines.md` へ退避する必要がある（`CLAUDE.md` を Boost に再生成させない） |
| デプロイ | `composer global require laravel/cloud-cli` + `cloud skills:install` | 行わない | グローバル環境を変更する。デプロイ先を定めていない |
| テスト | 言及なし | Pest（`--pest`） | — |

一方、次の考え方は妥当なので手順に反映してよい。

- 作業前に `php` / `composer` / `laravel` / `npm` のバージョンを確認する
- 既に Laravel アプリがあるならインストールを飛ばす
- ガイドラインはセッション内で読み込み、再起動を求めない
  （`CLAUDE.md` の `@docs/boost-guidelines.md` で達成済み）

> **このページはいつでも更新されうる。** 上表は取得時点のもので、追随の義務は負わない。
> 公式の記述が変わったからといって本プロジェクトの決定を自動的に変えないこと。
> 変更が必要と判断した場合は、この表を更新したうえでユーザーに提示する。

### 開発・テスト用

| パッケージ | 用途 | 手動追加 | 種別 |
|---|---|---|---|
| `laravel/pint` | Lint（コードスタイル） | — | `laravel new` の既定に含まれる |
| `laravel/pao` | テストツール（pint / pest / phpstan）の実行結果を Agent 向けの JSON 1 行で出力する | — | `laravel new` の既定に含まれる |
| `larastan/larastan` | 静的解析（PHPStan の Laravel 版） | ✅ | `require-dev` |
| `pestphp/pest` | テストフレームワーク | ✅（`--pest` オプションで導入） | `require-dev` |
| `pestphp/pest-plugin-laravel` | Pest の Laravel 統合 | ✅（`--pest` に同梱） | `require-dev` |
| `pestphp/pest-plugin-drift` | PHPUnit 記法から Pest 記法への変換 | ✅（`--pest` に同梱。Installer が変換に使う） | `require-dev` |
| `laravel/dusk` | システムテスト（Capybara + Selenium 相当） | ✅ | `require-dev` |
| `laravel/boost` | AI エージェント向けの MCP サーバー（DB スキーマ・ログ・ドキュメント検索）と AI ガイドライン生成 | ✅ | `require-dev` |

> **`laravel/pao` は `^1.1.3` 以上に固定する**（Phase 1 の Step 8 で引き上げる）。`laravel new` の
> 既定は `^1.0.6` だが、**v1.1.2 以前は全件パスでも `php artisan test` の終了コードが 1 になる**
> （v1.1.3 / 2026-07-29 で解消）。本プロジェクトは完了基準をすべて終了コードで判定するため、
> 下限を上げないと **green のテストを失敗と誤認する**。この制約を下げないこと。
>
> **カバレッジの `--min` については、pao の JSON の `result` フィールドだけが嘘をつく**（こちらは
> 別問題で未解消）。`--min` 未達でも `"result":"passed"` を返す。終了コードと `raw` は正しいので、
> **終了コードで判定すれば `--min` は使える**。詳細は後述の「テストカバレッジ設定（正規形）」参照。

カバレッジ計測ドライバの **PCOV は composer パッケージではなく PHP 拡張**のため、この表ではなく「ランタイム」表に記載している（マシン側の前提条件であり、`composer install` では導入されない）。

> **`laravel/boost` の導入範囲**: Phase 1 の `boost:install --mcp --guidelines` により、MCP サーバー設定（`.mcp.json`）と AI ガイドライン（`docs/boost-guidelines.md`）だけを生成する。**Agent Skills（`--skills`）は導入しない** — 出力先の `.claude/` はヘッドレス実行で書き込めず、かつテンプレートへコミットすると `boost:update` の同期責任が人手に残るため。
>
> ガイドラインの出力先は `config/boost.php` で `CLAUDE.md` から `docs/` へ退避させている（`CLAUDE.md` はテンプレートの成果物であり Boost に再生成させない）。Boost のガイドラインのうち本プロジェクトの方針と衝突する 2 つは `.ai/guidelines/` で上書きしている。

> | 上書きファイル | 対象 | 理由 |
> |---|---|---|
> | `.ai/guidelines/volt/core.blade.php` | `volt/core rules` | 新規コンポーネントに Volt を使わない方針 |
> | `.ai/guidelines/boost/core.blade.php` | `boost rules` | v2.5.0 の `## Project Rules` が、**存在しない `.ai/rules/index.md` を開くことを MUST として要求する**ため。ルールの置き場を増やさず `team-rules/` と `docs/` に一本化する |
>
> 上書きファイルのパスは Boost 内部のガイドラインキーに対応する（`boost` 節は `boost/core.blade.php`）。**節見出しの名前（`=== boost rules ===`）とは一致しない**ので、パスは `vendor/laravel/boost/src/Install/GuidelineComposer.php` の対応表で確認すること。上書き時は Boost 側の有用な記述（MCP ツールの説明等）を書き写して維持する。
>
> **`team-rules/` と `docs/*.md` が優先、Boost は補完**という関係を保つこと。

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

ローカル開発環境として以下の公式・準公式ツールを検討した上で、「ホスト側 PHP（asdf / mise）+ DB のみ Docker」の構成を採っている。知らずに外したのではなく、選ばなかった理由は次のとおり。

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

Laravel の `migrate` はデータベース自体の作成を行わないため、**両データベースとも DB コンテナの初回起動時に作成する**。`bookkeeper` は `compose.yaml` の `MYSQL_DATABASE`、`bookkeeper_test` は `docker/mysql/initdb/01-create-test-database.sql`（`docker-entrypoint-initdb.d` にマウント）が担当する。これにより、クローン直後に `composer run setup` を実行するだけで `php artisan test` まで動く。

> `docker-entrypoint-initdb.d` のスクリプトは**データディレクトリが空のときにしか実行されない**。init スクリプトを追加・変更した場合は `docker compose down -v` でボリュームを作り直さないと反映されない。

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

### 80% 判定の規約

**判定は `vendor/bin/pest --coverage --min=80` の終了コードで行う**（未達なら 1、達していれば 0）。

```sh
vendor/bin/pest --coverage --min=80
```

> **`laravel/pao` が整形する JSON の `result` フィールドは信用してはならない。**
> `--min` 未達でも `{"tool":"pest","result":"passed",...}` を返す。一方で**終了コードは 1 になり、
> `raw` 配列の末尾に `Total: NN.N %` と `FAIL Code coverage below expected 80.0 %...` が入る**ので、
> そちらを見れば正しく判定できる（実カバレッジ 91.9% に対し `--min=95` を指定して確認済み）。
> `result` を見て合否を決めると、**未達を「達成」と誤認する**。

HTML レポート（`coverage/index.html`）は数値の内訳を見るために使う。どのディレクトリが低いかを
特定して埋める用途で、合否判定の一次情報ではない。

具体的な実行手順と出力例は `.claude/commands/scaffold-phase4-finalize.md` の手順 6-3 参照。

未導入の場合の導入手順（**PHP ランタイム全体に影響する変更のため、必ず事前にユーザーへ確認する**）:

```sh
pecl install pcov
# php --ini で表示される conf.d 配下の ini に extension=pcov.so を追記する
php -m | grep pcov   # 追記後、pcov が出れば有効
```

バージョンマネージャ（asdf / mise 等）で PHP を管理している場合、拡張はその PHP
インストールに紐づく。**PHP を入れ直すと拡張も失われる**ため、再導入が必要になる。
