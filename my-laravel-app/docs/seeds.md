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

> **`role` は `firstOrCreate()` の第 2 引数で渡さないこと。** `team-rules/security.md` の方針により
> `role` は Mass assignment の対象外（`$fillable` に含めない）なので、
> `firstOrCreate([...], ['role' => ...])` と書いても**例外を出さずに黙って捨てられ、全員が
> `Member` で作られる**。取得してから明示代入する:
> ```php
> $user = User::firstOrCreate(['email' => $attributes['email']], [...]);
> $user->role = $attributes['role'];
> $user->save();
> ```
> 管理者が `Member` で作られると、症状は「管理画面へ行くと `home` へリダイレクトされる」と
> なって認可の実装ミスに見えるため、原因にたどり着きにくい。

## カテゴリ（4 件）

- 技術書
- 小説
- ビジネス
- 趣味・実用

## タグ（13 件）

`Ruby`, `Rails`, `JavaScript`, `アーキテクチャ`, `マネジメント`, `デザイン`, `古典`, `PHP`, `Laravel`, `AI`, `セキュリティ`, `ネットワーク`, `習慣`

## 書籍（30 件）

Faker でランダム生成ではなく、明示的な書籍を入れる（画面の見え方を予測可能にするため）。

下表 8 行目の「未公開書籍サンプル」（`published = false`）は、**メンバー画面では表示されない**ことを確認するための固定データである（`docs/screens.md` のメンバー領域の注記参照）。管理画面では 30 件すべて、メンバー画面では 29 件が見える。

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
| 978-4-7980-7527-3 | PHPフレームワーク Laravel入門 第3版 | 掌田津耶乃 | 技術書 | PHP, Laravel | 3 | true |
| 978-4-8156-2529-0 | これからはじめるLaravel実践入門 | 山田祥寛 | 技術書 | PHP, Laravel | 2 | true |
| 978-4-7980-7573-0 | やさしいMCP入門 | 御田稔 | 技術書 | AI | 4 | true |
| 978-4-297-14622-1 | 改訂新版 良いコード／悪いコードで学ぶ設計入門 | 仙塲大也 | 技術書 | アーキテクチャ | 5 | true |
| 978-4-8144-0091-1 | Tidy First? 個人で実践する経験主義的ソフトウェア設計 | Kent Beck | 技術書 | アーキテクチャ | 2 | true |
| 978-4-8156-3660-9 | AIエージェント開発／運用入門 | 御田稔 | 技術書 | AI | 3 | true |
| 978-4-06-540140-8 | 現場で活用するためのAIエージェント実践入門 | 太田真人 | 技術書 | AI | 2 | true |
| 978-4-06-536984-5 | ことばの意味を計算するしくみ | 谷中瞳 | 技術書 | AI | 1 | true |
| 978-4-8156-3425-4 | 実践サイバーセキュリティ入門講座 | 林憲明 | 技術書 | セキュリティ | 2 | true |
| 978-4-7981-8157-8 | 7日間でハッキングをはじめる本 | 野溝のみぞう | 技術書 | セキュリティ | 3 | true |
| 978-4-297-14722-8 | 社会人1年生の情報セキュリティ超入門 | ハッカーかず | 技術書 | セキュリティ | 4 | true |
| 978-4-8156-2705-8 | 図解入門TCP/IP 第2版 | みやたひろし | 技術書 | ネットワーク | 2 | true |
| 978-4-7981-8966-6 | エンジニア育成現場の「失敗」集めてみた。 | 出石聡史 | ビジネス | マネジメント | 3 | true |
| 978-4-7981-8552-1 | 両利きのプロジェクトマネジメント | 米山知宏 | ビジネス | マネジメント | 2 | true |
| 978-4-8283-1114-2 | エンジニアの持続的成長37のヒント | 阪上誠 | ビジネス | マネジメント | 2 | true |
| 978-4-7981-9226-0 | 「分かった！」と思わせる説明の技術 | 佐々木真 | ビジネス | マネジメント | 3 | true |
| 978-4-910063-44-7 | サム・アルトマン：「生成AI」で世界を手にした起業家の野望 | キーチ・ヘイギー | ビジネス | AI | 2 | true |
| 978-4-478-12072-9 | ゆるストイック | 佐藤航陽 | ビジネス | 習慣 | 3 | true |
| 978-4-295-41030-0 | 世界の一流は「休日」に何をしているのか | 越川慎司 | ビジネス | 習慣 | 2 | true |
| 978-4-296-07106-7 | ＃100日チャレンジ | 大塚あみ | 趣味・実用 | 習慣 | 3 | true |
| 978-4-8156-3341-7 | 科学的に証明された すごい習慣大百科 | 堀田秀吾 | 趣味・実用 | 習慣 | 2 | true |
| 978-4-910063-41-6 | 歩く マジで人生が変わる習慣 | 池田光史 | 趣味・実用 | 習慣 | 4 | true |

## 貸出（5 件）

各状態を最低 1 件作成する。

| ユーザー | 書籍 | state | 補足 |
|---|---|---|---|
| 一般花子 | プロを目指す人のためのRuby入門 | Requested | 申請中 |
| 一般花子 | 吾輩は猫である | Approved | 借用中、due_on = 7 日後 |
| 一般次郎 | リファクタリング | Overdue | 延滞中、due_on = 3 日前（Seeder では state を直接 `Overdue` で作成する） |
| 一般次郎 | こころ | Returned | 返却済み |
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
  - **上記 8 件より下の 22 件は貸出が 1 件も紐づかないため、`available_copies = total_copies`（在庫表の値をそのまま）とする**
- 冪等性: 各レコードは `firstOrCreate()`（ユニークなキーを第一引数に指定）を使う。

## 冪等キー（`firstOrCreate()` の第一引数）

**リソースごとに次のキーを使う。** 何をキーにするかで冪等性が壊れるため固定する。

| Seeder | 第一引数 |
|---|---|
| `UserSeeder` | `['email' => ...]` |
| `CategorySeeder` / `TagSeeder` | `['name' => ...]` |
| `BookSeeder` | `['title' => ...]` |
| `LendingSeeder` | `['user_id' => ..., 'book_id' => ...]` |
| `NotificationSeeder` | `['user_id' => ..., 'title' => ...]` |
| `AuditLogSeeder` | `['target_type' => ..., 'target_id' => ..., 'action' => ...]` |

> **`BookSeeder` のキーに `isbn` を使わないこと。** 上の書籍表で「未公開書籍サンプル」の
> ISBN は `(なし)` = `null` であり、`firstOrCreate(['isbn' => null], [...])` は
> **`isbn IS NULL` の任意の行にマッチする**。今は null 行が 1 件だけなので偶然
> 冪等に見えるが、null ISBN の書籍を足した時点で別の本を「既存」と誤認して
> 投入をスキップする。書籍表のタイトルは全 30 件で一意なので `title` を使う。

> **`LendingSeeder` のキーが `user_id` 単独でも `book_id` 単独でも足りない。**
> 上の貸出表では一般花子が 3 件・一般次郎が 2 件あり、`user_id` 単独では 1 件目しか
> 作られない。書籍側も同様なので、**必ず 2 カラムの組**で指定する
> （表の 5 行はこの組で一意）。
