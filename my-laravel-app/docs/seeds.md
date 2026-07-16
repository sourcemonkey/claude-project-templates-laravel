# Seed データ仕様

`database/seeders/` に投入するサンプルデータ。`php artisan db:seed` で冪等に実行可能にする（既存があれば skip）。

`DatabaseSeeder` から各リソースの Seeder（`UserSeeder`, `CategorySeeder`, `TagSeeder`, `BookSeeder`, `LendingSeeder`, `NotificationSeeder`, `AuditLogSeeder`）を FK 依存の順序で `call()` する。

## アカウント

| email | password | name | role |
|---|---|---|---|
| `admin@example.local` | `password123` | 管理者太郎 | Admin |
| `member@example.local` | `password123` | 一般花子 | Member |
| `member2@example.local` | `password123` | 一般次郎 | Member |

README にこのテストアカウント表を記載すること。

## カテゴリ（4 件）

- 技術書
- 小説
- ビジネス
- 趣味・実用

## タグ（7 件）

`Ruby`, `Rails`, `JavaScript`, `アーキテクチャ`, `マネジメント`, `デザイン`, `古典`

## 書籍（8 件）

Faker でランダム生成ではなく、明示的な書籍を入れる（画面の見え方を予測可能にするため）。

| ISBN | タイトル | 著者 | カテゴリ | タグ | 在庫 | published |
|---|---|---|---|---|---|---|
| 978-4-87311-993-6 | プロを目指す人のためのRuby入門 | 伊藤淳一 | 技術書 | Ruby | 3 | true |
| 978-4-87311-672-0 | パーフェクト Ruby on Rails | すがわら | 技術書 | Ruby, Rails | 2 | true |
| 978-4-87311-758-1 | リファクタリング | Fowler | 技術書 | アーキテクチャ | 1 | true |
| 978-4-7981-5547-5 | エンジニアリングマネージャーのしごと | Camille Fournier | ビジネス | マネジメント | 2 | true |
| 978-4-04-110404-6 | 吾輩は猫である | 夏目漱石 | 小説 | 古典 | 4 | true |
| 978-4-10-101001-7 | こころ | 夏目漱石 | 小説 | 古典 | 2 | true |
| 978-4-7981-7456-8 | ふつうのデザイン | （著者A） | 趣味・実用 | デザイン | 1 | true |
| (なし) | 未公開書籍サンプル | （著者B） | 技術書 | JavaScript | 1 | false |

## 貸出（5 件）

各状態を最低 1 件作成する。

| ユーザー | 書籍 | state | 補足 |
|---|---|---|---|
| 一般花子 | プロを目指す人のためのRuby入門 | Requested | 申請中 |
| 一般花子 | 吾輩は猫である | Approved | 借用中、due_on = 7 日後 |
| 一般次郎 | リファクタリング | Overdue | 延滞中、due_on = 3 日前（Seeder では state を直接 `Overdue` で作成する） |
| 一般次郎 | こころ | Returned | 完了 |
| 一般花子 | ふつうのデザイン | Rejected | 却下サンプル |

## 通知（3 件）

- 一般花子: `LendingApproved`（吾輩は猫であるの承認）
- 一般次郎: `ReturnReminder`（延滞分のリマインド）
- 一般花子: `LendingRejected`（ふつうのデザインの却下）

## 監査ログ（3 件）

- 管理者太郎が書籍を 1 件更新: `action: "update"`, `changes_json: { "title" => ["旧タイトル", "新タイトル"] }`
- 管理者太郎が貸出を 1 件 approve: `action: "approve"`, `changes_json: { "state" => ["Requested", "Approved"] }`
- 管理者太郎がカテゴリを 1 件 create: `action: "create"`, `changes_json: null`

## 注意

- `available_copies` は以下の通り設定する（承認済み・延滞中の貸出のみ在庫を消費する）:
  - プロを目指す人のためのRuby入門: `available_copies = 3`（Requested は消費しない）
  - パーフェクト Ruby on Rails: `available_copies = 2`
  - リファクタリング: `available_copies = 0`（Overdue で 1 冊消費中）
  - エンジニアリングマネージャーのしごと: `available_copies = 2`
  - 吾輩は猫である: `available_copies = 3`（Approved で 1 冊消費中）
  - こころ: `available_copies = 2`（Returned は消費しない）
  - ふつうのデザイン: `available_copies = 1`（Rejected は消費しない）
  - 未公開書籍サンプル: `available_copies = 1`
- 冪等性: 各レコードは `firstOrCreate()`（ユニークなキーを第一引数に指定）を使う。
