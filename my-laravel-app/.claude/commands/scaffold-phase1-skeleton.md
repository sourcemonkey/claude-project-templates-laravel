---
description: フェーズ1 - Laravel 雛形を生成し依存を導入する（DB は Docker 上の MySQL）
---

# Phase 1: スケルトン生成

`docs/stack.md` の技術スタックに従って、Laravel アプリの雛形を作成する。
DBMS は **MySQL 8.x** を **Docker コンテナ** で起動して利用する。
Laravel 本体はホスト側で動かす。

## 前提

以下はテンプレートに同梱済み。Phase 1 で新規作成しない:

- `my-laravel-app/compose.yaml`
- `my-laravel-app/docker/mysql/conf.d/.keep`
- `my-laravel-app/.tool-versions`
- `my-laravel-app/.gitignore`（`.env` 除外・カバレッジ除外など含む）
- `my-laravel-app/.npmrc`（npm のサプライチェーン対策 `ignore-scripts=true` / `audit=true`）
- ルート直下の `.tool-versions`, `env.example`, `.gitignore`

これらの内容を確認・編集する必要はない（中身は `docs/stack.md` の規約に合致した状態でコミット済み）。

## 実行手順

### 1. 事前確認

1. **PHP バージョン確認**: `my-laravel-app/` 内で `php -v` を実行し 8.4.23 系が出るか確認。出ない場合は asdf 等でインストールを促し中断。
2. **PHP 拡張の確認**: `php -m | grep -i zip` で `zip` 拡張が有効か確認する（`laravel/dusk` v8.x 系が `ext-zip` を要求するため）。無効な場合、`pecl install zip` でビルドし、`php --ini` で表示される `conf.d` 配下の ini ファイルに `extension=zip.so` を追記する（このホストの PHP 全体に適用される変更のため、事前にユーザーへ確認する）。`libzip` が未インストールの場合は `brew install libzip` を促す。
3. **Node.js バージョン確認**: `node -v` を実行し `.tool-versions` の `nodejs 22.14.0` 系と一致するか確認する。一致しない場合、`which node` で実際に使われているバージョンマネージャ（asdf/mise/nodenv/nvm 等）を特定する。**複数のバージョンマネージャが併存し、`.tool-versions`（asdf/mise 用）を無視して別のマネージャ（例: nodenv）が優先されるケースがある**ため、その場合は優先されているマネージャ側で該当バージョンをインストールし、プロジェクトディレクトリにローカルピン留め（例: `nodenv local 22.14.0`）する。バージョン不一致のまま進めると `npm run build` で Vite 系パッケージのネイティブバインディングが解決できず失敗することがある。
4. **Laravel Installer の確認**: `laravel --version` を実行。存在しない場合は `composer global require laravel/installer` を提案し、`~/.composer/vendor/bin`（または `~/.config/composer/vendor/bin`）に PATH が通っているか確認。
5. **Docker の確認**:
   - `docker version` で Docker Engine が利用可能か確認
     - `Cannot connect to the Docker daemon` 等のエラーが出た場合は「インストール済みだが Docker Desktop アプリが起動していない」ケース。ユーザーに Docker Desktop の起動を促し、起動後に再実行する
     - `command not found` の場合は「未インストール」のケース。「Docker Desktop か Docker Engine + Compose v2 をインストールしてください」と案内し中断
   - `docker compose version` で Compose v2 が利用可能か確認
6. **ポート 3306 の空き確認**:
   - `lsof -i :3306` または `nc -z 127.0.0.1 3306` で確認
   - 既に使用中ならユーザーに案内し、停止または別ポート利用を判断してもらう
7. **カバレッジ計測ドライバの確認（警告のみ・中断しない）**: `php -m | grep pcov` を実行する。出力が空の場合、「PCOV が未導入のため Phase 4 のカバレッジ 80% 判定が実行できない。Phase 1〜3 は影響を受けないので続行するが、Phase 4 に入る前に `docs/stack.md` の「テストカバレッジ設定（正規形）」の手順で導入が必要」と**報告してから続行する**。ここで中断しないのは、カバレッジが Phase 1 の完了基準に含まれず、Phase 1〜3 だけを試す利用者の足止めになるため。必須チェックは Phase 4 の Step 2-0 に置いてある（そこでは未導入なら中断する）。

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
- **Docker named volume の衝突**: Compose のプロジェクト名はディレクトリ名（basename）由来のため、`my-laravel-app` という同名ディレクトリが複数ある場合（git worktree・複数クローン）、同じボリューム `my-laravel-app_db-data` を共有してしまう。過去に別ディレクトリで初期化済みのデータが残っていると `MYSQL_DATABASE=bookkeeper` / `MYSQL_USER=app` の初期化がスキップされ、`app` ユーザーが `bookkeeper` にアクセスできない（`SHOW GRANTS FOR 'app'@'%';` で確認できる）。`docker compose down -v` で解消する。worktree で並行して試す場合は `COMPOSE_PROJECT_NAME` を worktree ごとに変える

### 3. Laravel アプリ生成

`my-laravel-app/` は既にテンプレート同梱ファイル（`CLAUDE.md`, `docs/`, `.claude/`, `compose.yaml`, `docker/`, `.gitignore`, `.npmrc` 等）で空でない。Laravel Installer はカレントディレクトリ指定（`laravel new .`）では空でないディレクトリへの生成を `Application already exists!` で拒否し、`--force` との併用も `Cannot use --force option when using current directory for installation!` で拒否する（Installer 5.30.0 で確認）。そのため、一時サブディレクトリに生成してから直下へ配置する:

```sh
laravel new tmp-skeleton --no-interaction --pest
```

`--pest` でテストフレームワークに Pest を選択する。スターターキット選択のプロンプトは `--no-interaction` によりスキップされ、認証機能なしの素の Laravel が生成される（認証は Step 6 で Breeze を個別に導入する）。`--no-interaction` かつ非 TTY で実行すると、進捗ログの代わりに `{"success":true,"name":"tmp-skeleton",...}` の JSON 1 行だけが出力される。これは正常。

生成完了後、`rsync` で全生成物（ドットファイル含む）を `my-laravel-app/` 直下へ配置し、一時ディレクトリを削除する:

```sh
rsync -a --exclude=/.gitignore --exclude=/.npmrc tmp-skeleton/ .
git clean -fdxq tmp-skeleton
ls -a .env .env.example artisan composer.json composer.lock phpunit.xml
```

最後の `ls` は配置が成功したことの確認。1 つでも「No such file」になる場合は先に進まず、原因を調べること。

> **注意（配置手段の選定理由）**: この配置を **`mv` と glob で書かないこと**。理由は 3 つある。
>
> - `mv tmp-skeleton/* .` はドットファイル（`.env`, `.env.example`, `.editorconfig`, `.gitattributes`）を含まず、`.env` を欠いたまま以降の `key:generate` / `migrate` が全滅する。しかもエラーは移動時点では出ず、フェーズ後半まで表面化しない
> - Claude Code の Bash ツールは**書き込み系コマンドの glob を拒否**する（`Glob patterns are not allowed in write operations.`）ため、そもそも `mv tmp-skeleton/* .` は実行できない
> - `find tmp-skeleton -mindepth 1 -maxdepth 1 -exec mv {} . \;` も、`-exec` がファイルを変更するため許可リストの `Bash(find:*)` では自動許可されず拒否される
>
> `rsync -a` は末尾スラッシュ付きのディレクトリ指定でドットファイルを含めて再帰コピーするため、シェルの glob 展開に依存せず zsh / bash のどちらで評価されても同じ結果になる。コピー後に残る `tmp-skeleton` は未追跡なので `git clean -fdxq` で除去する（追跡ファイルを巻き込む事故が起きない）。

`laravel new` は `.gitignore` / `.npmrc` を独自に生成するが、上記の `--exclude` により**テンプレート同梱版がそのまま残る**。テンプレート側を正とするため、除外は必ず指定すること（`--exclude=/.gitignore` の先頭 `/` は転送元ルート直下のみを対象にする指定で、`storage/framework/*/.gitignore` 等の下位ディレクトリの `.gitignore` は除外されない）。

> **補足**: `.npmrc` を `--exclude` するのは内容が同一（`ignore-scripts=true` / `audit=true`）だからだけでなく、Claude Code のセンシティブファイル保護により `.npmrc` への書き込みがヘッドレス実行で承認できないため。除外しておけば保護に抵触せず処理が止まらない。

配置後、テンプレート同梱ファイルが無傷であることを確認する:

```sh
git status --short -- .gitignore .npmrc .claude compose.yaml docker .tool-versions CLAUDE.md docs
```

何も出力されなければ正常。差分が出た場合は `git checkout -- <path>` で戻す。

### 4. config/database.php の調整

`docs/stack.md` の「MySQL 設定の規約」セクションに記載の正規形に合わせて `mysql` 接続設定を修正する。

**構造には手を入れない。`env()` の第 2 引数（既定値）を 4 か所書き換えるだけである**（`laravel new` の生成物は既に `charset` / `collation` も `env()` 経由になっている）:

| キー | `laravel new` の既定値 | 書き換え後 |
|---|---|---|
| `database` | `'laravel'` | `'bookkeeper'` |
| `username` | `'root'` | `'app'` |
| `password` | `''` | `'app_password'` |
| `collation` | `'utf8mb4_unicode_ci'` | `'utf8mb4_0900_ai_ci'` |

`charset` の既定値は `'utf8mb4'` で既に正しいため変更不要。`url` / `unix_socket` / `prefix_indexes` / `options` の各行は**生成されたまま残す**（削除しない）。

> **注意**: `'url' => env('DB_URL')` の行は残すが、`.env` に `DB_URL` の値は設定しない（Step 7 の注意参照）。行の存在と値の設定は別問題であり、行を消す必要はない。

### 5. Composer パッケージの追加

`docs/stack.md` の「手動追加」列が ✅ のパッケージを追加する:

```sh
composer require livewire/livewire spatie/laravel-query-builder blade-ui-kit/blade-heroicons
composer require --dev larastan/larastan laravel/dusk laravel-lang/lang
```

> **注意**: 当初 `enlightn/enlightn` を予定していたが、Laravel 13.x に対応するバージョンが存在しない（`laravel/framework ^9.0|^10.0|^11.0` までのサポート）ため `larastan/larastan`（PHPStan の Laravel 版）に変更した。詳細は `docs/stack.md` 参照。

> **補足**: `livewire/livewire` はこの時点では v4 系（`^4.3`）で解決される。Step 6 の `laravel/breeze`（Livewire スタック）導入時に Breeze の制約で v3 系（`^3.6.4`）に解決し直される（`breeze:install livewire` が composer 依存を書き換え、v3.8.2 系に落ちることを確認済み）。`docs/stack.md` の想定（Livewire v3）と一致するため問題ない。

> **補足（spatie/laravel-query-builder は v7 系で解決される）**: v7 の `allowedFilters()` / `allowedSorts()` は**可変長引数のみ**を受け取り、v6 までの配列渡しは `TypeError` になる。Phase 3 で使うときの書き方は `docs/architecture.md` の Model セクション参照。

### 6. 各種初期化

- **Laravel Breeze（Livewire スタック）**:
  ```sh
  composer require laravel/breeze --dev
  php artisan breeze:install livewire --no-interaction
  ```
  このコマンドで認証ビュー（ログイン・登録・パスワードリセット等）が Livewire コンポーネントとして生成され、Tailwind CSS と Alpine.js のセットアップも同時に行われる。`npm install` と `npm run build` も内部で実行される。非 TTY 環境では `WARN TTY mode requires /dev/tty to be read/writable.` が出るが処理は継続するので無視してよい。

  > **注意（Breeze 生成物は `dashboard` / `profile` ルートに依存する）**: `breeze:install` は `routes/web.php` に `dashboard` と `profile` の 2 ルートを追加し、生成したビュー・Controller・Feature テストがそれを参照する。一方 `docs/api-spec.md` の `routes/web.php` にはこの 2 つが無い。Phase 3 でルーティングを仕様通りに置き換える際、参照側の追従が必須になる（詳細は Phase 3 手順書と `docs/api-spec.md` の注記参照）。Phase 1 の時点では Breeze の生成物をそのまま残しておくこと。
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

  > **重要（`dusk:chrome-driver --detect` を必ず続けて実行する）**: ホストの Google Chrome が 1 世代古いと、`dusk:install` が入れた ChromeDriver とメジャーバージョンが噛み合わず、Phase 3 の `php artisan dusk` が全件
  > `session not created: This version of ChromeDriver only supports Chrome version NNN / Current browser version is MMM ...`
  > で失敗する。`--detect` はホストにインストールされた Chrome のバージョンを検出して対応する ChromeDriver を入れ直すため、Phase 1 の時点で実行しておく（Chrome を更新した場合も同じコマンドで追従する）。

  > **重要（`tests/Pest.php` を先に並べ替える）**: Dusk 8.6 の `dusk:install` は `tests/Pest.php` の**先頭**（`use` 文より前）に完全修飾名で次の行を挿入する:
  > ```php
  > pest()->extend(Tests\DuskTestCase::class)
  > //  ->use(Illuminate\Foundation\Testing\DatabaseMigrations::class)
  >     ->in('Browser');
  >
  > use Illuminate\Foundation\Testing\RefreshDatabase;
  > use Tests\TestCase;
  > ```
  > この状態で Step 9 の Pint を掛けると `fully_qualified_strict_types` / `ordered_imports` が短縮名 + `use` 文へ書き換え、`use Tests\DuskTestCase;` が `pest()->extend(DuskTestCase::class)` の**後ろ**に置かれる。Pest は `pest()->extend()` をブートストラップ段階で評価するため、`php artisan test` が `The class DuskTestCase was not found.` で失敗する。
  >
  > **`dusk:install` の直後に**、挿入されたブロックを `use` 文の**後ろ**へ移し、短縮名 + `use Tests\DuskTestCase;` の形に直しておくこと。こうしておけば Pint はこのファイルを一切書き換えず（トライアルで確認済み）、Step 9 での手戻りが発生しない:
  > ```php
  > use Illuminate\Foundation\Testing\RefreshDatabase;
  > use Tests\DuskTestCase;
  > use Tests\TestCase;
  >
  > // dusk:install はこの行をファイル冒頭（use 文より前）に挿入するが、Pint の
  > // fully_qualified_strict_types が短縮名 + use 文へ書き換えると、import が
  > // pest()->extend() より後ろに置かれ Pest のブートストラップが解決に失敗する。
  > // use 文より後ろへ移してあるのはそのため。
  > pest()->extend(DuskTestCase::class)
  > //  ->use(Illuminate\Foundation\Testing\DatabaseMigrations::class)
  >     ->in('Browser');
  > ```
  > （Pint 適用後に直す運用では、Pint を掛け直すたびに壊れる。並べ替えを先に済ませること。）
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

  Breeze（Livewire スタック）が生成する `app/Http/Controllers/Auth/VerifyEmailController.php` は、`$request->user()` が nullable な型を返す一方 `Illuminate\Auth\Events\Verified` のコンストラクタが non-null を期待するため、level 5 で 1 件のエラーが出る（Breeze 自身の生成コードであり本プロジェクトの実装ミスではない）。この既知の指摘は以下の手順でベースライン化し、以後のアプリケーションコードに対してはエラー 0 を維持する:
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
- **Laravel Pint**: `laravel new` で既定導入済み。確認のみ（`vendor/bin/pint --version`）。

### 7. .env の準備

`laravel new` が生成した `.env` / `.env.example` に、ルート同梱の `env.example` の内容（`DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `MAIL_FROM_ADDRESS`）をマージする。あわせて `DB_CONNECTION` を `sqlite` から `mysql` に変更する。`APP_KEY` は上書きしない（Laravel が生成した値をそのまま使う。未設定なら次のコマンドで生成する）:

また、`APP_LOCALE=en` / `APP_FAKER_LOCALE=en_US` を `APP_LOCALE=ja` / `APP_FAKER_LOCALE=ja_JP` に変更する（Step 6 の注意参照。`config/app.php` の変更だけでは反映されない）。

```sh
php artisan key:generate
```

`DB_DATABASE=bookkeeper` を追記する。`MAIL_MAILER` は Laravel 13 の `.env` では既定で `log` になっている（`docs/stack.md` の「メール確認」セクション参照）。既定から変わっている場合のみ `log` に設定する。

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

> **注意: `DB_URL`（接続文字列方式）を `.env` に追加しないこと**
>
> このプロジェクトの `config/database.php` は `DB_HOST` / `DB_USERNAME` / `DB_PASSWORD` / `DB_PORT` の個別変数で接続情報を受け取る設計になっている。
> Laravel 13 の既定 `mysql` 接続は `'url' => env('DB_URL')`（環境変数名は `DATABASE_URL` ではなく `DB_URL`）を持つが、URL 方式と個別変数方式を混在させると接続設定の優先順位が複雑になりデバッグが困難になる。
> プロジェクト全体で個別変数方式に統一するため、`DB_URL` は設定しないこと。

### 8. composer.json の dev / setup スクリプトの調整

開発サーバーの起動もセットアップも、`laravel new` 既定の `composer.json` のスクリプト（`composer run dev` / `composer run setup`）を使う。**自前のラッパースクリプト（`bin/dev`・`bin/setup` 等）は作らない**（`composer.json` 側との二重管理になるため。`docs/stack.md` の「開発サーバー起動（正規形）」「初回セットアップ（正規形）」参照）。既定の生成物を本プロジェクトの方針に合わせて編集する。

**`scripts.dev`**: `laravel new` の既定生成物には `php artisan queue:listen ...` を含む concurrently コマンドが入っているため、`docs/stack.md` の規約（Queue ワーカーを起動しない）に従い、この行を削除する（`pail` と `npm run dev` はそのまま残してよい）。`--names` と `-c`（色指定）からも `queue` に対応する要素を落とすこと（残すと名前と実プロセスの対応がずれる）。

**`scripts.setup`**: 既定の生成物は次の形になっている（Laravel Framework 13.20.0 で確認）。

```json
"setup": [
    "composer install",
    "@php -r \"file_exists('.env') || copy('.env.example', '.env');\"",
    "@php artisan key:generate",
    "@php artisan migrate --force",
    "npm install --ignore-scripts",
    "npm run build"
]
```

本プロジェクトは DB を Docker で動かし、かつ Seeder 込みで「最初から動く状態」にするため、次の 2 点を変更する:

1. **先頭に `docker compose up -d --wait db` を足す** — 後続の `migrate` は DB が healthy でないと失敗するため。`--wait` を使う理由は Step 2 と同じ（判定条件を `compose.yaml` の healthcheck に一本化する）
2. **`@php artisan migrate --force` を `@php artisan migrate --seed --force` にする** — `docs/seeds.md` のサンプルデータ投入まで含めて一発で完了させるため

変更後:

```json
"setup": [
    "docker compose up -d --wait db",
    "composer install",
    "@php -r \"file_exists('.env') || copy('.env.example', '.env');\"",
    "@php artisan key:generate",
    "@php artisan migrate --seed --force",
    "npm install --ignore-scripts",
    "npm run build"
]
```

`npm install --ignore-scripts` は既定のまま残す（`.npmrc` の `ignore-scripts=true` と方針が一致するため）。

### 9. DB の作成と起動確認

1. **データベースの作成**（`bookkeeper` は `compose.yaml` の `MYSQL_DATABASE` で自動作成済み。`bookkeeper_test` を手動作成する）:
   ```sh
   docker compose exec -T db mysql -uroot -proot_password -e \
     "CREATE DATABASE IF NOT EXISTS bookkeeper_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; GRANT ALL PRIVILEGES ON \`bookkeeper_test\`.* TO 'app'@'%'; FLUSH PRIVILEGES;"
   ```

   > **重要（phpunit.xml のテスト DB 設定）**: `laravel new`（Laravel 13.x）が生成する `phpunit.xml` は既定で `DB_CONNECTION=sqlite` / `DB_DATABASE=:memory:` を設定しており、**このままだとテストが MySQL の `bookkeeper_test` ではなく SQLite で走る**。本プロジェクトは MySQL 固有の DDL（`docs/db-schema.md` の `books` テーブルの `ALTER TABLE ... ADD CONSTRAINT ... CHECK`）を使うため、SQLite ではマイグレーションが構文エラーで失敗する（Phase 1 時点では該当マイグレーションが無いため表面化しないが、Phase 2 で必ず壊れる）。`docs/stack.md` の規約通りテストは `bookkeeper_test`（MySQL）で実行するため、`phpunit.xml` の該当 env を次のように書き換える:
   > ```xml
   > <env name="DB_CONNECTION" value="mysql"/>
   > <env name="DB_DATABASE" value="bookkeeper_test"/>
   > ```
   > （`DB_URL` の env が空文字で定義されている場合はそのままでよい。）
2. `php artisan migrate`
   - 失敗時の典型原因: コンテナ未起動 / `.env` の認証情報不一致 / Step 2 で触れた Docker named volume の衝突（`Access denied for user 'app'@'%' to database 'bookkeeper'` のようなエラーが出る場合はこれを疑う）
   - エラー時は勝手に MySQL のユーザー権限をいじらず、状況を報告して指示を仰ぐ
3. **Pint による自動修正**: `vendor/bin/pint` を実行する。`laravel new` / `breeze:install` / `lang:add` が生成するファイル（`bootstrap/providers.php`, `lang/ja/*.php` 等）はデフォルトで Pint の規約に違反しているため自動修正が入る。その後 `vendor/bin/pint --test` が 0 件になることを確認する。
   - Step 6 の指示どおり `tests/Pest.php` を先に並べ替えてあれば、Pint はこのファイルを書き換えない。書き換えられた場合は並べ替えが漏れているので Step 6 に戻ること
4. `php artisan test` が green であることを確認する。
5. **起動確認**: `composer run dev` をバックグラウンドで立ち上げ、`curl -sS --retry 15 --retry-all-errors --retry-delay 1 -o /dev/null -w "%{http_code}" http://localhost:8000` が 200 を返すことを確認する。`/login` `/register` も 200 になること。確認後サーバを停止する（`pkill -f "php artisan serve"`、`pkill -f "artisan pail"`、`pkill -f vite`。concurrently に `--kill-others` が付いている場合は最初の 1 つで残りも終了するが、3 つとも実行して確実に止める）。
   - `--retry` を付けるのは、`composer run dev` の起動直後は `php artisan serve` がまだ listen していないため。Bash ツールでは `sleep` を伴う待機ループが書けないので `curl` 側のリトライで吸収する
6. **`composer run setup` の一気通貫確認**: `composer run setup` を実行し、DB 起動 → `composer install` → `.env` 用意 → `key:generate` → `migrate --seed` → `npm install` → `npm run build` が最後まで通ることを確認する（Phase 1 時点では Seeder が空なので `Seeding database.` のみ出る）。
   - `.env` と `APP_KEY` は Step 7 で用意済みのため、`copy('.env.example', '.env')` は skip され `key:generate` は既存のキーを上書きする。**この確認の前に `.env` の内容（DB 接続情報）が `.env.example` と一致していることを確かめる**。一致していないと、既存の `.env` が残る挙動に助けられて「新規クローンでは通らない設定」を見逃す
7. **git status の確認**: `git status --short` に、`.gitignore` で除外されるべき生成物（`public/hot`, `storage/pail`, `.phpunit.result.cache` 等）が現れていないことを確認する。現れた場合はテンプレートの `.gitignore` 側を補うこと。

## このフェーズの完了基準

- [ ] `docker compose up -d --wait db` で DB が healthy になる
- [ ] `composer run setup` で DB 起動 → セットアップ完了まで一気通貫で動く
- [ ] `composer.json` の `scripts.setup` に `docker compose up -d --wait db` と `migrate --seed --force` が反映済み
- [ ] `composer run dev` で http://localhost:8000 が 200
- [ ] `php artisan migrate` が成功（`bookkeeper` データベースに対して）
- [ ] `bookkeeper_test` データベースが作成済み
- [ ] `phpunit.xml` の `DB_CONNECTION` が `mysql`・`DB_DATABASE` が `bookkeeper_test`（既定の sqlite / :memory: から変更済み）
- [ ] `composer.lock` がコミット対象に入っている
- [ ] `composer.json` に `docs/stack.md` の「手動追加 ✅」パッケージがすべて記載
- [ ] Laravel Breeze（Livewire スタック）/ laravel-lang / larastan / Dusk の初期化済み
- [ ] `php artisan dusk:chrome-driver --detect` を実行済み（ホストの Chrome とバージョンが一致）
- [ ] `my-laravel-app/.env` が存在し、`.gitignore` で除外されている
- [ ] `my-laravel-app/.env.example` が存在し、コミット対象に含まれている。`.env` の設定（`DB_*` / `APP_LOCALE` / `APP_FAKER_LOCALE` / `MAIL_FROM_ADDRESS`）が同期されている
- [ ] `composer.json` の `dev` スクリプトに Queue ワーカー（`php artisan queue:work` / `queue:listen`）が**含まれていない**
- [ ] `php artisan test` が green
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse --memory-limit=512M` がエラー 0
- [ ] `git status --short` に `.gitignore` 漏れの生成物が出ていない

## やらないこと

- モデル生成（Phase 2 で実施）
- Controller / View 生成（Phase 3 で実施）
- Seeder（Phase 4 で実施）
- Laravel 本体のコンテナ化（プロジェクト方針として行わない）
- Queue ワーカーの起動設定（本プロジェクトでは非同期ジョブを使わない）
- Redis / Reverb の追加
- 同梱ファイル（`compose.yaml`, `.tool-versions`, `env.example`, `.npmrc`）の編集

## 完了後

`/verify` を実行し、結果を報告。
