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

> **注意1（`role` を Mass assignment 対象にしない）**: `team-rules/security.md` の
> 「`id` や `role` 等の権限に関わるカラムを `$fillable` に含めない」に従い、**`role` は
> fillable に追加しない**（追加すると Mass assignment による権限昇格の余地が生まれる）。
> ロール変更（`PATCH /admin/users/{user}`）を明示代入で書く必要があるが、**その実装は
> Phase 3 の担当**であり、一次情報は `docs/api-spec.md` の同エンドポイントの項に置いてある
> （手順書は当該フェーズのセッションしか読まないため、ここには書かない）。Model Factory は
> fillable を経由しないため、`User::factory()->admin()` は問題なく機能する。

> **注意2（Laravel 13 の User モデルは属性ベース）**: `laravel new`（Laravel 13.x）が生成する `User` モデルは、`protected $fillable` / `protected $hidden` プロパティではなく PHP 属性 `#[Fillable([...])]` / `#[Hidden([...])]` を使う。上記の通り `role` は fillable に足さないので、`#[Fillable(['name', 'email', 'password'])]` はそのままでよい。

`casts()` に `'role' => UserRole::class` を追加する（`UserRole` Enum は次のステップで作成）。`app/Enums/UserRole.php`:

```php
enum UserRole: int
{
    case Member = 0;
    case Admin = 1;
}
```

`User` モデルに `isAdmin(): bool` メソッドを追加し、`role === UserRole::Admin` を返す。

> **注意3（larastan 用の `@property` 注釈）**: enum キャストしたカラム（`role`）は、`@property` PHPDoc が無いと larastan が `casts()` の型を推論できず `int` 扱いになり、`isAdmin()` の `role === UserRole::Admin` が **「常に false」と誤判定されて `vendor/bin/phpstan analyse` がエラーになる**（`team-rules/review-policy.md` の必須チェック）。モデルの docblock に `@property` を付けること:
> ```php
> /**
>  * @property UserRole $role
>  */
> class User extends Authenticatable
> ```
> 同様に enum キャストを持つ他モデル（`Lending::$state`, `Notification::$kind`）にも `@property` を付ける。
>
> **date / datetime キャストも同じ理由で `@property` が要る。** larastan はこれらも `string` と
> 推論するため、`Carbon` のメソッドを呼ぶコードが `Cannot call method toDateString() on string.`
> でエラーになる（Phase 3 の `ApproveLendingAction` が `$lending->due_on->toDateString()` を
> 使うため必ず踏む）。`Lending` には次を付けておくこと:
> ```php
> /**
>  * @property LendingState $state
>  * @property Carbon $requested_at
>  * @property Carbon|null $approved_at
>  * @property Carbon|null $due_on
>  * @property Carbon|null $returned_at
>  */
> ```

> **注意4（`Notifiable` トレイトとの衝突）**: `User` に `notifications()` の `hasMany` を定義しないこと。Breeze が付与する `Illuminate\Notifications\Notifiable` トレイトが既に `notifications()`（`MorphMany` 返り、パスワードリセットで利用）を提供しており、これを `HasMany` 返りで上書きすると larastan が非共変な戻り値型としてエラーにする。独自 `Notification` へのアクセスは `Notification` 側の `belongsTo(User::class)` で表現する。`User` に必要なリレーションは `lendings()`（`hasMany`）のみ。

### 残りのモデル

各モデルを `php artisan make:model Xxx -mf`（マイグレーション + ファクトリ同時生成）で雛形作成し、`docs/db-schema.md` の定義（NOT NULL、UNIQUE、CHECK 制約、インデックス、enum 値）に合わせて手動で補正する。

対象: `Category`, `Book`, `Tag`, `Lending`, `Notification`, `AuditLog`

`book_tags` は中間テーブルのため専用モデルは作らず、マイグレーションのみ `php artisan make:migration create_book_tags_table --create=book_tags` で作成する（`Book` / `Tag` モデルの `belongsToMany` のピボットテーブルとして扱う）。

**生成の順序を FK 依存に合わせること**（`make:model` はタイムスタンプ順でマイグレーションを並べるため、生成順がそのまま実行順になる）: `Category` → `Tag` → `Book` → `book_tags` → `Lending` → `Notification` → `AuditLog`。

> `App\Models\Notification` は Laravel 標準の `Illuminate\Notifications\Facades\Notification` ファサードと名前が衝突しないよう、Controller / Action での `use` 文に注意する（完全修飾名かエイリアスで区別する）。なお Laravel 13 の `laravel new` は標準の `notifications` テーブルのマイグレーションを生成しないため、`create_notifications_table` を新規作成してもテーブル名は衝突しない。

各モデルの `$fillable`（`User` 以外は従来どおり `protected $fillable` プロパティで可）・`casts()`・リレーションを定義する。enum キャスト（`Lending::$state` → `LendingState`, `Notification::$kind` → `NotificationKind`）を持つモデルには前述の `@property` 注釈を付ける。

Enum クラスは `app/Enums/` に置く。値は `docs/db-schema.md` の各テーブル定義に明示されているものを使い、**推測で採番しない**（`UserRole` / `LendingState` / `NotificationKind` の 3 つ）。

> **注意（`audit_logs` は `updated_at` を持たない）**: 不変レコードのため `AuditLog` モデルに
> `public $timestamps = false;` を設定する（設定しないと Eloquent が保存時に `updated_at` を
> 書こうとして「Unknown column 'updated_at'」で失敗する）。`created_at` はマイグレーションの
> `useCurrent()` により DB 側で設定される。この設定に伴い、次の 3 点が要る:
>
> - `changes_json` を `'changes_json' => 'array'` でキャストする
> - **`created_at` も `'created_at' => 'datetime'` でキャストする。** `$timestamps = false` の
>   モデルは `created_at` を**自動ではキャストしない**ため、明示しないと DB から読んだ値が
>   文字列のままになる。Phase 3 の監査ログ画面で `{{ $log->created_at?->format('Y-m-d H:i') }}`
>   と書くと `Call to a member function format() on string` で **500** になる（`?->` は null 用で、
>   文字列には効かない）。larastan 用に `@property \Illuminate\Support\Carbon|null $created_at` も付ける
> - **`created_at` は生成直後のインスタンスに載らない。** `useCurrent()` が生成するのは DB 側の
>   `DEFAULT CURRENT_TIMESTAMP` で、Eloquent は自分で設定も再取得もしないため
>   `AuditLog::factory()->create()->created_at` は **`null` を返す**。値を読むときは
>   `->fresh()` を挟む（忘れるとモデルテストが `Expecting null not to be null.` で落ちる）。
>   `User::$role` を DB の `default(0)` に任せた場合と同じ理屈で、後述のファクトリの注意と対になっている

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

> このマイグレーションは `use Illuminate\Support\Facades\DB;` を必要とする。また `ALTER TABLE ... ADD CONSTRAINT` は MySQL 固有の構文で SQLite では動かないため、テストは必ず MySQL の `bookkeeper_test` で実行すること（前提の phpunit.xml 設定を参照）。

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

状態遷移用の外部パッケージは使わず、`Lending` モデルのメソッド（`approve()`, `reject()`, `returnBook()`）として実装する（`return` は PHP 予約語のためメソッド名に使えない）。各メソッド内で遷移元の state を確認し、不正な場合は `throw new \DomainException(...)` する。在庫減算・通知などの副作用は Action（Phase 3）側で行い、モデルのメソッドは state 遷移（と対応する `approved_at` / `returned_at` の設定）に限定する。

`markOverdue()` のようなメソッドは作成しない。`Overdue` への遷移はバッチ相当の操作（将来 Queue を有効化した際に実装予定）であり、本フェーズでは Seeder で state を直接 `Overdue` に設定することで代替する。

### リレーション

テーブル定義と ER 図から方向を導出し、各モデルに `hasMany` / `belongsTo` / `belongsToMany` を記述する。削除時の挙動はマイグレーションの外部キー定義で `@docs/db-schema.md` の「削除時の挙動」セクション通りに設定する。`User` の `notifications()` は定義しない（前述の注意4）。

`belongsToMany` は中間テーブル名を明示し（`belongsToMany(Tag::class, 'book_tags')`）、`withTimestamps()` を付ける（`book_tags` は `created_at` / `updated_at` を持つため。付けないと attach 時に NOT NULL 違反になる）。

### Spatie Query Builder 対応

Model 側での特別な設定は不要。許可するフィルタ・ソートは Phase 3 で Controller 側に定義する（`docs/db-schema.md` の「Spatie Query Builder 対応」セクション参照）。

### マイグレーション実行

```sh
php artisan migrate
```

エラーが出たら止めて報告。勝手に `migrate:fresh` しない。

実行後、可逆性を確認する（`team-rules/coding-standards.md` の要求）:

```sh
php artisan migrate:rollback
php artisan migrate
```

### ファクトリ

`make:model -f` が生成するファクトリは中身が空（`return [];`）なので、`docs/db-schema.md` の定義に合わせて書くこと（ファイルが既に存在するため Read してから編集する）。

> **`UserFactory` だけは前提が違う。** `laravel new` / Breeze が既に生成済みで
> 中身も空でないため「**残りの**ファクトリ」に含まれない。**実行順序 1（users
> テーブルの補正）の一部として、`User` を触る時点で下の `User` の項まで読み、
> モデルと同時に直すこと**（後回しにすると `role` が `null` のままモデルテストが
> 落ちる）。

- `User` ファクトリのメールは `@test.local` ドメインにする（Breeze 標準ファクトリの既定ドメインとテスト実行時に衝突しないようにするため）。`role` を扱う `admin()` state も追加する

  ```php
  'email' => fake()->unique()->userName().'@test.local',
  ```

  > **`fake()->safeEmail('test.local')` と書かないこと。** Faker の `safeEmail()` は
  > **引数を取らず**、常に `example.com` / `.net` / `.org` を返す。
  - **`definition()` にも `'role' => UserRole::Member` を明示すること**。マイグレーションの `default(0)` に任せると、`User::factory()->create()` が返す**インスタンスに `role` 属性が載らない**（DB 側の既定値は INSERT 後に再取得しない限りモデルへ反映されない）。この状態で `$user->role` を読むと enum キャストが効かず `null` が返り、後述のモデルテスト「enum キャストの確認」が `Failed asserting that null is identical to an object of class "App\Enums\UserRole".` で落ちる
- **`Book` ファクトリの既定は「在庫満杯」（`available_copies` = `total_copies`）にすること**。`fake()->numberBetween()` を 2 つ独立に呼ぶと CHECK 制約違反で `QueryException` になり、`available_copies` に 0 を許すと `Lending::factory()` が連鎖生成した書籍の承認が在庫チェックに弾かれて**確率的に落ちるテスト**になる。ファクトリの既定は「素直に使って通る値」とし、在庫切れの検証用に `outOfStock()` state（`available_copies = 0`）を用意して異常系はテスト側で明示する
  - **`available_copies` はローカル変数ではなくクロージャで `$attributes['total_copies']` から導出すること。**

    ```php
    return [
        // ...
        'total_copies' => fake()->numberBetween(1, 5),
        'available_copies' => fn (array $attributes) => $attributes['total_copies'],
    ];
    ```

    ローカル変数（`$totalCopies = fake()->numberBetween(1, 5);` を 2 箇所で使う書き方）でも
    引数なしの `Book::factory()->create()` は通るため、Phase 2 のモデルテストでは気付けない。
    しかし**呼び出し側が `total_copies` だけを上書きすると既定の `available_copies` が
    そのまま残り**、`Book::factory()->create(['total_copies' => 2])` が
    `SQLSTATE[HY000]: General error: 3819 Check constraint 'books_available_lte_total' is violated.`
    で落ちる。これは Phase 4 の Dusk（返却テストで在庫を指定して書籍を作る）で初めて
    顕在化するため、**Phase 2 の時点でクロージャにしておくこと**。
    `outOfStock()` などの state は definition の解決後に適用されるので影響を受けない。
- `Lending` ファクトリには state ごとの state メソッド（`approved()`, `overdue()`, `returned()`, `rejected()`）を用意しておくと、モデルテストと Phase 4・5 の Feature / Dusk テストの両方で使える
  - **Seeder では使わない。** Phase 5 の Seeder は `docs/seeds.md` の固定値を `firstOrCreate()` で投入する方式のため、ファクトリを経由しない。`approved()` の `due_on` は `docs/api-spec.md` の承認仕様（14 日後）に従うので、**seeds.md の Approved サンプル（`due_on = 7 日後`）とは一致しない**。Seeder でこの state を使うと seeds.md と食い違うデータが入る

### モデルテスト

> **注意（Pest の Unit ディレクトリ設定）**: `tests/Unit/` は既定では素の PHPUnit `TestCase` にバインドされており、Laravel アプリが起動しない（DB も使えない）。DB を伴うモデルテストを `tests/Unit/Models/` に置くため、`tests/Pest.php` に次のバインドを追加すること:
> ```php
> pest()->extend(TestCase::class)
>     ->use(RefreshDatabase::class)
>     ->in('Unit/Models');
> ```
> これが無いと `tests/Unit/Models/` のテストは Laravel を起動できず `A facade root has not been set.` 等で失敗する。`TestCase` / `RefreshDatabase` は `tests/Pest.php` の冒頭で既に import 済みなので、**完全修飾名では書かないこと**（Pint の `fully_qualified_strict_types` が短縮するため差分が出る）。

`tests/Unit/Models/` に各モデルの最低限のバリデーションテストを Pest で書く（`test/models` 相当のディレクトリ構成）。網羅すべき観点:

- presence（必須カラムのバリデーション、または DB の NOT NULL 制約）
- uniqueness
- enum（PHP Enum）キャストの確認
- リレーションの存在
- `books` の CHECK 制約（`available_copies` の範囲違反で `QueryException`）
- 削除時の挙動（`restrictOnDelete` で `QueryException`、`cascadeOnDelete` で連動削除されること）
- `role` が Mass assignment されないこと（`User::create()` に `role` を渡しても `Member` のままであること）
  - **`create()` 直後のインスタンスから `role` を読まない。** fillable が `role` を捨てるため属性が載らず、
    DB 側の `default(0)` も再取得するまで反映されないので `null` が返る。`->fresh()` を挟んでから確認する
- **`Lending` の遷移メソッド**（`approve()` / `reject()` / `returnBook()`）の正常系と、不正な遷移元で `DomainException` が送出されること（Phase 3 の Action がこれらに直接依存する）

**各観点につき、該当するモデルごとに最低 1 件書く**（観点が当てはまらないモデルは飛ばす）。上限は設けない。

```sh
php artisan test tests/Unit/Models
```

で all green を確認。

### Pint 自動修正

モデルテストを書き終えてから実行する:

```sh
vendor/bin/pint
```

その後 `vendor/bin/pint --test` が違反 0 であることを確認する。

## このフェーズの完了基準

まず `bin/check-repo.sh`（読み取りのみ）を実行し、終了コード 0 を確認してから以下を確認する。

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
