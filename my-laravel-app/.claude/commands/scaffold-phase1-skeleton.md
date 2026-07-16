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

### 2. DB コンテナの起動

`my-laravel-app/` ディレクトリで以下を実行:

1. `docker compose up -d db` で DB コンテナを起動
2. DB が ready になるまで待機:
   ```sh
   for i in $(seq 1 30); do
     if docker compose exec -T db mysqladmin ping -uroot -proot_password > /dev/null 2>&1; then
       echo "MySQL is ready"
       break
     fi
     sleep 1
   done
   ```
3. `docker compose exec db mysql -uapp -papp_password bookkeeper -e "SELECT 1"` で `app` ユーザが `bookkeeper` データベースに実際にアクセスできることを確認する（データベース名を指定せずに `SELECT 1` するだけではログイン可否しか確認できず、後述のボリューム衝突による権限不足を見逃す）

起動失敗時の典型原因:
- ポート競合（`docker compose logs db` で確認）
- ボリュームに前回データが残っていてユーザ作成がスキップされた（`docker compose down -v` で初期化）
- **Docker named volume の衝突**: Docker Compose のデフォルトプロジェクト名はディレクトリ名（basename）に由来するため、`my-laravel-app` という同名ディレクトリが複数存在する場合（例: 元のチェックアウトと git worktree、あるいは複数クローン）、`my-laravel-app_db-data` という同じボリューム名を共有してしまう。過去に別の `my-laravel-app` で初期化済みのデータが残っていると、今回の `MYSQL_DATABASE=bookkeeper` / `MYSQL_USER=app` の初期化がスキップされ、`app` ユーザーが `bookkeeper` にアクセスできない（`SHOW GRANTS FOR 'app'@'%';` で対象データベースを確認できる）。この場合も `docker compose down -v` で解消するが、worktree で並行して試す場合は根本対策として `COMPOSE_PROJECT_NAME` を worktree ごとに変える運用も検討する

### 3. Laravel アプリ生成

`my-laravel-app/` は既にテンプレート同梱ファイル（`CLAUDE.md`, `docs/`, `.claude/`, `compose.yaml`, `docker/`, `.gitignore` 等）で空でないため、`laravel new` を直接カレントディレクトリに実行する:

```sh
laravel new . --force --no-interaction --pest
```

`--force` により既存ディレクトリでも生成を強行する。`--pest` でテストフレームワークに Pest を選択する。スターターキット選択のプロンプトは `--no-interaction` によりスキップされ、認証機能なしの素の Laravel が生成される（認証は Step 6 で Breeze を個別に導入する）。

`laravel new` は `.gitignore` を独自に生成するが、テンプレート同梱の内容を正とするため、生成直後に以下を実行してテンプレート側のファイルへ戻す:

```sh
git checkout -- .gitignore CLAUDE.md docs/ .claude/ compose.yaml docker/ .tool-versions 2>/dev/null || true
```

（テンプレートリポジトリがまだ git 管理下にない場合、上記コマンドは何もせず終了して構わない。その場合は `docs/`, `.claude/`, `compose.yaml`, `docker/`, `CLAUDE.md`, `.tool-versions`, `.gitignore` が `laravel new` によって上書き・混入していないか目視で確認する。）

### 4. config/database.php の調整

`docs/stack.md` の「MySQL 設定の規約」セクションに記載のサンプル通りに `mysql` 接続設定を修正する。要点:

- `charset: utf8mb4` / `collation: utf8mb4_0900_ai_ci` を明示
- `host` / `username` / `password` / `port` を `.env` 経由で読み込む（Laravel の既定のまま）

### 5. Composer パッケージの追加

`docs/stack.md` の「手動追加」列が ✅ のパッケージを追加する:

```sh
composer require livewire/livewire spatie/laravel-query-builder blade-ui-kit/blade-heroicons
composer require --dev larastan/larastan laravel/dusk laravel-lang/lang
```

> **注意**: 当初 `enlightn/enlightn` を予定していたが、Laravel 13.x に対応するバージョンが存在しない（`laravel/framework ^9.0|^10.0|^11.0` までのサポート）ため `larastan/larastan`（PHPStan の Laravel 版）に変更した。詳細は `docs/stack.md` 参照。

### 6. 各種初期化

- **Laravel Breeze（Livewire スタック）**:
  ```sh
  composer require laravel/breeze --dev
  php artisan breeze:install livewire
  ```
  このコマンドで認証ビュー（ログイン・登録・パスワードリセット等）が Livewire コンポーネントとして生成され、Tailwind CSS と Alpine.js のセットアップも同時に行われる。
- **laravel-lang（日本語化）**:
  ```sh
  php artisan lang:add ja
  ```
  `config/app.php` の `'locale'` を `'ja'` に、`'faker_locale'` を `'ja_JP'` に変更する。**`laravel new` が生成する `.env` / `.env.example` には `APP_LOCALE=en` / `APP_FAKER_LOCALE=en_US` が明示的に設定されており、`.env` の値が `config/app.php` のデフォルト値より優先されるため、`config/app.php` だけを変更しても反映されない。** Step 7 で `.env` / `.env.example` の `APP_LOCALE` を `ja`、`APP_FAKER_LOCALE` を `ja_JP` に変更すること。
- **Laravel Dusk**:
  ```sh
  php artisan dusk:install
  ```
  ChromeDriver のインストールも自動で行われる。

  > **注意**: `dusk:install` が `tests/Pest.php` の先頭に挿入するコードは、`use Tests\DuskTestCase;` 等の `use` 文より前に `DuskTestCase::class` を参照する順序になっており、そのままでは `php artisan test` が `The class "DuskTestCase" was not found.` で失敗する（Dusk 自体の既知の生成バグ）。`tests/Pest.php` を開き、`use` 文をファイル冒頭（`pest()->extend(DuskTestCase::class)...` より前）に移動すること。
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
- **Laravel Pint**: `laravel new` で既定導入済み。確認のみ（`vendor/bin/pint --version`）。

### 7. .env の準備

`laravel new` が生成した `.env` / `.env.example` に、ルート同梱の `env.example` の内容（`DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DEFAULT_FROM_EMAIL`）をマージする。あわせて `DB_CONNECTION` を `sqlite` から `mysql` に変更する。`APP_KEY` は上書きしない（Laravel が生成した値をそのまま使う。未設定なら次のコマンドで生成する）:

また、`APP_LOCALE=en` / `APP_FAKER_LOCALE=en_US` を `APP_LOCALE=ja` / `APP_FAKER_LOCALE=ja_JP` に変更する（Step 6 の注意参照。`config/app.php` の変更だけでは反映されない）。

```sh
php artisan key:generate
```

`DB_DATABASE=bookkeeper` を追記する。`MAIL_MAILER=log` を設定する（`docs/stack.md` の「メール確認」セクション参照）。

`.env` はテンプレート同梱の `.gitignore` で除外済み。`.env.example` は git 管理対象に含める（`APP_KEY=` は空のままにしておく）。

> **注意: `DATABASE_URL` を `.env` に追加しないこと**
>
> このプロジェクトの `config/database.php` は `DB_HOST` / `DB_USERNAME` / `DB_PASSWORD` / `DB_PORT` の個別変数で接続情報を受け取る設計になっている。
> `DATABASE_URL` 方式と個別変数方式を混在させると接続設定の優先順位が複雑になりデバッグが困難になる。
> プロジェクト全体で個別変数方式に統一するため、`DATABASE_URL` は設定しないこと。

### 8. bin/setup と bin/dev の作成

Laravel には Rails の `bin/setup` / `bin/dev` に相当する標準スクリプトが無いため、新規作成する。

先に `composer.json` の `scripts.dev` を確認する。`laravel new` の既定生成物には `php artisan queue:listen ...` を含む concurrently コマンドが入っているため、`docs/stack.md` の規約（Queue ワーカーを起動しない）に従い、この行を削除する（`pail` と `npm run dev` はそのまま残してよい）。

`bin/setup`（実行権限を付与すること）:

```sh
#!/usr/bin/env bash
set -euo pipefail

docker compose up -d db

for i in $(seq 1 30); do
  if docker compose exec -T db mysqladmin ping -uroot -proot_password > /dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "Database did not become ready in 30 seconds" >&2
    exit 1
  fi
  sleep 1
done

composer install
npm install
php artisan migrate --seed
```

`bin/dev` は `docs/stack.md` の「bin/dev（正規形）」セクションの内容をそのまま使う。

両ファイルに `chmod +x` で実行権限を付与する。

### 9. DB の作成と起動確認

1. **データベースの作成**（`bookkeeper` は `compose.yaml` の `MYSQL_DATABASE` で自動作成済み。`bookkeeper_test` を手動作成する）:
   ```sh
   docker compose exec -T db mysql -uroot -proot_password -e \
     "CREATE DATABASE IF NOT EXISTS bookkeeper_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; GRANT ALL PRIVILEGES ON \`bookkeeper_test\`.* TO 'app'@'%'; FLUSH PRIVILEGES;"
   ```
2. `php artisan migrate`
   - 失敗時の典型原因: コンテナ未起動 / `.env` の認証情報不一致 / Step 2 で触れた Docker named volume の衝突（`Access denied for user 'app'@'%' to database 'bookkeeper'` のようなエラーが出る場合はこれを疑う）
   - エラー時は勝手に MySQL のユーザー権限をいじらず、状況を報告して指示を仰ぐ
3. **起動確認**: `bin/dev` をバックグラウンドで立ち上げ、`curl -sS -o /dev/null -w "%{http_code}" http://localhost:8000` が 200 を返すことを確認後、サーバを停止（`kill %1` または `pkill -f "php artisan serve"`）。
4. **Pint による自動修正**: `vendor/bin/pint --test` を実行する。`laravel new` / `breeze:install` / `lang:add` が生成するファイル（`bootstrap/providers.php`, `tests/Pest.php`, `lang/ja/*.php` 等）はデフォルトで Pint の規約に違反していることがあるため、`vendor/bin/pint` で自動修正し、再度 `--test` で 0 件になることを確認する。

## このフェーズの完了基準

- [ ] `docker compose up -d db` で DB が起動し、`mysqladmin ping` が成功する
- [ ] `bin/setup` で DB 起動 → セットアップ完了まで一気通貫で動く
- [ ] `bin/dev` で http://localhost:8000 が 200
- [ ] `php artisan migrate` が成功（`bookkeeper` データベースに対して）
- [ ] `bookkeeper_test` データベースが作成済み
- [ ] `composer.lock` がコミット対象に入っている
- [ ] Laravel Breeze（Livewire スタック）/ larastan / Dusk の初期化済み
- [ ] `my-laravel-app/.env` が存在し、`.gitignore` で除外されている
- [ ] `my-laravel-app/.env.example` が存在し、コミット対象に含まれている
- [ ] `bin/dev` に Queue ワーカー（`php artisan queue:work` / `queue:listen`）の行が**含まれていない**
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse --memory-limit=512M` がエラー 0

## やらないこと

- モデル生成（Phase 2 で実施）
- Controller / View 生成（Phase 3 で実施）
- Seeder（Phase 4 で実施）
- Laravel 本体のコンテナ化（プロジェクト方針として行わない）
- Queue ワーカーの起動設定（本プロジェクトでは非同期ジョブを使わない）
- Redis / Reverb の追加
- 同梱ファイル（`compose.yaml`, `.tool-versions`, `env.example`）の編集

## 完了後

`/verify` を実行してセルフチェックし、結果を「やったこと / 次にやること / 詰まっていること」の 3 点で報告する。
