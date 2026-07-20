# ルーティング仕様

`routes/web.php` に展開する想定の宣言的仕様。

## 全体構造

```php
require __DIR__.'/auth.php'; // Laravel Breeze が生成する認証ルート群（login / register / forgot-password 等）

Route::get('/', [HomeController::class, 'index'])->name('home');

Route::middleware('auth')->group(function () {
    Route::get('/books', [BookController::class, 'index'])->name('books.index');
    Route::get('/books/{book}', [BookController::class, 'show'])->name('books.show');

    Route::get('/lendings', [LendingController::class, 'index'])->name('lendings.index');
    Route::post('/lendings', [LendingController::class, 'store'])->name('lendings.store');
    Route::get('/lendings/{lending}', [LendingController::class, 'show'])->name('lendings.show');
    Route::patch('/lendings/{lending}/return', [LendingController::class, 'returnBook'])->name('lendings.return');

    Route::get('/notifications', [NotificationController::class, 'index'])->name('notifications.index');
    Route::patch('/notifications/{notification}/read', [NotificationController::class, 'read'])->name('notifications.read');

    Route::get('/profile/edit', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');

    Route::prefix('admin')->name('admin.')->middleware('admin')->group(function () {
        Route::get('/', [Admin\DashboardController::class, 'index'])->name('dashboard');

        Route::get('/users', [Admin\UserController::class, 'index'])->name('users.index');
        Route::get('/users/{user}', [Admin\UserController::class, 'show'])->name('users.show');
        Route::patch('/users/{user}', [Admin\UserController::class, 'update'])->name('users.update');

        // カテゴリ・タグは作成・編集フォームを一覧画面内に置くため create / edit 画面を持たない
        Route::resource('categories', Admin\CategoryController::class)->only(['index', 'store', 'update', 'destroy']);
        Route::resource('tags', Admin\TagController::class)->only(['index', 'store', 'update', 'destroy']);
        Route::resource('books', Admin\BookController::class)->except(['show']);

        Route::get('/lendings', [Admin\LendingController::class, 'index'])->name('lendings.index');
        Route::get('/lendings/{lending}', [Admin\LendingController::class, 'show'])->name('lendings.show');
        Route::patch('/lendings/{lending}/approve', [Admin\LendingController::class, 'approve'])->name('lendings.approve');
        Route::patch('/lendings/{lending}/reject', [Admin\LendingController::class, 'reject'])->name('lendings.reject');

        Route::get('/audit-logs', [Admin\AuditLogController::class, 'index'])->name('audit-logs.index');
    });
});
```

> `return` は PHP の予約語のためメソッド名に使えない。貸出の返却アクションは `LendingController::returnBook()` として定義し、ルートのパス自体は仕様通り `/lendings/{lending}/return` とする。

> **重要（Breeze 生成物との差分）**: 上記の `routes/web.php` は Laravel Breeze が Phase 1 で生成する `dashboard` / `profile` の 2 ルートを**持たない**。Breeze の生成物はこの 2 つを前提にしているため、Phase 3 では次の追従が必須になる（放置すると `route('dashboard')` が `RouteNotFoundException` になり、Phase 1 で green だった Breeze の Feature テストが壊れる）。
>
> - `route('dashboard')` を参照する Breeze 生成物（`resources/views/livewire/pages/auth/*.blade.php`、`resources/views/livewire/layout/navigation.blade.php`、`app/Http/Controllers/Auth/VerifyEmailController.php`）を **`route('home')` に置き換える**。ログイン・登録・メール確認後の遷移先は `/` とする
> - Breeze の Feature テスト（`tests/Feature/Auth/AuthenticationTest.php`・`RegistrationTest.php`・`EmailVerificationTest.php`・`PasswordConfirmationTest.php`）の `dashboard` / `/dashboard` への assert も同様に `home` / `/` へ更新する
> - プロフィール画面は Breeze の `Route::view('profile', 'profile')` を廃し、本仕様の `GET /profile/edit`（`ProfileController@edit`）に置き換える。name / email の更新は Breeze の `profile.update-profile-information-form`（Volt）ではなく本仕様の `PATCH /profile` で行い、`tests/Feature/ProfileTest.php` をそれに合わせて書き換える。パスワード変更・退会の Volt コンポーネントは Breeze の生成物をそのまま `/profile/edit` に載せる
> - 不要になった `resources/views/dashboard.blade.php` / `profile.blade.php` / `welcome.blade.php`、および画面から外れて未使用になる `resources/views/livewire/profile/update-profile-information-form.blade.php` は削除する

## エンドポイント詳細

### `POST /lendings`

- 認証: 要ログイン
- パラメータ: `book_id`, `note`（`StoreLendingRequest` でバリデーション）
- 成功時: `redirect()->route('lendings.show', $lending)->with('status', '借用申請を送信しました')`
- 失敗時: 422、書籍詳細にフォーム付きで再描画（Livewire コンポーネントの場合はコンポーネント内でエラー表示）。業務ルール違反（在庫切れ・申請重複）は例外ではなく `ActionResult` の失敗として返し、`back()->with('error', ...)` で書籍詳細に戻す
- 実装: `RequestLendingAction` で実装。リダイレクト先の組み立てに作成した `Lending` が要るため、`ActionResult::$resource` に載せて返す（`docs/architecture.md` の Action セクション参照）
- 業務ルール:
  - 在庫 1 以上必須
  - 同一ユーザー × 同一書籍の active な lending（Requested / Approved / Overdue）が既にある場合は不可

### `PATCH /admin/lendings/{lending}/approve`

- 認証: 要 admin
- 副作用: state を `Approved`、`approved_at` 設定、`due_on = 14 日後`、`books.available_copies -= 1`、通知作成
- すべて 1 トランザクション内（`ApproveLendingAction` で実装）

### `PATCH /lendings/{lending}/return`（メンバー）

- Controller アクション名: `returnBook`（`return` は PHP 予約語のため `Route::patch(..., 'returnBook')` で定義）
- 認証: 要ログイン、本人のみ
- 副作用: state を `Returned`、`returned_at` 設定、`books.available_copies += 1`
- 実装: `ReturnLendingAction` で実装

### `PATCH /admin/lendings/{lending}/reject`

- 認証: 要 admin
- 副作用: state を `Rejected`、通知作成
- 実装: `RejectLendingAction` で実装

### `PATCH /notifications/{notification}/read`

- 認証: 要ログイン、本人のみ
- 副作用: `read_at = now()` を設定する
- 成功時: `redirect()->route('notifications.index')->with('status', '既読にしました')`
- 失敗時: 422

## 認可マトリクス

| リソース | member | admin |
|---|---|---|
| 蔵書 read | ✓ | ✓ |
| 蔵書 write | ✗ | ✓ |
| 自分の貸出 read | ✓ | ✓ |
| 他人の貸出 read | ✗ | ✓ |
| 申請承認/却下 | ✗ | ✓ |
| カテゴリ/タグ CRUD | ✗ | ✓ |
| ユーザー管理 | ✗ | ✓ |
| 監査ログ閲覧 | ✗ | ✓ |
| 通知閲覧・既読化 | 本人のみ | ✓ |
| プロフィール編集 | 本人のみ | ✓ |
