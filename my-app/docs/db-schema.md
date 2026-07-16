# DB スキーマ

## ER 概略

```
users ──< lendings >── books >── categories
              │            │
              │            └─< book_tags >── tags
              │
              └─< notifications
              
audit_logs (独立、polymorphic 相当のカラム構成)
```

## テーブル定義

### users（Laravel Breeze 標準 + role 拡張）

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| name | string | NOT NULL |
| email | string | NOT NULL, UNIQUE |
| email_verified_at | timestamp | nullable |
| password | string | NOT NULL |
| role | tinyInteger | NOT NULL, default: 0（enum: `Member: 0`, `Admin: 1`） |
| remember_token | string(100) | nullable |
| created_at / updated_at | timestamp | |

インデックス: `email`

> パスワードリセットは Laravel 標準の `password_reset_tokens` テーブル（`email`, `token`, `created_at`）で管理する。Breeze インストール時に自動生成されるマイグレーションをそのまま使い、本プロジェクトで独自定義しない。

### categories

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| name | string | NOT NULL, UNIQUE |
| description | text | nullable |
| created_at / updated_at | timestamp | |

### books

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| category_id | bigint | NOT NULL, FK |
| isbn | string | UNIQUE, nullable |
| title | string | NOT NULL |
| author | string | NOT NULL |
| publisher | string | nullable |
| published_on | date | nullable |
| total_copies | integer | NOT NULL, default: 1 |
| available_copies | integer | NOT NULL, default: 1 |
| description | text | nullable |
| published | boolean | NOT NULL, default: false |
| created_at / updated_at | timestamp | |

インデックス: `category_id`, `isbn`, `title`

制約: `available_copies >= 0`, `available_copies <= total_copies`（CHECK 制約）

### tags

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| name | string | NOT NULL, UNIQUE |
| created_at / updated_at | timestamp | |

### book_tags（中間テーブル）

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| book_id | bigint | NOT NULL, FK |
| tag_id | bigint | NOT NULL, FK |
| created_at / updated_at | timestamp | |

インデックス: `(book_id, tag_id)` UNIQUE

### lendings（貸出記録）

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | NOT NULL, FK |
| book_id | bigint | NOT NULL, FK |
| state | tinyInteger | NOT NULL, default: 0（enum: `Requested: 0`, `Approved: 1`, `Returned: 2`, `Rejected: 3`, `Overdue: 4`） |
| requested_at | timestamp | NOT NULL |
| approved_at | timestamp | nullable |
| due_on | date | nullable |
| returned_at | timestamp | nullable |
| note | text | nullable |
| created_at / updated_at | timestamp | |

インデックス: `user_id`, `book_id`, `state`

#### state 遷移ルール

| 現在の state | 遷移先 | 操作 |
|---|---|---|
| `Requested` | `Approved` | 管理者承認 |
| `Requested` | `Rejected` | 管理者却下 |
| `Approved` / `Overdue` | `Returned` | メンバー返却 |

`Returned` と `Rejected` は終端 state（以降の遷移なし）。`Overdue` への変更はバッチ相当の操作（Seeder では state を直接指定して良い）。

### notifications

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | NOT NULL, FK |
| kind | tinyInteger | NOT NULL, default: 0（enum: `LendingApproved`, `LendingRejected`, `ReturnReminder`） |
| title | string | NOT NULL |
| body | text | nullable |
| read_at | timestamp | nullable |
| created_at / updated_at | timestamp | |

インデックス: `user_id`, `(user_id, read_at)`

> Laravel 標準の通知（`Illuminate\Notifications\Notifiable` / `notifications` テーブル）は使わない。`kind` による分類と `read_at` の単純な既読管理のみで十分なため、専用の `Notification` モデル・専用テーブルとして独自実装する。

### audit_logs

| カラム | 型 | 制約・既定値 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK（操作者、nullable） |
| target_type | string | NOT NULL |
| target_id | bigint | NOT NULL |
| action | string | NOT NULL（例: `create`, `update`, `delete`, `approve`） |
| changes_json | json | nullable |
| created_at | timestamp | NOT NULL |

> 監査ログは不変レコードのため `updated_at` を持たない。マイグレーションでは `$table->timestamps()` を使わず `$table->timestamp('created_at')->useCurrent();` と明示すること。

インデックス: `(target_type, target_id)`（`user_id` は `$table->foreignId('user_id')` で自動生成されるため個別の `index()` 呼び出しは不要）

## リレーション

テーブル定義と ER 図から方向を導出する。中間テーブル（`book_tags`）は `belongsToMany` で結ぶ（`Book::tags()` / `Tag::books()`）。

## バリデーション要点（Form Request のルールとして実装）

- `User`: email 必須・形式・一意、name 必須
- `Book`: title / author / category_id 必須、`total_copies` は 1 以上の整数、`available_copies` は 0 以上の整数、ISBN は形式チェック（あれば）
- `Lending`: state 遷移は Form Request ではなく Model のメソッド（`approve()` 等）内でバリデーションする
- `Tag` / `Category`: name 一意

## Spatie Query Builder 対応

検索機能を持つ画面で使うモデルに対して、Controller 側で `allowedFilters` / `allowedSorts` を定義する。

| モデル | allowedFilters | allowedSorts |
|---|---|---|
| Book | title, author, publisher, isbn, description, published, `AllowedFilter::exact('category_id')`, `AllowedFilter::exact('tags.id')` | created_at, title |
| User（admin 画面） | name, email, `AllowedFilter::exact('role')` | created_at, name |
| Lending（admin 画面） | `AllowedFilter::exact('state')`, `AllowedFilter::exact('user_id')`, `AllowedFilter::exact('book_id')` | requested_at, due_on |
| AuditLog | `AllowedFilter::exact('action')`, `AllowedFilter::exact('target_type')` | created_at |

## 削除時の挙動（外部キー制約 / Eloquent イベント）

| リレーション | 挙動 | 実現方法 |
|---|---|---|
| `User has many Lending` | 貸出履歴があるユーザーは削除不可 | マイグレーションで `->restrictOnDelete()`（もしくは `deleting` イベントで検知して例外） |
| `User has many Notification` | ユーザー削除時に連動削除 | マイグレーションで `->cascadeOnDelete()` |
| `Book has many Lending` | 貸出履歴がある書籍は削除不可 | マイグレーションで `->restrictOnDelete()` |
| `Book has many BookTag`（中間テーブル） | 書籍削除時に連動削除 | マイグレーションで `->cascadeOnDelete()` |
| `Category has many Book` | 書籍が紐づくカテゴリは削除不可 | マイグレーションで `->restrictOnDelete()` |

## テスト teardown でのレコード削除順序

FK 制約を持つテーブルは依存先を後に削除する（ER 図の矢印の逆順）:

```
AuditLog → Notification → Lending → BookTag → Book → Tag → Category → User
```

Laravel Dusk のシステムテストではブラウザが別プロセスで動作するため、DB トランザクションによるロールバックが効かない。各モデルの `truncate()`（外部キー制約を一時的に無効化した上で）をこの順序で呼び出す必要がある。詳細な実装は `.claude/commands/scaffold-phase3-ui.md` 参照。
