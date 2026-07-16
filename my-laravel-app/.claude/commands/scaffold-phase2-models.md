---
description: フェーズ2 - DB スキーマからモデル・マイグレーションを生成する
---

# Phase 2: モデルとマイグレーション

`docs/db-schema.md` の定義に厳密に従ってマイグレーションとモデルを作成する。テーブル定義・カラム制約・インデックス・enum 値・リレーションはすべて `docs/db-schema.md` が一次情報。

## 実行順序

`@docs/db-schema.md` の ER 図・リレーション定義を読み、FK の参照先テーブルを先に作る順序で作成すること。Breeze が生成する `users` テーブルは他テーブルの FK が `users.id` を参照するため、FK 依存の有無にかかわらず必ず最初に対応する。

## 手順

### users テーブルの補正

Phase 1 で Breeze がインストール済みのため `users` テーブルのマイグレーション自体は存在する。以下を追加するマイグレーションを新規作成する:

```sh
php artisan make:migration add_role_to_users_table --table=users
```

`docs/db-schema.md` の `users` テーブル定義に合わせて `role`（`tinyInteger`, `NOT NULL`, `default: 0`）カラムを追加する。

`App\Models\User` に `role` を `$fillable` に追加し、`casts()` に `'role' => UserRole::class` を追加する（`UserRole` Enum は次のステップで作成）。`app/Enums/UserRole.php`:

```php
enum UserRole: int
{
    case Member = 0;
    case Admin = 1;
}
```

`User` モデルに `isAdmin(): bool` メソッドを追加し、`role === UserRole::Admin` を返す。

### 残りのモデル

各モデルを `php artisan make:model Xxx -mf`（マイグレーション + ファクトリ同時生成）で雛形作成し、`docs/db-schema.md` の定義（NOT NULL、UNIQUE、CHECK 制約、インデックス、enum 値）に合わせて手動で補正する。

対象: `Category`, `Book`, `Tag`, `Lending`, `Notification`, `AuditLog`

`book_tags` は中間テーブルのため専用モデルは作らず、マイグレーションのみ `php artisan make:migration create_book_tags_table --create=book_tags` で作成する（`Book` / `Tag` モデルの `belongsToMany` のピボットテーブルとして扱う）。

> `App\Models\Notification` は Laravel 標準の `Illuminate\Notifications\Facades\Notification` ファサードと名前が衝突しないよう、Controller / Action での `use` 文に注意する（完全修飾名かエイリアスで区別する）。

ジェネレータの自動生成だけでは制約が足りないので、以下を必ず確認:

- すべての FK は `$table->foreignId('xxx_id')->constrained()`
- 必須カラムは `->nullable()` を付けない
- ユニーク制約は `->unique()`、CHECK 制約はマイグレーション内で `DB::statement()` により明示
- インデックスは `docs/db-schema.md` の通り
- `audit_logs` は `$table->timestamps()` ではなく `$table->timestamp('created_at')->useCurrent();` を使う

### CHECK 制約の書き方

`books` テーブルの `available_copies` には MySQL の CHECK 制約を 2 つ付ける。マイグレーション内での書き方:

```php
public function up(): void
{
    Schema::table('books', function (Blueprint $table) {
        // ここでは available_copies カラム自体は既に存在する前提
    });

    DB::statement('ALTER TABLE books ADD CONSTRAINT books_available_copies_non_negative CHECK (available_copies >= 0)');
    DB::statement('ALTER TABLE books ADD CONSTRAINT books_available_lte_total CHECK (available_copies <= total_copies)');
}

public function down(): void
{
    DB::statement('ALTER TABLE books DROP CHECK books_available_copies_non_negative');
    DB::statement('ALTER TABLE books DROP CHECK books_available_lte_total');
}
```

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

状態遷移用の外部パッケージは使わず、`Lending` モデルのメソッド（`approve()`, `reject()`, `returnBook()`）として実装する（`return` は PHP 予約語のためメソッド名に使えない）。各メソッド内で遷移元の state を確認し、不正な場合は `throw new \DomainException(...)` する。

`markOverdue()` のようなメソッドは作成しない。`Overdue` への遷移はバッチ相当の操作（将来 Queue を有効化した際に実装予定）であり、本フェーズでは Seeder で state を直接 `Overdue` に設定することで代替する。

### リレーション

テーブル定義と ER 図から方向を導出し、各モデルに `hasMany` / `belongsTo` / `belongsToMany` を記述する。中間テーブル（`book_tags`）は `belongsToMany` で結ぶ。削除時の挙動（`restrictOnDelete` / `cascadeOnDelete`）はマイグレーションの外部キー定義で `@docs/db-schema.md` の「削除時の挙動」セクション通りに設定する。

### Spatie Query Builder 対応

Model 側での特別な設定は不要。許可するフィルタ・ソートは Phase 3 で Controller 側に定義する（`docs/db-schema.md` の「Spatie Query Builder 対応」セクション参照）。

### マイグレーション実行

```sh
php artisan migrate
```

エラーが出たら止めて報告。勝手に `migrate:fresh` しない。

### Pint 自動修正

```sh
vendor/bin/pint app/Models app/Enums database/migrations
```

### モデルテスト

`make:model -f` が生成するファクトリは Faker の適当な値が入っているだけなので、`docs/db-schema.md` の定義に合わせて書き直すこと（ファイルが既に存在するため Read してから Write する）。`User` ファクトリのメールは `@test.local` ドメインにすること（Breeze 標準ファクトリのデフォルトドメインとテスト実行時に衝突しないようにするため）。

`tests/Unit/Models/` に各モデルの最低限のバリデーションテストを Pest で書く（`test/models` 相当のディレクトリ構成）。網羅すべき観点:

- presence（必須カラムのバリデーション、または DB の NOT NULL 制約）
- uniqueness
- enum（PHP Enum）キャストの確認
- リレーションの存在

```sh
php artisan test tests/Unit/Models
```

で all green を確認。

## このフェーズの完了基準

- [ ] `php artisan migrate:status` で全マイグレーションが `Ran`
- [ ] `php artisan test tests/Unit/Models` が all green
- [ ] マイグレーション定義（`database/migrations/`）が `docs/db-schema.md` の定義と一致
- [ ] 各モデルのリレーション・enum キャストが定義済み
- [ ] `books` テーブルに CHECK 制約が存在する

## やらないこと

- Controller / View（Phase 3 で実施）
- Action クラス（Phase 3 で実施）
- Seeder（Phase 4 で実施）
- Queue 関連のマイグレーション・モデル・設定ファイルへの手出し

## 完了後

`/verify` を実行し、結果を報告。
