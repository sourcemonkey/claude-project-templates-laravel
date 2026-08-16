---
description: フェーズ2 - DB スキーマからモデル・マイグレーションを生成する
---

# Phase 2: モデルとマイグレーション

`docs/db-schema.md` の定義に厳密に従ってマイグレーションとモデルを作成する。テーブル定義・カラム制約・インデックス・enum 値・リレーションはすべて `docs/db-schema.md` が一次情報。

> **実行場所**: 本手順書のコマンドは、断りが無い限りすべて **`my-laravel-app/` をカレント**として
> 書かれている。Bash ツールのカレントは呼び出しをまたいで持続するので、**最初に一度だけ**
> `cd my-laravel-app` し、以降は移動しない（ルートにも別物の `bin/` があり、そこから
> `bin/check-repo.sh` を打つと `exit 127` になる）。

> **前提**: Phase 1 が完走し、`phpunit.xml` のテスト DB が MySQL の `bookkeeper_test` に設定済みであること（Phase 1 手順書の Step 9 参照）。既定の `sqlite` / `:memory:` のままだと、本フェーズで追加する `books` の `ALTER TABLE ... ADD CONSTRAINT ... CHECK` が SQLite の構文エラーで失敗し、モデルテストが全滅する。

## 実行順序

`@docs/db-schema.md` の ER 図・リレーション定義を読み、FK の参照先テーブルを先に作る順序で作成すること。Breeze が生成する `users` テーブルは他テーブルの FK が `users.id` を参照するため、FK 依存の有無にかかわらず必ず最初に対応する。

本フェーズ全体の作業順序は次のとおり。**Pint はモデルテストを書いた後に実行する**（先に実行すると `tests/Unit/Models` がまだ存在せず `The path "tests/Unit/Models" is not readable.` で失敗する）:

1. `users` テーブルの補正（マイグレーション + Enum + Model + **`UserFactory`**）
2. 残りのモデル・マイグレーション・ファクトリの作成
3. `php artisan migrate`
4. モデルテストの作成
5. `vendor/bin/pint`
6. `php artisan test` / `vendor/bin/phpstan analyse`

## 手順

### users テーブルの補正

Phase 1 で Breeze がインストール済みのため `users` テーブルのマイグレーション自体は存在する。以下を追加するマイグレーションを新規作成する:

```sh
php artisan make:migration add_role_to_users_table --table=users
```

`docs/db-schema.md` の `users` テーブル定義に合わせて `role`（`tinyInteger`, `NOT NULL`, `default: 0`）カラムを追加する。`down()` では `$table->dropColumn('role')` で戻せるようにする（`team-rules/coding-standards.md` の「マイグレーションは可逆にする」）。

次に `App\Models\User` を補正する。

> **注意1（`role` を Mass assignment 対象にしない）**: `team-rules/security.md` に従い
> **`role` は fillable に追加しない**。Model Factory は fillable を経由しないため
> `User::factory()->admin()` は問題なく機能する（ロール変更の実装は Phase 3 の担当で、
> 一次情報は `docs/api-spec.md`）。

> **注意2（Laravel 13 の User モデルは属性ベース）**: `laravel/laravel` が生成する `User` モデルは、`protected $fillable` / `protected $hidden` プロパティではなく PHP 属性 `#[Fillable([...])]` / `#[Hidden([...])]` を使う。上記の通り `role` は fillable に足さないので、`#[Fillable(['name', 'email', 'password'])]` はそのままでよい。

`casts()` に `'role' => UserRole::class` を追加する（`UserRole` Enum は次のステップで作成）。`app/Enums/UserRole.php`:

```php
enum UserRole: int
{
    case Member = 0;
    case Admin = 1;
}
```

`User` モデルに `isAdmin(): bool` メソッドを追加し、`role === UserRole::Admin` を返す。

> **注意3（larastan 用の `@property` 注釈）**: enum キャストしたカラムは `@property` PHPDoc が無いと larastan が `int` 扱いにし、`role === UserRole::Admin` を「常に false」と誤判定して `vendor/bin/phpstan analyse` がエラーになる。モデルの docblock に `@property` を付けること:
> ```php
> /**
>  * @property UserRole $role
>  */
> class User extends Authenticatable
> ```
> 同様に enum キャストを持つ他モデル（`Lending::$state`, `Notification::$kind`）にも `@property` を付ける。
>
> **date / datetime キャストも同じ理由で `@property` が要る**（`Cannot call method
> toDateString() on string.` になる）。`Lending` には次を付けておくこと:
> ```php
> /**
>  * @property LendingState $state
>  * @property Carbon $requested_at
>  * @property Carbon|null $approved_at
>  * @property Carbon|null $due_on
>  * @property Carbon|null $returned_at
>  */
> ```

> **注意4（`Notifiable` トレイトとの衝突）**: **`User` に `notifications()` を定義しないこと。** Breeze が付与する `Notifiable` トレイトの `notifications()`（`MorphMany`）を `HasMany` で上書きすることになり、larastan が非共変な戻り値型としてエラーにする。独自 `Notification` へのアクセスは `Notification` 側の `belongsTo(User::class)` で表現する。**`User` に必要なリレーションは `lendings()` のみ。**

### 残りのモデル

各モデルを `php artisan make:model Xxx -mf`（マイグレーション + ファクトリ同時生成）で雛形作成し、`docs/db-schema.md` の定義（NOT NULL、UNIQUE、CHECK 制約、インデックス、enum 値）に合わせて手動で補正する。

対象: `Category`, `Book`, `Tag`, `Lending`, `Notification`, `AuditLog`

`book_tags` は中間テーブルのため専用モデルは作らず、マイグレーションのみ `php artisan make:migration create_book_tags_table --create=book_tags` で作成する（`Book` / `Tag` モデルの `belongsToMany` のピボットテーブルとして扱う）。

**生成の順序を FK 依存に合わせること**（`make:model` はタイムスタンプ順でマイグレーションを並べるため、生成順がそのまま実行順になる）: `Category` → `Tag` → `Book` → `book_tags` → `Lending` → `Notification` → `AuditLog`。

**`&&` で連結し、次の 2 呼び出しにまとめる。** 連結は 1 つのシェルが左から順に実行するので、
生成順＝タイムスタンプ順が保たれる。

```sh
php artisan make:model Category -mf && php artisan make:model Tag -mf && php artisan make:model Book -mf && php artisan make:migration create_book_tags_table --create=book_tags
```

```sh
php artisan make:model Lending -mf && php artisan make:model Notification -mf && php artisan make:model AuditLog -mf
```

> **ツールの並列呼び出しでまとめてはいけない**（実行順が保証されず FK 依存が壊れる）。
> 2 つに分けてあるのは、連結が長いとツール側の別のガードに当たりやすいため。

> `App\Models\Notification` は Laravel 標準の `Notification` ファサードと名前が衝突するので、Controller / Action での `use` 文に注意する（完全修飾名かエイリアスで区別する）。

各モデルの `$fillable`（`User` 以外は従来どおり `protected $fillable` プロパティで可）・`casts()`・リレーションを定義する。enum キャスト（`Lending::$state` → `LendingState`, `Notification::$kind` → `NotificationKind`）を持つモデルには前述の `@property` 注釈を付ける。

Enum クラスは `app/Enums/` に置く。値は `docs/db-schema.md` の各テーブル定義に明示されているものを使い、**推測で採番しない**（`UserRole` / `LendingState` / `NotificationKind` の 3 つ）。

> **注意（`audit_logs` は `updated_at` を持たない）**: 不変レコードのため `AuditLog` モデルに
> `public $timestamps = false;` を設定する（設定しないと Eloquent が保存時に `updated_at` を
> 書こうとして「Unknown column 'updated_at'」で失敗する）。`created_at` はマイグレーションの
> `useCurrent()` により DB 側で設定される。この設定に伴い、次の 3 点が要る:
>
> - `changes_json` を `'changes_json' => 'array'` でキャストする。**再取得した値を `toBe()` で
>   比較しない**（MySQL の JSON 型はキーの挿入順を保持せず、厳密比較が
>   `Failed asserting that two arrays are identical.` で落ちる）。`toMatchArray()` を使う
> - **`created_at` も `'created_at' => 'datetime'` でキャストする。** `$timestamps = false` の
>   モデルは自動キャストが効かず、Phase 3 の監査ログ画面が
>   `Call to a member function format() on string` で **500** になる。larastan 用に
>   `@property \Illuminate\Support\Carbon|null $created_at` も付ける
> - **`created_at` は生成直後のインスタンスに載らない**（`useCurrent()` は DB 側の既定値なので
>   Eloquent が再取得しない）。`AuditLog::factory()->create()->created_at` は `null` を返すため、
>   値を読むときは `->fresh()` を挟む

ジェネレータの自動生成だけでは制約が足りないので、以下を必ず確認:

- すべての FK は `$table->foreignId('xxx_id')->constrained()`
- 必須カラムは `->nullable()` を付けない
- ユニーク制約は `->unique()`、CHECK 制約はマイグレーション内で `DB::statement()` により明示
- インデックスは `docs/db-schema.md` の通り
- 削除時の挙動（`restrictOnDelete` / `cascadeOnDelete` / `nullOnDelete`）は `docs/db-schema.md` の「削除時の挙動」表の通り
- `audit_logs` は `$table->timestamps()` ではなく `$table->timestamp('created_at')->useCurrent();` を使う

### CHECK 制約の書き方

`books` テーブルの `available_copies` には MySQL の CHECK 制約を 2 つ付ける。マイグレーション内での書き方:

```php
public function up(): void
{
    Schema::create('books', function (Blueprint $table) {
        // ... カラム定義 ...
    });

    DB::statement('ALTER TABLE books ADD CONSTRAINT books_available_copies_non_negative CHECK (available_copies >= 0)');
    DB::statement('ALTER TABLE books ADD CONSTRAINT books_available_lte_total CHECK (available_copies <= total_copies)');
}

public function down(): void
{
    DB::statement('ALTER TABLE books DROP CHECK books_available_copies_non_negative');
    DB::statement('ALTER TABLE books DROP CHECK books_available_lte_total');

    Schema::dropIfExists('books');
}
```

> `use Illuminate\Support\Facades\DB;` が要る。`ALTER TABLE ... ADD CONSTRAINT` は MySQL 固有の構文なので、テストは必ず `bookkeeper_test`（MySQL）で実行すること。

### Lending の state 遷移

許容される遷移は `@docs/db-schema.md` の「state 遷移ルール」参照。

`state` は PHP Enum（`app/Enums/LendingState.php`）で表現する:

```php
enum LendingState: int
{
    case Requested = 0;
    case Approved = 1;
    case Returned = 2;
    case Rejected = 3;
    case Overdue = 4;
}
```

状態遷移用の外部パッケージは使わず、`Lending` モデルのメソッド（`approve()`, `reject()`, `returnBook()`）として実装する（`return` は PHP 予約語のためメソッド名に使えない）。各メソッド内で遷移元の state を確認し、不正な場合は `throw new \DomainException(...)` する。在庫減算・通知・**`due_on` の設定**は Action（Phase 3）側で行い、モデルのメソッドは state 遷移（と対応する `approved_at` / `returned_at` の設定）に限定する。**`due_on`（14 日後）を `approve()` に含めないこと。** 責務の一次情報は `docs/architecture.md` の Action 一覧。

**`markOverdue()` のようなメソッドは作成しない。** `Overdue` への遷移はバッチ相当の操作で、本フェーズでは Seeder が state を直接設定する。

### リレーション

テーブル定義と ER 図から方向を導出し、各モデルに `hasMany` / `belongsTo` / `belongsToMany` を記述する。削除時の挙動はマイグレーションの外部キー定義で `@docs/db-schema.md` の「削除時の挙動」セクション通りに設定する。`User` の `notifications()` は定義しない（前述の注意4）。

`belongsToMany` は中間テーブル名を明示し（`belongsToMany(Tag::class, 'book_tags')`）、**`withTimestamps()` を付ける**（付けないと attach 時に NOT NULL 違反になる）。

### Spatie Query Builder 対応

Model 側での特別な設定は不要。許可するフィルタ・ソートは Phase 3 で Controller 側に定義する（`docs/db-schema.md` の「Spatie Query Builder 対応」セクション参照）。

### マイグレーション実行

```sh
php artisan migrate
```

エラーが出たら止めて報告。勝手に `migrate:fresh` しない。

実行後、可逆性を確認する（`team-rules/coding-standards.md` の要求）。**`&&` で連結して 1 呼び出しにする**（`;` だと `rollback` が落ちても `migrate` の終了コードしか返らず、失敗を取りこぼす）:

```sh
php artisan migrate:rollback && php artisan migrate
```

### ファクトリ

`make:model -f` が生成するファクトリは中身が空（`return [];`）なので、`docs/db-schema.md` の定義に合わせて書くこと（ファイルが既に存在するため Read してから編集する）。

> **`UserFactory` は既に生成済みで中身も空**ではないため、上の「残りのファクトリ」に
> 含まれない。**実行順序 1（users テーブルの補正）の一部として、`User` を触る時点で
> 下の `User` の項まで読み、モデルと同時に直すこと**（後回しにすると `role` が `null` の
> ままモデルテストが落ちる）。

- `User` ファクトリのメールは `@test.local` ドメインにする（Breeze 標準ファクトリの既定ドメインとテスト実行時に衝突しないようにするため）。`role` を扱う `admin()` state も追加する

  ```php
  'email' => fake()->unique()->userName().'@test.local',
  ```

  > **`fake()->safeEmail('test.local')` と書かないこと。** Faker の `safeEmail()` は
  > **引数を取らず**、常に `example.com` / `.net` / `.org` を返す。
  - **`definition()` にも `'role' => UserRole::Member` を明示すること**。マイグレーションの `default(0)` に任せると `User::factory()->create()` が返すインスタンスに `role` が載らず、モデルテストの「enum キャストの確認」が `Failed asserting that null is identical to an object of class "App\Enums\UserRole".` で落ちる
- **`Book` ファクトリの既定は「在庫満杯」（`available_copies` = `total_copies`）にすること**。`fake()->numberBetween()` を 2 つ独立に呼ぶと CHECK 制約違反になり、0 を許すと `Lending::factory()` 経由の承認が在庫チェックに弾かれて**確率的に落ちるテスト**になる。**ファクトリの既定は「素直に使って通る値」とし、異常系は `outOfStock()` state（`available_copies = 0`）でテスト側から明示する**
  - **`available_copies` はローカル変数ではなくクロージャで `$attributes['total_copies']` から導出すること。**

    ```php
    return [
        // ...
        'total_copies' => fake()->numberBetween(1, 5),
        'available_copies' => fn (array $attributes) => $attributes['total_copies'],
    ];
    ```

    ローカル変数で書くと `Book::factory()->create(['total_copies' => 2])` のように
    **呼び出し側が片方だけを上書きしたときに** `Check constraint 'books_available_lte_total'
    is violated.` で落ちる。**Phase 2 のモデルテストでは気付けず、Phase 4 の Dusk で初めて
    顕在化する**ので、ここでクロージャにしておくこと。
  - **`isbn` は `fake()->unique()->isbn13()` とする。`optional()` と繋がないこと**
    （`optional()` は**後続の呼び出しを確率で `null` に差し替える**ため、
    `optional()->unique()->isbn13()` は `null` に対するメソッド呼び出しになって落ちる）。
    null の ISBN は `docs/seeds.md` の「未公開書籍サンプル」を Seeder が作るので、
    ファクトリ側で混ぜる必要はない。
- `Lending` ファクトリには state ごとの state メソッド（`approved()`, `overdue()`, `returned()`, `rejected()`）を用意しておくと、モデルテストと Phase 4・5 の Feature / Dusk テストの両方で使える
  - **Seeder では使わない**（`approved()` の `due_on` は 14 日後で、**seeds.md の Approved サンプル（7 日後）と一致しない**ため、使うと仕様と食い違うデータが入る）

### モデルテスト

> **注意（Pest の Unit ディレクトリ設定）**: `tests/Unit/` は既定では素の PHPUnit `TestCase` にバインドされており、Laravel アプリが起動しない（DB も使えない）。DB を伴うモデルテストを `tests/Unit/Models/` に置くため、`tests/Pest.php` に次のバインドを追加すること:
> ```php
> pest()->extend(TestCase::class)
>     ->use(RefreshDatabase::class)
>     ->in('Unit/Models');
> ```
> これが無いと `A facade root has not been set.` 等で失敗する。`TestCase` / `RefreshDatabase` は `tests/Pest.php` の冒頭で import 済みなので、**完全修飾名では書かないこと**（Pint が短縮して差分が出る）。

`tests/Unit/Models/` に各モデルの最低限のバリデーションテストを Pest で書く（`test/models` 相当のディレクトリ構成）。網羅すべき観点:

- presence（必須カラムのバリデーション、または DB の NOT NULL 制約）
  - **`Model::create($model::factory()->raw([...]))` と書かないこと**（`raw()` は非 fillable の列も
    返すため、DB へ到達する前に `MassAssignmentException` になる）。
    `Model::factory()->create(['col' => null])` を使う
- uniqueness
- enum（PHP Enum）キャストの確認
- リレーションの存在
- `books` の CHECK 制約（`available_copies` の範囲違反で `QueryException`）
- 削除時の挙動（`restrictOnDelete` で `QueryException`、`cascadeOnDelete` で連動削除されること）
- `role` が Mass assignment されないこと。`User::create()` に `role` を渡すと
  `MassAssignmentException` が投げられることを assert する:

  ```php
  expect(fn () => User::create([
      'name' => 'テストユーザー',
      'email' => 'guarded@test.local',
      'password' => 'password',
      'role' => UserRole::Admin,
  ]))->toThrow(Illuminate\Database\Eloquent\MassAssignmentException::class);
  ```
- **`Lending` の遷移メソッド**（`approve()` / `reject()` / `returnBook()`）の正常系と、不正な遷移元で `DomainException` が送出されること（Phase 3 の Action がこれらに直接依存する）

**各観点につき、該当するモデルごとに 1 件書く**（観点が当てはまらないモデルは飛ばす）。
遷移メソッドのように対象が複数あるものは、メソッドごとに正常系 1 件 + 異常系 1 件。
**これで全体 35 件前後になる。大きく超える場合は同じ観点を重複して書いている**ので見直すこと
（網羅性はカバレッジ判定で確かめる。それは Phase 5 の担当）。

```sh
php artisan test tests/Unit/Models
```

で all green を確認。

### Pint 自動修正

モデルテストを書き終えてから実行する。自動修正と検査は `&&` で連結して 1 呼び出しにする
（修正が先、検査が後という順序に意味があるので `;` ではなく `&&`）:

```sh
vendor/bin/pint && vendor/bin/pint --test
```

`--test` 側が違反 0 になること。

## このフェーズの完了基準

まず `bin/check-repo.sh`（読み取りのみ）を実行し、終了コード 0 を確認してから以下を確認する。

コマンドで確かめる 3 項目は `&&` でつないで 1 呼び出しにする。

```sh
php artisan test && vendor/bin/pint --test && vendor/bin/phpstan analyse --memory-limit=512M
```

- [ ] `php artisan migrate:status` で全マイグレーションが `Ran`
- [ ] `php artisan migrate:rollback` → `php artisan migrate` が両方成功する（可逆性）
- [ ] `php artisan test tests/Unit/Models` が all green
- [ ] `php artisan test` 全体が all green（Phase 1 の Breeze 認証テストを壊していない）
- [ ] マイグレーション定義（`database/migrations/`）が `docs/db-schema.md` の定義と一致
- [ ] 各モデルのリレーション・enum キャストが定義済み
- [ ] enum キャストを持つモデルに `@property` 注釈があり、`vendor/bin/phpstan analyse --memory-limit=512M` がエラー 0
- [ ] `role` が `User` の Mass assignment 対象（fillable）に**含まれていない**
- [ ] `BookFactory` の `available_copies` がクロージャで `$attributes['total_copies']` から導出されている（`Book::factory()->create(['total_copies' => 2])` が CHECK 制約に違反しない）
- [ ] `books` テーブルに CHECK 制約が 2 つ存在する。次で確認する（2 行出れば OK）:

  ```sh
  docker compose exec -T db mysql -uapp -papp_password bookkeeper -e "SHOW CREATE TABLE books"
  ```

  > **`information_schema.CHECK_CONSTRAINTS` を `TABLE_NAME` で絞らないこと。**
  > このビューは `CONSTRAINT_SCHEMA` / `CONSTRAINT_NAME` / `CHECK_CLAUSE` しか持たず、
  > `TABLE_NAME` 列は**存在しない**（`ERROR 1054 (42S22): Unknown column 'TABLE_NAME'
  > in 'where clause'` になる）。テーブルで絞るには `TABLE_CONSTRAINTS` との結合が要るため、
  > 上の `SHOW CREATE TABLE` のほうが短く確実。
- [ ] `vendor/bin/pint --test` が違反 0

## やらないこと

- Controller / View（Phase 3 で実施）
- Enum の `label()` メソッド（Phase 3 で実施）
- Action クラス（Phase 3 で実施）
- Seeder（Phase 5 で実施）
- Queue 関連のマイグレーション・モデル・設定ファイルへの手出し

## 完了後

`/verify` を実行し、結果を報告。
