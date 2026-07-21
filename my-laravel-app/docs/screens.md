# 画面構成

## 公開（未ログイン可）

| パス | 画面名 | 概要 |
|---|---|---|
| `GET /` | ランディング | ログイン誘導 |
| `GET /login` | ログイン | Laravel Breeze |
| `GET /forgot-password` | パスワード再発行 | Laravel Breeze |

## メンバー領域（要ログイン）

| パス | 画面名 | 概要 |
|---|---|---|
| `GET /books` | 蔵書一覧 | 検索 / ページネーション / タグ・カテゴリで絞り込み（Livewire コンポーネント） |
| `GET /books/{book}` | 蔵書詳細 | 在庫数表示、借用申請ボタン |
| `POST /lendings` | 借用申請 | 詳細画面から POST |
| `GET /lendings` | 自分の貸出一覧 | 状態フィルタ（Livewire コンポーネント） |
| `GET /lendings/{lending}` | 自分の貸出詳細 | 返却ボタン |
| `PATCH /lendings/{lending}/return` | 返却操作 | state を Returned に |
| `GET /notifications` | 通知一覧 | 未読/既読切替 |
| `PATCH /notifications/{notification}/read` | 既読化 | |
| `GET /profile/edit` | プロフィール編集 | |
| `PATCH /profile` | プロフィール更新 | name / email の更新 |

## 管理者領域（要ログイン + admin ロール）

URL プレフィックス: `/admin/`

| パス | 画面名 | 概要 |
|---|---|---|
| `GET /admin` | ダッシュボード | 申請待ち件数 / 延滞件数 |
| `GET /admin/users` | ユーザー一覧 | 検索 |
| `GET /admin/users/{user}` | ユーザー詳細 | 貸出履歴含む |
| `PATCH /admin/users/{user}` | ロール変更 | Member ⇄ Admin |
| `GET /admin/categories` | カテゴリ一覧 | 作成・編集フォームは一覧画面内（専用の create / edit 画面は作らない） |
| `POST /admin/categories` | カテゴリ作成 | |
| `PATCH /admin/categories/{category}` | カテゴリ更新 | |
| `DELETE /admin/categories/{category}` | カテゴリ削除 | |
| `GET /admin/tags` | タグ一覧 | 作成・編集フォームは一覧画面内（専用の create / edit 画面は作らない） |
| `POST /admin/tags` | タグ作成 | |
| `PATCH /admin/tags/{tag}` | タグ更新 | |
| `DELETE /admin/tags/{tag}` | タグ削除 | |
| `GET /admin/books` | 蔵書一覧 | |
| `GET /admin/books/create` | 蔵書登録 | |
| `POST /admin/books` | 蔵書作成 | |
| `GET /admin/books/{book}/edit` | 蔵書編集 | |
| `PATCH /admin/books/{book}` | 蔵書更新 | |
| `DELETE /admin/books/{book}` | 蔵書削除 | |
| `GET /admin/lendings` | 貸出申請一覧 | 状態フィルタ（Livewire コンポーネント） |
| `GET /admin/lendings/{lending}` | 貸出詳細 | 承認・却下ボタン |
| `PATCH /admin/lendings/{lending}/approve` | 申請承認 | |
| `PATCH /admin/lendings/{lending}/reject` | 申請却下 | |
| `GET /admin/audit-logs` | 監査ログ | 検索 / 日付絞り込み |

## レイアウト

### `layouts/app.blade.php`（メンバー向け）

```
┌─────────────────────────────────────────────┐
│ Header: ロゴ | 蔵書 | 自分の貸出 | 通知🔔 | ユーザー名▾ │
├─────────────────────────────────────────────┤
│                                             │
│           {{ $slot }}                       │
│                                             │
├─────────────────────────────────────────────┤
│ Footer: © Company                           │
└─────────────────────────────────────────────┘
```

### `layouts/admin.blade.php`（管理者向け）

```
┌─────────────────────────────────────────────┐
│ Header: BookKeeper Admin   | ← メンバー画面へ | ▾ │
├──────────┬──────────────────────────────────┤
│ Sidebar  │                                  │
│ - Dash   │       {{ $slot }}                │
│ - Users  │                                  │
│ - Books  │                                  │
│ - Cat.   │                                  │
│ - Tags   │                                  │
│ - Lend.  │                                  │
│ - Audit  │                                  │
└──────────┴──────────────────────────────────┘
```

## 画面共通の作法

- 一覧画面はページネーション（Laravel 標準の `paginate(25)`）。
- 検索フォームは Spatie Query Builder（`QueryBuilder::for(Model::class)->allowedFilters([...])`）。
- 削除は確認ダイアログ必須。Livewire コンポーネント内は `wire:confirm="削除しますか？"`（Livewire v3 標準機能）、非 Livewire のフォームは Alpine.js で `<form x-data x-on:submit="confirm('削除しますか？') || $event.preventDefault()">` のように実装する。**`x-data` を必ず付けること**（空でよい）。Alpine v3 は `x-data` スコープ内の要素しか `x-on:` ディレクティブを処理しないため、`x-data` の無い素の `<form x-on:submit>` は Alpine に**エラーも出さず無視され、確認なしで削除が実行される**。これは Livewire 経由で Alpine が読み込まれていても起きる（Alpine の読み込み有無とは別問題）。
- フラッシュメッセージは画面上部、Tailwind の色でステータス表示（`session('status')` = 緑、`session('error')` = 赤）。
- フォームエラーは入力欄の直下に赤字で表示（`$errors->first('field')`）。

### ボタン・ラベルの標準（テスト記述時の参照用）

| 場面 | ラベル |
|---|---|
| 作成・編集フォームの submit（全リソース共通） | `保存` |
| 削除ボタン | `削除` |
| ユーザーのロール変更 submit | `変更する` |
| ユーザーのロール変更 select の label | `ロール変更` |
| 通知の既読化ボタン | `既読` |
| カテゴリフォームの name フィールド label | `カテゴリ名` |
| タグフォームの name フィールド label | `タグ名` |

### enum の表示ラベル

一覧・詳細画面に表示する enum の日本語表記。**各 Enum クラスの `label(): string` メソッドとして実装し、ビューからは `{{ $lending->state->label() }}` で参照する**（Blade 側に `@if` の連鎖や配列マッピングを書かない）。

| enum | 値 | 表示ラベル |
|---|---|---|
| `LendingState` | `Requested` | `申請中` |
| | `Approved` | `借用中` |
| | `Returned` | `返却済み` |
| | `Rejected` | `却下` |
| | `Overdue` | `延滞中` |
| `NotificationKind` | `LendingApproved` | `承認通知` |
| | `LendingRejected` | `却下通知` |
| | `ReturnReminder` | `返却リマインド` |
| `UserRole` | `Member` | `メンバー` |
| | `Admin` | `管理者` |

> **Breeze のログインフォームのラベル文言（メールアドレス欄・パスワード欄・ログインボタン）は `laravel-lang/lang` の翻訳ファイルが提供する文言をそのまま使う。** バージョンによって訳語が変わりうるため、この docs では固定値を明示しない。Phase 3 でシステムテストを書く前に、Breeze が `resources/views/` 配下に生成した認証ビュー（Livewire スタックでは `resources/views/livewire/pages/auth/` 等）と `lang/` 配下の翻訳ファイル（`lang/ja.json` 等）を実際に Read し、ラベル文言を確認してからテストコードに反映すること（推測で書くと不一致による修正ループが発生する。なお Breeze はビューを vendor ディレクトリではなくプロジェクト直下に publish する）。
