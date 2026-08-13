# DB スキーマ

## ER 概略

```
users ──< lendings >── books >── categories
  │                        │
  │                        └─< book_tags >── tags
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

インデックス: `category_id`, `isbn`, `title`（`category_id` は `$table->foreignId('category_id')` の外部キー制約が、`isbn` は `->unique()` がそれぞれインデックスを自動生成するため、マイグレーションで個別に `index()` を呼ぶのは `title` のみ）

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
| kind | tinyInteger | NOT NULL, default: 0（enum: `LendingApproved: 0`, `LendingRejected: 1`, `ReturnReminder: 2`） |
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
  - **新規登録フォームに `available_copies` の入力欄を出さない。** `total_copies` と同値で初期化する（在庫が満杯の状態で登録される）
  - **編集フォームでは直接編集できる**が、Form Request に **`lte:total_copies` を必ず付ける**。付けないと `total_copies` を超える値が通り、CHECK 制約 `books_available_lte_total` に違反して **500** になる（バリデーションで弾けば入力欄の下にエラーが出る）
- `Lending`: state 遷移は Form Request ではなく Model のメソッド（`approve()` 等）内でバリデーションする
- `Tag` / `Category`: name 一意

## Spatie Query Builder 対応

検索機能を持つ画面で使うモデルに対して、Controller 側で `allowedFilters` / `allowedSorts` を定義する。

> **注意**: v7 の `allowedFilters()` / `allowedSorts()` は**可変長引数のみ**を受け取る。下表の内容は配列ではなく引数の並びとして渡すこと（`->allowedFilters('title', 'author', AllowedFilter::exact('category_id'))`）。詳細は `docs/architecture.md` の Model セクション参照。

> **注意（`published` はメンバー画面では効かない）**: メンバー向けの蔵書一覧・詳細は `published = true` の**強制スコープ**が掛かるため、`published` フィルタが意味を持つのは管理画面だけである（`docs/screens.md` のメンバー領域の注記が一次情報）。メンバー画面のクエリでこのフィルタを許可しても、強制スコープが優先して結果は変わらない。

| モデル | allowedFilters | allowedSorts | 既定順序（ソート未指定時） |
|---|---|---|---|
| Book | title, author, publisher, isbn, description, published（**管理画面のみ有効**）, `AllowedFilter::exact('category_id')`, `AllowedFilter::exact('tags.id')` | created_at, title | `id` 昇順 |
| User（admin 画面） | name, email, `AllowedFilter::exact('role')` | created_at, name | `id` 昇順 |
| Lending（admin 画面・member 画面とも） | `AllowedFilter::exact('state')`, `AllowedFilter::exact('user_id')`, `AllowedFilter::exact('book_id')` | requested_at, due_on | `requested_at` 降順 |
| AuditLog | `AllowedFilter::exact('action')`, `AllowedFilter::exact('target_type')` | created_at | `created_at` 降順 |
| Notification | —（一覧は既読 / 未読の切替のみ） | — | `created_at` 降順 |
| Category / Tag | —（一覧のみ） | — | `id` 昇順 |

> **既定順序は必ず明示すること（`defaultSort()` か `orderBy()`）。** MySQL は `ORDER BY` の
> 無いクエリの行順序を保証しないため、指定しないとページネーションが不安定になる。
> 時系列で見るリソース（貸出・通知・監査ログ）は**新しい順**、マスタ系（書籍・ユーザー・
> カテゴリ・タグ）は**投入順（`id` 昇順）**に揃える。

## 削除時の挙動（外部キー制約 / Eloquent イベント）

| リレーション | 挙動 | 実現方法 |
|---|---|---|
| `User has many Lending` | 貸出履歴があるユーザーは削除不可 | マイグレーションで `->restrictOnDelete()`（もしくは `deleting` イベントで検知して例外） |
| `User has many Notification` | ユーザー削除時に連動削除 | マイグレーションで `->cascadeOnDelete()` |
| `Book has many Lending` | 貸出履歴がある書籍は削除不可 | マイグレーションで `->restrictOnDelete()` |
| `Book has many BookTag`（中間テーブル） | 書籍削除時に連動削除 | マイグレーションで `->cascadeOnDelete()` |
| `Tag has many BookTag`（中間テーブル） | タグ削除時に連動削除（書籍からタグが外れるだけで、書籍自体は残る） | マイグレーションで `->cascadeOnDelete()` |
| `Category has many Book` | 書籍が紐づくカテゴリは削除不可 | マイグレーションで `->restrictOnDelete()` |
| `User has many AuditLog` | 操作者が削除されてもログは残し、`user_id` を NULL にする | マイグレーションで `->nullOnDelete()`（`user_id` は nullable） |

> **「削除不可」の画面挙動（実装ブレ防止のため固定）**: `restrictOnDelete` の関連レコードが
> ある状態で削除しようとすると DB が `QueryException`（`errno 1451`）を投げる。**Controller の
> `destroy` では、この例外を `try/catch` で捕まえずに、削除前に関連の有無を `exists()` で
> 事前チェックする**こと。
> ```php
> if ($book->lendings()->exists()) {
>     return back()->with('error', '貸出履歴があるため削除できません。');
> }
> $book->delete();
> ```
> `try/catch (QueryException)` で書くと、larastan が「例外を投げうる処理が catch 節の外に無い」
> と見て **Dead catch（`Dead catch - QueryException is never thrown in the try block.`）** で
> `phpstan analyse` を落とす（Eloquent の `delete()` の型が例外送出を宣言しないため）。事前
> チェックならこれを踏まない。フラッシュ文言は下表で固定する。
>
> | 削除対象（関連レコードあり） | フラッシュ文言 |
> |---|---|
> | ユーザー（貸出履歴あり） | `貸出履歴があるため削除できません。` |
> | 書籍（貸出履歴あり） | `貸出履歴があるため削除できません。` |
> | カテゴリ（書籍が紐づく） | `書籍が登録されているため削除できません。` |

## テスト teardown でのレコード削除順序

FK 制約を持つテーブルは依存先を後に削除する（ER 図の矢印の逆順）:

```
AuditLog → Notification → Lending → BookTag → Book → Tag → Category → User
```

Laravel Dusk のシステムテストではブラウザが別プロセスで動作するため、DB トランザクションによるロールバックが効かない。各モデルの `truncate()`（外部キー制約を一時的に無効化した上で）をこの順序で呼び出す必要がある。詳細な実装は `.claude/commands/scaffold-phase4-ui-tests.md` 参照。
