---
description: フェーズ1 - Laravel 雛形を生成し依存を導入する（DB は Docker 上の MySQL）
---

# Phase 1: スケルトン生成

`docs/setup.md` と `docs/stack.md` の技術スタックに従って、Laravel アプリの雛形を作成する。
DBMS は **MySQL 8.x** を **Docker コンテナ** で起動して利用する。
Laravel 本体はホスト側で動かす。

> **実行場所**: 本手順書のコマンドは、断りが無い限りすべて **`my-laravel-app/` をカレント**として
> 書かれている。Bash ツールのカレントは呼び出しをまたいで持続するので、**最初に一度だけ**
> `cd my-laravel-app` し、以降は移動しない（ルートにも別物の `bin/` があり、そこから
> `bin/check-repo.sh` を打つと `exit 127` になる）。

## 前提

以下はテンプレートに同梱済み。Phase 1 で新規作成しない:

- `my-laravel-app/compose.yaml`
- `my-laravel-app/docker/mysql/conf.d/.keep`
- `my-laravel-app/.tool-versions`
- `my-laravel-app/.gitignore`（`.env` 除外・カバレッジ除外など含む）
- `my-laravel-app/.npmrc`（npm のサプライチェーン対策 `ignore-scripts=true` / `audit=true`）
- ルート直下の `.tool-versions`, `env.example`, `.gitignore`

これらの内容を確認・編集する必要はない（中身は `docs/stack.md` / `docs/setup.md` の規約に合致した状態でコミット済み）。

## 実行手順

### 1. 事前確認

`my-laravel-app/` で次を実行する。

```sh
bin/doctor.sh
```

**終了コードが 0 でなければ先へ進まない。** `[NG]` の項目と対処が出力されるので、その内容を
**ユーザーに提示して解消を依頼し、解消後に再実行する**。`[WARN]` は続行してよい。

検査項目は、PHP のバージョンと `zip` / `pcov` 拡張、Composer 2 系、Node.js のバージョンと
バージョンマネージャの併存、Docker デーモンと Compose v2、DB ポートの空き、
DB ボリュームの衝突。バージョンの一次情報は `.tool-versions` で、スクリプトがそこから読む
（**この手順書にもスクリプトにも数値を書かない**）。

> **このスクリプトは何も変更しない（読み取りのみ）。** 何度実行しても同じ結果になるので、
> 対処のたびに再実行してよい。ホストの PHP への拡張追加のようにホスト全体へ影響する変更は、
> **対処として案内するだけで実行はしない**（実行はユーザーの判断）。
>
> `[WARN]` の 2 つは意味が異なる。**pcov 未導入**は Phase 5 のカバレッジ 80% 判定にのみ必要で、
> Phase 1〜4 は影響を受けない（必須チェックは Phase 5 の Step 2-0 にあり、そこでは未導入なら中断する）。
> **DB ボリュームの残存**は初回セットアップ時のみ問題になる（詳細は次節「起動失敗時の典型原因」）。

### 2. DB コンテナの起動

`my-laravel-app/` ディレクトリで以下を実行:

1. `docker compose up -d --wait db` で DB コンテナを起動する。`--wait` は `compose.yaml` の `healthcheck`（`mysqladmin ping`）が healthy を報告するまでブロックするため、**待機用のシェルループを自前で書かないこと**。
   - 準備完了の判定条件を `compose.yaml` の 1 箇所に集約でき、`composer run setup`（Step 8）とも同じ書き方に揃う
   - `for i in $(seq 1 30); do ... done` のようなループは Claude Code の Bash ツールでは変数展開のガード（`Contains simple_expansion`）に掛かって実行できない。スクリプトファイル内に書く場合を除き使わない
   - healthy にならないまま終了した場合、`--wait` は非 0 で終了する。`docker compose logs db` で原因を確認する
2. `docker compose exec -T db mysql -uapp -papp_password bookkeeper -e "SELECT 1"` で `app` ユーザが `bookkeeper` データベースに実際にアクセスできることを確認する（データベース名を指定せずに `SELECT 1` するだけではログイン可否しか確認できず、後述のボリューム衝突による権限不足を見逃す）

起動失敗時の典型原因:
- ポート競合（`docker compose logs db` で確認）
- ボリュームに前回データが残っていてユーザ作成がスキップされた（`docker compose down -v` で初期化）
- **Docker named volume の衝突**: `my-laravel-app` という同名ディレクトリが複数ある場合（git worktree・複数クローン）、Compose のプロジェクト名が basename 由来のため同じボリュームを共有し、`app` ユーザーの初期化がスキップされる（`SHOW GRANTS FOR 'app'@'%';` で確認できる）。`docker compose down -v` で解消する。worktree で並行して試す場合は `COMPOSE_PROJECT_NAME` を worktree ごとに変える

### 3. Laravel アプリ生成

`my-laravel-app/` は既にテンプレート同梱ファイル（`CLAUDE.md`, `docs/`, `.claude/`, `compose.yaml`, `docker/`, `.gitignore`, `.npmrc` 等）で空でないため、一時サブディレクトリに生成してから直下へ配置する:

```sh
composer create-project -q laravel/laravel:^13.0 tmp-skeleton --remove-vcs --prefer-dist --no-scripts
```

> **`-q` を省略しないこと（本手順書の `composer` 全般）。** 成功時のみ無音になり、失敗時は
> 例外がそのまま出るため切り分けは失われない。導入されたバージョンの確認は、出力ではなく
> `composer.json` / `composer.lock` を一次情報とする。
>
> **`-q` はサブコマンドの後ろに置くこと**（`composer create-project -q ...`）。許可リストは
> `Bash(composer create-project*)` の前置一致なので、`composer -q create-project ...` は
> **一致せずヘッドレスで承認待ちになる**（`git -c` を前置した場合と同じ理由）。

**`laravel new` は使わない。** バージョン指定オプションが無く、常に最新安定版が入るため 13 系に固定できない。

> **`--no-scripts` を省略しないこと。** `laravel/laravel` の `post-create-project-cmd` は
> `database/database.sqlite` を作って `migrate --graceful` を **SQLite に対して**実行する。
> 本プロジェクトは MySQL なのでどちらも不要。

生成完了後、`rsync` で全生成物（ドットファイル含む）を `my-laravel-app/` 直下へ配置し、一時ディレクトリを削除する:

```sh
rsync -a --exclude=/.gitignore --exclude=/.npmrc tmp-skeleton/ .
git clean -fdxq tmp-skeleton
ls -a .env.example artisan composer.json composer.lock phpunit.xml
```

最後の `ls` は配置が成功したことの確認。1 つでも「No such file」になる場合は先に進まず、原因を調べること（`.env` はまだ存在しない。次の初期化で作る）。

> **この配置を `mv` と glob で書かないこと**（`mv tmp-skeleton/* .` はドットファイルを
> 含まず `.env` を取りこぼす。Bash ツールも書き込み系の glob を拒否する）。`rsync -a` は
> 末尾スラッシュ付きの指定でドットファイルごと再帰コピーする。

**`--exclude` は必ず指定する。** `laravel/laravel` 同梱の `.gitignore` / `.npmrc` ではなく、テンプレート同梱版を正とするため（先頭 `/` は転送元ルート直下のみを対象にする指定で、`storage/framework/*/.gitignore` 等は除外されない）。

配置後、テンプレート同梱ファイルが無傷であることを確認する:

```sh
git status --short -- .gitignore .npmrc .claude compose.yaml docker .tool-versions CLAUDE.md docs
```

何も出力されなければ正常。差分が出た場合は `git checkout -- <path>` で戻す。

#### 初期化とテストフレームワークの導入

`--no-scripts` で飛ばした初期化を実行する:

```sh
composer run post-root-package-install
php artisan key:generate --ansi
```

前者が `.env.example` を `.env` へコピーし、後者が `APP_KEY` を生成する。

続いてテストフレームワークを PHPUnit から Pest へ入れ替える:

```sh
composer remove -q phpunit/phpunit --dev --no-update
composer require -q pestphp/pest pestphp/pest-plugin-laravel --no-update --dev
composer update -q
vendor/bin/pest --init
composer require -q pestphp/pest-plugin-drift --dev
vendor/bin/pest --no-output --no-progress --drift
composer remove -q pestphp/pest-plugin-drift --dev
```

`--drift` は `laravel/laravel` 同梱の PHPUnit 形式のテストを Pest 記法へ変換する。変換が済めば plugin は不要なので外す。

> **`--no-output --no-progress` を省略しないこと。** `laravel/pao` がエージェント実行と判定して
> この 2 つを自動追記するため、省略すると `pest-plugin-drift` の引数数と衝突して
> `The [--drift] argument only accepts the directory to convert as argument.` で必ず失敗する。
> 先に明示しておけば pao 側は追記しない。

> **`./vendor/bin/pest` と書かないこと。** 許可リストは `Bash(vendor/bin/pest*)` の前置一致なので、
> `./` を付けた形や環境変数を前置した形（`PEST_NO_SUPPORT=true ./vendor/bin/pest ...`）は一致せず、
> ヘッドレスでは承認待ちで止まる。

> **`APP_URL` は自動では設定されない。** Step 7 で `.env` / `.env.example` の両方を
> `http://localhost:8000` に揃えること。

### 4. config/database.php の調整

`docs/setup.md` の「MySQL 設定の規約」セクションに記載の正規形に合わせて `mysql` 接続設定を修正する。

**構造には手を入れない。`env()` の第 2 引数（既定値）を 4 か所書き換えるだけである**（`laravel/laravel` の生成物は既に `charset` / `collation` も `env()` 経由になっている）:

| キー | `laravel/laravel` の既定値 | 書き換え後 |
|---|---|---|
| `database` | `'laravel'` | `'bookkeeper'` |
| `username` | `'root'` | `'app'` |
| `password` | `''` | `'app_password'` |
| `collation` | `'utf8mb4_unicode_ci'` | `'utf8mb4_0900_ai_ci'` |

`charset` の既定値は `'utf8mb4'` で既に正しいため変更不要。`url` / `unix_socket` / `prefix_indexes` / `options` の各行は**生成されたまま残す**（削除しない）。

> **注意（`mariadb` 接続をつられて書き換えないこと）**: `config/database.php` の `mariadb` ブロックは
> `mysql` ブロックと**行の内容が完全に一致する**。Edit ツールで置換する場合、`'database' => env('DB_DATABASE', 'laravel'),`
> のような 1 行だけを対象にすると一意に定まらず失敗する。`'driver' => 'mysql',` の行を含む
> ブロック全体を対象にして、`mysql` 側だけを書き換えること。

> **注意**: `'url' => env('DB_URL')` の行は残すが、`.env` に `DB_URL` の値は設定しない（Step 7 の注意参照）。行の存在と値の設定は別問題であり、行を消す必要はない。

### 5. Composer パッケージの追加

`docs/setup.md` の「手動追加」列が ✅ のパッケージを追加する:

```sh
composer require -q spatie/laravel-query-builder blade-ui-kit/blade-heroicons
composer require -q --dev -W larastan/larastan laravel/dusk laravel-lang/lang laravel/boost
```

> `laravel/boost` は、AI エージェント向けの MCP サーバー（DB スキーマ・ログ・Laravel
> エコシステムのドキュメント検索）と AI ガイドラインを提供する。導入手順は Step 6 参照。

> **`livewire/livewire` / `livewire/volt` は手動で `composer require` しない。**
> Step 6 の `php artisan breeze:install livewire` が `^3.6.4` / `^1.7.0` の制約付きで
> `composer.json` へ追加する。手動追加すると Breeze の制約を上書きして v4 系が入る。

### 6. 各種初期化

- **Laravel Breeze（Livewire スタック）**:
  ```sh
  composer require -q laravel/breeze --dev
  php artisan breeze:install livewire --no-interaction
  ```
  このコマンドで認証ビュー（ログイン・登録・パスワードリセット等）が Livewire コンポーネントとして生成され、Tailwind CSS と Alpine.js のセットアップも同時に行われる。`npm install` と `npm run build` も内部で実行される。非 TTY 環境では `WARN TTY mode requires /dev/tty to be read/writable.` が出るが処理は継続するので無視してよい。

  このコマンドは `livewire/livewire:^3.6.4` と `livewire/volt:^1.7.0` を `composer.json` の `require` へ追加する。**どちらも別途 `composer require` しないこと**（Step 5 の注記参照）。導入後に `composer.json` の `livewire/livewire` が `^3.6.4` になっていることを確認する。

  > **`breeze:install` が追加する `dashboard` / `profile` の 2 ルートは、Phase 1 の時点ではそのまま残す**（`docs/api-spec.md` の仕様には無いが、置き換えと参照側の追従は Phase 3 の担当）。
- **laravel-lang（日本語化）**:
  ```sh
  php artisan lang:add ja --no-interaction
  ```
  `config/app.php` の `'locale'` / `'faker_locale'` は Laravel 13 では `env('APP_LOCALE', 'en')` / `env('APP_FAKER_LOCALE', 'en_US')` として `.env` を参照する。したがって値の切り替えは **`.env` 側で行う**（Step 7 で `APP_LOCALE=ja` / `APP_FAKER_LOCALE=ja_JP` に変更する）。**`config/app.php` のハードコード編集は不要**（`.env` が優先されるため）。
- **Laravel Dusk**:
  ```sh
  php artisan dusk:install --no-interaction
  php artisan dusk:chrome-driver --detect
  ```
  `dusk:install` は ChromeDriver も自動でインストールするが、入るのは**最新版**である。

  > **重要（`dusk:chrome-driver --detect` を必ず続けて実行する）**: ホストの Google Chrome が 1 世代古いと、`dusk:install` が入れた ChromeDriver とメジャーバージョンが噛み合わず、Phase 4 の `php artisan dusk` が全件
  > `session not created: This version of ChromeDriver only supports Chrome version NNN / Current browser version is MMM ...`
  > で失敗する。`--detect` はホストにインストールされた Chrome のバージョンを検出して対応する ChromeDriver を入れ直すため、Phase 1 の時点で実行しておく（Chrome を更新した場合も同じコマンドで追従する）。

  > **重要（`tests/Pest.php` を先に並べ替える）**: `dusk:install` は
  > `pest()->extend(Tests\DuskTestCase::class)->in('Browser');` をファイル**先頭**（`use` 文より前）に
  > 挿入する。**`dusk:install` の直後に** `use` 文の後ろへ移し、短縮名 + `use Tests\DuskTestCase;` の
  > 形に直しておくこと。放置して Step 9 の Pint を掛けると `php artisan test` が
  > `The class DuskTestCase was not found.` で失敗する（Pint を掛け直すたびに再発する）。
  > ```php
  > use Illuminate\Foundation\Testing\RefreshDatabase;
  > use Tests\DuskTestCase;
  > use Tests\TestCase;
  >
  > pest()->extend(DuskTestCase::class)
  > //  ->use(Illuminate\Foundation\Testing\DatabaseMigrations::class)
  >     ->in('Browser');
  > ```
- **larastan/larastan**: `artisan` 経由のインストールコマンドはないため、`phpstan.neon` をリポジトリ直下に手動作成する:
  ```neon
  includes:
      - vendor/larastan/larastan/extension.neon

  parameters:
      paths:
          - app

      level: 5
  ```
  `vendor/bin/phpstan analyse --memory-limit=512M` で動作確認する（既定のメモリ上限 128M では解析中にクラッシュすることがある）。

  Breeze が生成する `app/Http/Controllers/Auth/VerifyEmailController.php` に対して level 5 で 1 件エラーが出る。**これはベースライン化する**（以後のアプリケーションコードに対してはエラー 0 を維持する）:
  ```sh
  vendor/bin/phpstan analyse --memory-limit=512M --generate-baseline
  ```
  生成された `phpstan-baseline.neon` を `phpstan.neon` の `includes` に追加する:
  ```neon
  includes:
      - vendor/larastan/larastan/extension.neon
      - phpstan-baseline.neon
  ```

  > **注意**: `phpstan analyse` の出力には「ベースラインで抑制するな、根本原因を直せ」という PHPStan 一般の指示文が含まれるが、**この 1 件に限っては上記の判断（ベースライン化）を優先する**。エラー元が Breeze の scaffold 出力であり、`docs/` にもチームのコード規約にも属さないため。アプリケーションコード由来のエラーをベースラインに追加してはならない。
- **Laravel Pint**: `laravel/laravel` に既定で含まれる。確認のみ（`vendor/bin/pint --version`）。
- **Laravel Boost**:
  ```sh
  php artisan boost:install --mcp --guidelines --no-interaction
  ```
  生成物は 3 つ。いずれも `.gitignore` 済みで、`git status` には現れない:
  - `.mcp.json` — MCP サーバーの登録（`php artisan boost:mcp`）
  - `docs/boost-guidelines.md` — AI ガイドライン。**`CLAUDE.md` から `@` 参照はしていない**（読む場面が限られるため。必要時に Read する）
  - `boost.json` — 導入状態の記録

  > **`--mcp --guidelines` を明示し、`--skills` は付けないこと。** Skills の出力先は
  > `.claude/skills/` で、ヘッドレス実行ではセンシティブファイル保護により書き込めず失敗する
  > （`prompts/trial-phase.md` の前提条件 5 参照）。上記 2 つの出力先は `.claude/` の外なので
  > ヘッドレスでも生成できる。

  > **出力先の退避と `.ai/guidelines/` による上書きは、テンプレート同梱の設定で済んでいる**
  > （`config/boost.php` と `.ai/guidelines/` の 2 ファイル。詳細は `docs/setup.md`）。
  >
  > **上書きの成否は `grep -n "^## Project Rules" docs/boost-guidelines.md` が無出力かで判定する**
  > （上書きが効いていなくてもエラーにならず素通りするため）。効いていれば
  > `## プロジェクトのルール` に置き換わっている。**`grep "\.ai/rules"` で判定しないこと**——
  > 上書きファイル自身がその語を含むため、**成功していても必ずヒットする**。

### 7. .env の準備

生成された `.env` / `.env.example` に、ルート同梱の `env.example` の内容（`DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `MAIL_FROM_ADDRESS`）をマージする。あわせて `DB_CONNECTION` を `sqlite` から `mysql` に変更する。`APP_KEY` は上書きしない（Laravel が生成した値をそのまま使う。未設定なら次のコマンドで生成する）:

また、`APP_LOCALE=en` / `APP_FAKER_LOCALE=en_US` を `APP_LOCALE=ja` / `APP_FAKER_LOCALE=ja_JP` に変更する（Step 6 の注意参照。`config/app.php` の変更だけでは反映されない）。`APP_FALLBACK_LOCALE` は `en` のまま残す。

```sh
php artisan key:generate
```

`DB_DATABASE=bookkeeper` を追記する。`MAIL_MAILER` は Laravel 13 の `.env` では既定で `log` になっている（`docs/setup.md` の「メール確認」セクション参照）。既定から変わっている場合のみ `log` に設定する。

Laravel 13 の `.env` / `.env.example` は `DB_CONNECTION=sqlite` 以外の `DB_*` 行が**コメントアウトされた状態**で生成される。コメントを外した上で値を設定すること:

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=bookkeeper
DB_USERNAME=app
DB_PASSWORD=app_password
```

`.env` はテンプレート同梱の `.gitignore` で除外済み。`.env.example` は git 管理対象に含める（`APP_KEY=` は空のままにしておく）。**`.env` に加えた変更（`DB_*` / `APP_LOCALE` / `APP_FAKER_LOCALE` / `MAIL_FROM_ADDRESS`）は `.env.example` にも同じく反映する**（`team-rules/security.md` の「`.env.example` をリポジトリに含めて同期する」）。

> **注意: `APP_URL` も同期対象。** `.env` は `.env.example` のコピーなので値は一致するが、
> **両方とも `http://localhost:8000` である必要がある**（`laravel/laravel` の版によっては
> `http://localhost` = 80 番のことがある）。ずれていると `url()` / `route()` が 8000 番以外を
> 指し、パスワード再発行メールのリンクが到達しない。`APP_KEY` だけは `.env.example` を空のままにし、
> **`diff .env .env.example` の差分が `APP_KEY` の 1 行だけ**になる状態を正とする
> （`bin/check-repo.sh` が検査する）。

> **注意: `DB_URL`（接続文字列方式）を `.env` に追加しないこと**
>
> このプロジェクトの `config/database.php` は `DB_HOST` / `DB_USERNAME` / `DB_PASSWORD` / `DB_PORT` の個別変数で接続情報を受け取る設計になっている。
> Laravel 13 の既定 `mysql` 接続は `'url' => env('DB_URL')`（環境変数名は `DATABASE_URL` ではなく `DB_URL`）を持つが、URL 方式と個別変数方式を混在させると接続設定の優先順位が複雑になりデバッグが困難になる。
> プロジェクト全体で個別変数方式に統一するため、`DB_URL` は設定しないこと。

### 8. composer.json の dev / setup スクリプトの調整

開発サーバーの起動もセットアップも、`laravel/laravel` 既定の `composer.json` のスクリプト（`composer run dev` / `composer run setup`）を使う。**自前のラッパースクリプト（`bin/dev`・`bin/setup` 等）は作らない**（`composer.json` 側との二重管理になるため。`docs/setup.md` の「開発サーバー起動（正規形）」「初回セットアップ（正規形）」参照）。既定の生成物を本プロジェクトの方針に合わせて編集する。

**`scripts.dev`**: **`composer.json` は書き換えない。** Laravel 13.17 以降の `laravel/laravel` が生成する `dev` は、`concurrently` の直書きではなく Laravel 本体の `php artisan dev` への委譲になっている:

```json
"dev": [
    "Composer\\Config::disableProcessTimeout",
    "@php artisan dev"
]
```

起動するプロセスは `Illuminate\Foundation\DevCommands::registerDefaults()` が登録する `server` / `queue` / `logs` / `vite` の 4 つで、**`composer.json` に `queue:listen` という文字列は存在しない**。`docs/setup.md` の規約（Queue ワーカーを起動しない）に従うため、`app/Providers/AppServiceProvider.php` の `boot()` で除外する:

あわせて `docs/stack.md` の「Eloquent の strict 設定」に従い、mass assignment の取りこぼしを例外にする 1 行も同じ `boot()` に置く。

```php
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\DevCommands;

public function boot(): void
{
    // docs/setup.md の方針により Queue ワーカーは起動しない。
    // composer run dev → php artisan dev の対象から queue を外す。
    DevCommands::except('queue');

    // fillable 外の列を mass assignment したときに例外にする（既定は黙って捨てる）。
    Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction());
}
```

`php artisan dev:list` を実行し、`queue` が消えて `server` / `logs` / `vite` の 3 つになることを確認する。

> **`composer.json` の `dev` を `concurrently` 直書きへ戻さないこと。** 上流の既定へ書き戻す形にすると、次に上流の既定が変わったときに同じ陳腐化を繰り返す。

**`scripts.setup`**: 本プロジェクトは DB を Docker で動かし、かつ Seeder 込みで「最初から動く状態」にするため、既定の生成物に次の 3 点を変更する:

1. **先頭に `docker compose up -d --wait db` を足す**
2. **`@php artisan migrate --force` を `@php artisan migrate --seed --force` にする**
3. **`@php artisan boost:install --mcp --guidelines --no-interaction` を足す** — `.mcp.json` と `docs/boost-guidelines.md` は `.gitignore` 済みで、クローンした利用者の手元には存在しないため。Step 6 と重複するが冪等なので問題ない

変更後:

```json
"setup": [
    "docker compose up -d --wait db",
    "composer install",
    "@php -r \"file_exists('.env') || copy('.env.example', '.env');\"",
    "@php artisan key:generate",
    "@php artisan migrate --seed --force",
    "@php artisan boost:install --mcp --guidelines --no-interaction",
    "npm install --ignore-scripts",
    "npm run build"
]
```

`npm install --ignore-scripts` は既定のまま残す（`.npmrc` の `ignore-scripts=true` と方針が一致するため）。

> **`setup` の `key:generate` は既存の `APP_KEY` を毎回作り直す。** Step 9-7 で 2 回流すと
> `APP_KEY` は 2 回とも別の値になるが、**これは異常ではない**（`diff .env .env.example` の差分が
> `APP_KEY` の 1 行だけ、という判定には影響しない）。

**`require-dev` の `laravel/pao` の制約を `^1.1.3` へ引き上げる。**

```sh
composer require -q --dev "laravel/pao:^1.1.3" --no-interaction
```

既定は `^1.0.6` だが、**v1.1.2 以前は全件パスでも `php artisan test` の終了コードが 1 になる**
（詳細は `docs/setup.md`）。完了基準を終了コードで判定するため、下限を保証しておく。

### 9. DB の作成と起動確認

1. **データベースの確認**（`bookkeeper` は `compose.yaml` の `MYSQL_DATABASE` が、`bookkeeper_test` は `docker/mysql/initdb/01-create-test-database.sql` がそれぞれ自動作成する。手動作成は不要）:
   ```sh
   docker compose exec -T db mysql -uroot -proot_password -e "SHOW DATABASES LIKE 'bookkeeper%';"
   ```
   `bookkeeper` と `bookkeeper_test` の 2 つが並ぶこと。

   > **`bookkeeper_test` が無い場合は、既存ボリュームを使い回している**。`docker-entrypoint-initdb.d` の
   > スクリプトは**データディレクトリが空のときにしか実行されない**ため、init スクリプト追加より前に
   > 作られたボリュームには適用されない。`docker compose down -v` でボリュームごと作り直してから
   > `docker compose up -d --wait db` し直すこと（開発用 DB のデータも消えるが、Phase 1 時点では
   > 失うものが無い）。

   > **重要（phpunit.xml のテスト DB 設定）**: 生成される `phpunit.xml` は既定で `DB_CONNECTION=sqlite` / `DB_DATABASE=:memory:` を設定しており、**このままだとテストが SQLite で走る**。**Phase 1 では表面化しないが、MySQL 固有の DDL を使う Phase 2 で必ず壊れる**ので、ここで書き換える:
   > ```xml
   > <env name="DB_CONNECTION" value="mysql"/>
   > <env name="DB_DATABASE" value="bookkeeper_test"/>
   > ```
   > （`DB_URL` の env が空文字で定義されている場合はそのままでよい。）
2. `php artisan migrate`
   - 失敗時の典型原因: コンテナ未起動 / `.env` の認証情報不一致 / Step 2 で触れた Docker named volume の衝突（`Access denied for user 'app'@'%' to database 'bookkeeper'` のようなエラーが出る場合はこれを疑う）
   - エラー時は勝手に MySQL のユーザー権限をいじらず、状況を報告して指示を仰ぐ
3. **Pint による自動修正**: `vendor/bin/pint` を実行する。アプリ生成 / `breeze:install` / `lang:add` が生成するファイル（`bootstrap/providers.php`, `lang/ja/*.php` 等）はデフォルトで Pint の規約に違反しているため自動修正が入る。その後 `vendor/bin/pint --test` が 0 件になることを確認する。
   - Step 6 の指示どおり `tests/Pest.php` を先に並べ替えてあれば、Pint はこのファイルを書き換えない。書き換えられた場合は並べ替えが漏れているので Step 6 に戻ること
4. `php artisan test` が green であることを確認する。

   > **終了コード 1 は本物の失敗として扱う。**握り潰さずに原因を追うこと。Step 8 で
   > `laravel/pao` を `^1.1.3` 以上に固定してあるため、v1.1.2 以前の既知事象
   > （全件パスでも 1 が返る）はもう起きない。
5. **起動確認**: `composer run dev` をバックグラウンドで立ち上げ、次の 2 つを**それぞれ 1 呼び出しで**実行する。

   ```sh
   curl -sS --retry 15 --retry-all-errors --retry-delay 1 -o /dev/null -w "/: %{http_code}\n" http://localhost:8000; curl -sS -o /dev/null -w "/login: %{http_code}\n" http://localhost:8000/login; curl -sS -o /dev/null -w "/register: %{http_code}\n" http://localhost:8000/register
   ```

   3 つとも 200 になること。確認後サーバを停止する（最初の 1 つで残りも終了するが、3 つとも実行して確実に止める）。

   ```sh
   pkill -f "php artisan serve"; pkill -f "artisan pail"; pkill -f vite
   ```

   - `--retry` を付けるのは、`composer run dev` の起動直後は `php artisan serve` がまだ listen していないため。Bash ツールでは `sleep` を伴う待機ループが書けないので `curl` 側のリトライで吸収する
   - **停止まわりの終了コード 1 はすべて正常。フェーズの失敗として扱わず、原因を追わないこと。** 1 つ目の `pkill` で残りのプロセスも終了するため 2 つ目以降は「該当プロセス無し」で 1 を返し、同じ理由でバックグラウンド実行の完了通知も `failed`（`php artisan dev` 自体の非 0 終了）になる
6. **既定 `DatabaseSeeder` の空化**: 既定の `run()` は固定メールの Test User を `create()` で 1 件作るため、**`composer run setup` を 2 回目に実行すると `users.email` の UNIQUE 制約違反で落ちる**。`run()` の本体をコメント化して空にすること（Seeder 本体は Phase 5 で `docs/seeds.md` に沿って実装する）:
   ```php
   public function run(): void
   {
       // Seeder は Phase 5 で docs/seeds.md に沿って実装する。
       // laravel/laravel 既定の Test User 生成は、setup 再実行時に
       // users.email の UNIQUE 制約へ衝突するため空にしておく。
   }
   ```
   `run()` を空にすると `use App\Models\User;` が未使用になる。**この import も併せて削除する**
   （残すと Pint の `no_unused_imports` が Step 9-3 で外しにくる）。この編集は 9-3 の Pint 実行より
   後なので、**編集後に `vendor/bin/pint --test` を掛け直して 0 件を確認する**こと。
7. **`composer run setup` の一気通貫確認**: `composer run setup` を実行し、DB 起動 → `composer install` → `.env` 用意 → `key:generate` → `migrate --seed` → `npm install` → `npm run build` が最後まで通ることを確認する（上記で空化したため Seeder は何も投入せず `Seeding database.` のみ出る）。**続けてもう一度 `composer run setup` を実行し、2 回目も同じく通る（非冪等で落ちない）ことを確認する。**
   - `.env` と `APP_KEY` は Step 7 で用意済みのため、`copy('.env.example', '.env')` は skip され `key:generate` は既存のキーを上書きする。**この確認の前に `.env` の内容（DB 接続情報）が `.env.example` と一致していることを確かめる**。一致していないと、既存の `.env` が残る挙動に助けられて「新規クローンでは通らない設定」を見逃す
   - 確認は `diff .env .env.example` で行う。**差分が `APP_KEY` の 1 行だけ**になっていれば正しい（`APP_URL` が差分に出た場合は Step 7 の注意を参照）
8. **git status の確認**: `git status --short` に、`.gitignore` で除外されるべき生成物（`public/hot`, `storage/pail`, `.phpunit.result.cache` 等）が現れていないことを確認する。現れた場合はテンプレートの `.gitignore` 側を補うこと。
   - この時点では Laravel の生成物一式（`app/`, `config/`, `public/` 等）がすべて未追跡として並ぶため、`git status` の表示はディレクトリ単位に畳まれる。個別の生成物が除外されているかは `git check-ignore -v <path>...` で確かめる

   ```sh
   git status --short; echo "=== check-ignore ==="; git check-ignore -v public/hot storage/pail .phpunit.result.cache; echo "=== coverage ==="; grep -n coverage .gitignore
   ```


## このフェーズの完了基準

まず `bin/check-repo.sh`（読み取りのみ）を実行し、終了コード 0 を確認してから以下を確認する。

コマンドで確かめる 3 項目は `&&` でつないで 1 呼び出しにする（`;` ではなく `&&` を使う。
`;` だと途中が落ちても最後のコマンドの終了コードしか返らず、失敗を取りこぼす）。
**`laravel/pao` が結果を JSON 1 行に整形するため出力は数十文字。`tail` で切らない。**

```sh
php artisan test && vendor/bin/pint --test && vendor/bin/phpstan analyse --memory-limit=512M
```

- [ ] `docker compose up -d --wait db` で DB が healthy になる
- [ ] `composer run setup` で DB 起動 → セットアップ完了まで一気通貫で動く
- [ ] `composer.json` の `scripts.setup` に `docker compose up -d --wait db` と `migrate --seed --force` が反映済み
- [ ] `composer run dev` で http://localhost:8000 が 200
- [ ] `php artisan migrate` が成功（`bookkeeper` データベースに対して）
- [ ] `bookkeeper_test` データベースが存在する（init スクリプトによる自動作成。手動作成していないこと）
- [ ] `phpunit.xml` の `DB_CONNECTION` が `mysql`・`DB_DATABASE` が `bookkeeper_test`（既定の sqlite / :memory: から変更済み）
- [ ] `.mcp.json` と `docs/boost-guidelines.md` が生成されている（`boost:install` が通っている）
- [ ] `docs/boost-guidelines.md` の Volt の節が、`.ai/guidelines/` による上書き後の内容
      （「新規コンポーネントはクラスベース」）になっている
- [ ] `docs/boost-guidelines.md` に `## Project Rules`（Boost 既定の節）が残っていない
      （`grep -n "^## Project Rules" docs/boost-guidelines.md` が無出力）
- [ ] `CLAUDE.md` が `boost:install` に書き換えられていない（`git status` に現れないこと）
- [ ] `composer.json` の `laravel/framework` が `^13.`（Step 3 の検証を通過している）
- [ ] `git status --short -- composer.lock` が `?? composer.lock` を返す（`.gitignore` で除外されていない）
- [ ] `composer.json` に `docs/setup.md` の「手動追加 ✅」パッケージがすべて記載
- [ ] Laravel Breeze（Livewire スタック）/ laravel-lang / larastan / Dusk の初期化済み
- [ ] `php artisan dusk:chrome-driver --detect` を実行済み（ホストの Chrome とバージョンが一致）
- [ ] `php artisan dev:list` に `queue` が**含まれていない**（`server` / `logs` / `vite` の 3 つ）
- [ ] `php artisan test` が green（終了コードで判定する）
- [ ] `composer.json` の `require-dev` の `laravel/pao` が `^1.1.3` 以上になっている
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse --memory-limit=512M` がエラー 0

## やらないこと

- モデル生成（Phase 2 で実施）
- Controller / View 生成（Phase 3 で実施）
- Seeder（Phase 5 で実施）
- Laravel 本体のコンテナ化（プロジェクト方針として行わない）
- Queue ワーカーの起動設定（本プロジェクトでは非同期ジョブを使わない）
- Redis / Reverb の追加
- 同梱ファイル（`compose.yaml`, `.tool-versions`, `env.example`, `.npmrc`）の編集

## 完了後

`/verify` を実行し、結果を報告。
