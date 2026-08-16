# 画面構成

## 公開（未ログイン可）

| パス | 画面名 | 概要 |
|---|---|---|
| `GET /` | ランディング | ログイン誘導。**見出しに `BookKeeper` を含める**（Phase 4 の `tests/Browser/ExampleTest.php` がこの文言を assert する）。未ログインでも `layouts/app.blade.php` を使う（nav 側が `@auth` / `@guest` で分岐する） |
| `GET /login` | ログイン | Laravel Breeze |
| `GET /forgot-password` | パスワード再発行 | Laravel Breeze |

## メンバー領域（要ログイン）

| パス | 画面名 | 概要 |
|---|---|---|
| `GET /books` | 蔵書一覧 | 検索 / ページネーション / タグ・カテゴリで絞り込み（Livewire コンポーネント `App\Livewire\Books\BookList`）。**`published = true` の書籍のみ**（下記）。検索欄に出すのは `title` / `author` / カテゴリ / タグの 4 つ（`docs/db-schema.md` の `allowedFilters` にはこれ以外も並ぶが、UI に出すのはこの 4 つに固定する） |
| `GET /books/{book}` | 蔵書詳細 | 在庫数表示、借用申請ボタン。**`published = false` は 404**（下記） |
| `POST /lendings` | 借用申請 | 詳細画面から POST |
| `GET /lendings` | 自分の貸出一覧 | 状態フィルタ（Livewire コンポーネント `App\Livewire\Lendings\LendingList`） |
| `GET /lendings/{lending}` | 自分の貸出詳細 | 返却ボタン |
| `PATCH /lendings/{lending}/return` | 返却操作 | state を Returned に |
| `GET /notifications` | 通知一覧 | 未読/既読切替 |
| `PATCH /notifications/{notification}/read` | 既読化 | |
| `GET /profile/edit` | プロフィール編集 | |
| `PATCH /profile` | プロフィール更新 | name / email の更新 |

> **未公開書籍（`published = false`）はメンバーには見せない。** `GET /books` の一覧クエリに
> `where('published', true)` を強制スコープとして掛け、`GET /books/{book}` は未公開なら
> **404 を返す**（借用申請の導線ごと塞ぐ）。これは利用者が指定するフィルタではなく、
> メンバー画面側で常に効く条件である。
>
> **404 は Policy ではなく Controller の存在判定で表現すること。** `BookPolicy::view()` を
> false にすると `home` へのリダイレクト + `error` フラッシュになり **404 にならない**。
> `view()` は `true` のままにし、`BookController::show()` で `NotFoundHttpException` を投げる。
> **テストには `assertNotFound()` を書くこと**（リダイレクト実装でも「メンバーには見えない」
> という結果自体は満たせてしまうため、それ以外では検出できない）。
>
> `docs/db-schema.md` の `published` フィルタは**管理画面専用**。メンバー画面では強制スコープが
> 優先するため `filter[published]=false` を指定しても結果は変わらない。
>
> **メンバーには 30 件中 29 件が見える**（Seeder が未公開書籍サンプルを 1 件投入するため）。
> 25 件/ページなので **2 ページ**（25 件・4 件）になる。件数を検証するテストはこの値を使う。

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
| `GET /admin/books` | 蔵書一覧 | 検索欄に出すのは `title` / `author` / `published` の 3 つ |
| `GET /admin/books/create` | 蔵書登録 | |
| `POST /admin/books` | 蔵書作成 | |
| `GET /admin/books/{book}/edit` | 蔵書編集 | |
| `PATCH /admin/books/{book}` | 蔵書更新 | |
| `DELETE /admin/books/{book}` | 蔵書削除 | |
| `GET /admin/lendings` | 貸出申請一覧 | 状態フィルタ（Livewire コンポーネント `App\Livewire\Admin\Lendings\LendingList`） |
| `GET /admin/lendings/{lending}` | 貸出詳細 | 承認・却下ボタン |
| `PATCH /admin/lendings/{lending}/approve` | 申請承認 | |
| `PATCH /admin/lendings/{lending}/reject` | 申請却下 | |
| `GET /admin/audit-logs` | 監査ログ | `action` / `target_type` での絞り込みと `created_at` のソート（**日付範囲での絞り込みは持たない**）。**対象は `target_type` / `target_id` をそのまま表示し、対象レコードを解決しない**。**操作者は `$log->user?->name ?? '-'` で表示する**（`user_id` は nullable） |

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

ヘッダ右端の `▾` はユーザーメニューで、**ログアウト**を提供する。

> **ログアウトは Breeze の Livewire コンポーネントに任せ、`logout` の名前付きルートを作らない。**
> Breeze は `App\Livewire\Actions\Logout` として提供するため `routes/web.php` に `logout` は
> 存在せず、`route('logout')` でフォームを組むと `Route [logout] not defined.` で 500 になる。
>
> `layouts/admin.blade.php` には**ログアウト専用の小さな Livewire コンポーネント**
> （`App\Livewire\Actions\Logout` を呼んで `route('home')` へリダイレクトする）をヘッダに
> 埋め込む（`<livewire:layout.navigation />` を持たないため）。

## 画面共通の作法

- 一覧画面はページネーション（Laravel 標準の `paginate(25)`）。
- **Livewire コンポーネントにするのは、上表で「（Livewire コンポーネント）」と明記した 3 画面だけ。**
  それ以外の一覧（`/admin/books` / `/admin/users` / `/admin/categories` / `/admin/tags` /
  `/admin/audit-logs`）は Controller + Blade で作り、検索条件はクエリ文字列で受ける
  （`QueryBuilder` が `request()` から読む）。クラス名は上表の指定に従う — **Phase 4 の
  `Livewire::test()` がこの名前を直接参照する**。
- 検索フォームは Spatie Query Builder（`QueryBuilder::for(Model::class)->allowedFilters([...])`）。
- 削除は確認ダイアログ必須。Livewire コンポーネント内は `wire:confirm="削除しますか？"`（Livewire v3 標準機能）、非 Livewire のフォームは Alpine.js で `<form x-data x-on:submit="confirm('削除しますか？') || $event.preventDefault()">` のように実装する。**`x-data` を必ず付けること**（空でよい。無いと確認なしで削除が実行される。`docs/stack.md` の Alpine の項）。
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
| 蔵書詳細の借用申請 submit | `借用を申請` |
| 貸出詳細の返却 submit（メンバー） | `返却` |
| 貸出詳細の承認 submit（管理者） | `承認` |
| 貸出詳細の却下 submit（管理者） | `却下` |
| 一覧画面の検索 submit（非 Livewire の管理画面） | `検索` |

> **貸出フローの 4 ボタン（借用を申請 / 返却 / 承認 / 却下）は Dusk が `press()` で
> 直接叩く。** 上表の他のラベルと同じく固定値として扱い、実装時に言い換えないこと。

### 確認ダイアログを出す操作（実装ブレ防止のため固定）

`x-data x-on:submit="confirm('...') || $event.preventDefault()"` を付ける操作と、その文言。

| 操作 | 確認文言 |
|---|---|
| 書籍・カテゴリ・タグの削除 | `削除しますか？` |
| 貸出の返却（メンバー） | `返却しますか？` |
| 貸出の却下（管理者） | `却下しますか？` |

承認（`承認`）には確認ダイアログを付けない。

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

> **Breeze のログインフォームのラベル文言（メールアドレス欄・パスワード欄・ログインボタン）は固定値を定めない**（`laravel-lang/lang` の訳語がバージョンで変わるため）。**テストを書く前に、Breeze が生成した認証ビュー（`resources/views/livewire/pages/auth/` 等）と `lang/ja.json` を実際に Read して確認すること。** 推測で書くと不一致による修正ループが発生する。
