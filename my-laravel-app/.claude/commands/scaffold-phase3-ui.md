---
description: フェーズ3 - Controller / View / Policy を生成し UI を完成させる
---

# Phase 3: UI（Controller / View / Policy）

`docs/screens.md` と `docs/api-spec.md` に従って画面と認可を構築する。ルーティング・エンドポイント・認可マトリクスは `docs/api-spec.md`、画面構成は `docs/screens.md` が一次情報。

## 実行順序

1. **ルーティング**: `docs/api-spec.md` の「全体構造」の通りに `routes/web.php` を記述。`Route::get('/', ...)` に対応する `HomeController::index()`（公開のランディングページ）もあわせて作成する
2. **レイアウト**: `layouts/app.blade.php`（メンバー用）と `layouts/admin.blade.php`（管理者用）を作成。ヘッダ / フッタ / サイドバーの構造は `docs/screens.md` の「レイアウト」セクション参照
3. **例外ハンドリング（`bootstrap/app.php`）**:
   - `withExceptions()` 内で `Illuminate\Auth\Access\AuthorizationException` を `render()` し、`flash('error', 'この操作を行う権限がありません。')` の上で `redirect()->route('home')` を返す（挙動は `@docs/architecture.md` の「認可エラーの挙動」参照）
4. **`EnsureUserIsAdmin` ミドルウェア**（`app/Http/Middleware/`）:
   - `$request->user()->isAdmin()` が false なら `flash('error', '管理者のみアクセスできます。')` の上で `redirect()->route('home')`
   - `bootstrap/app.php` の `withMiddleware()` で `admin` エイリアスとして登録
5. **メンバー領域・管理者領域の Controller / View**: `@docs/screens.md` の各領域の画面一覧と `@docs/api-spec.md` のルーティング定義から導出すること
6. **Policy**: `php artisan make:policy XxxPolicy --model=Xxx` でリソースごとに作成。認可ルールは `@docs/api-spec.md` の「認可マトリクス」通り。実装パターン（シングルトンリソースの Policy 直接呼び出し等）は `@docs/architecture.md` の「Policy」セクション参照
7. **Action クラス**: `@docs/architecture.md` の「Action 一覧」参照。各 Action の副作用は `@docs/api-spec.md` の「エンドポイント詳細」参照
8. **カスタムエラーページ**: `resources/views/errors/404.blade.php`, `419.blade.php`, `500.blade.php` を Tailwind スタイルに合わせて作成
9. **通知（メンバー向け）と監査ログ（管理者向け）画面**: `docs/screens.md` の画面一覧から導出

## 画面実装の注意

- **検索**: Spatie Query Builder（`QueryBuilder::for(Book::class)->allowedFilters([...])->allowedSorts([...])->paginate(25)`）を Livewire コンポーネントの `render()` 内で使う
  - 許可するフィルタ・ソートは `docs/db-schema.md` の「Spatie Query Builder 対応」セクション参照
- **ページネーション**: Laravel 標準の `->paginate(25)`。件数は `docs/screens.md` の通り 25 件/ページ
- **借用申請フォーム**: 通常の Blade `<form>` + `@csrf` で `route('lendings.store')` に POST する。`Route::post` 側は `StoreLendingRequest` で `book_id` / `note` をバリデーションする
- **Livewire**: サーバー往復を伴う動的処理（検索結果の絞り込み、状態フィルタ）に使う。`wire:model.live` で入力と同時に結果を更新する
- **削除確認**: Livewire コンポーネント内は `wire:confirm="削除しますか？"`。非 Livewire のフォームは Alpine.js で `x-on:submit="confirm('削除しますか？') || $event.preventDefault()"`
- **フラッシュ**: `layouts/app.blade.php` の上部で `session('status')` / `session('error')` を Tailwind の色で表示
- **エラー表示**: フォーム部分の Blade コンポーネントを作成し、`$errors->first('field')` を表示

## レイアウトのスタイル（実装ブレ防止のため明示）

Tailwind の最小構成。実装ブレを防ぐため以下に揃える:

- メンバー用ヘッダ: 白背景、影、ロゴ + ナビ
- 管理者用サイドバー: ダークグレー背景、リンク一覧
- カード: `bg-white rounded-lg shadow p-6`
- プライマリボタン: `bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700`
- 危険ボタン（削除等）: `bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700`
- フラッシュ status: `bg-green-50 text-green-800 border border-green-200 rounded p-3`
- フラッシュ error: `bg-red-50 text-red-800 border border-red-200 rounded p-3`

## Policy の書き方（実装ブレ防止のため例示）

リソース全体に共通する形式:

```php
class BookPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, Book $book): bool
    {
        return true;
    }

    public function create(User $user): bool
    {
        return $user->isAdmin();
    }

    public function update(User $user, Book $book): bool
    {
        return $user->isAdmin();
    }

    public function delete(User $user, Book $book): bool
    {
        return $user->isAdmin();
    }
}
```

Controller では各アクションで `$this->authorize('update', $book);` を呼ぶ。`index` アクションでは Laravel の Policy に Pundit の `Scope` 相当の仕組みがないため、絞り込みが必要なリソース（例: Lending は自分の貸出のみ）は Controller 内で明示的に分岐する:

```php
// 全件表示（BookController::index() 等）
$books = QueryBuilder::for(Book::class)->allowedFilters([...])->paginate(25);

// 絞り込みあり（LendingController::index() 等）
$lendings = $request->user()->isAdmin()
    ? Lending::query()
    : $request->user()->lendings();
$lendings = QueryBuilder::for($lendings)->allowedFilters([...])->paginate(25);
```

## Pint 自動修正

Action・Policy・Controller・Livewire コンポーネントの実装が完了したら自動修正可能な違反を解消する:

```sh
vendor/bin/pint app/Http app/Livewire app/Policies app/Actions tests
```

## テスト

### `tests/DuskTestCase.php` の設定（テストを書く前に必ず実施）

Laravel Dusk はブラウザを別プロセスで操作するため、DB トランザクションによるロールバック（`RefreshDatabase` 等）が効かない。`Illuminate\Foundation\Testing\DatabaseTruncation` トレイトを使い、テストごとに関連テーブルを truncate する:

```php
<?php

namespace Tests;

use Illuminate\Foundation\Testing\DatabaseTruncation;
use Laravel\Dusk\TestCase as BaseTestCase;

abstract class DuskTestCase extends BaseTestCase
{
    use DatabaseTruncation;

    // FK依存の逆順（順序の根拠は @docs/db-schema.md の「teardown削除順序」セクション参照）
    protected array $tablesToTruncate = [
        'audit_logs', 'notifications', 'lendings', 'book_tags', 'books', 'tags', 'categories', 'users',
    ];

    // ... driver() 等の既定実装 ...
}
```

### `signInAs` ヘルパー

Dusk でログイン後の画面操作を行う際、リダイレクト完了を待たずに次の操作を行うと断続的に失敗するテストになる。各テストクラスの `protected` メソッドとして以下を必ず含めること:

```php
protected function signInAs(Browser $browser, User $user): void
{
    $browser->visit('/login')
        ->type('email', $user->email)
        ->type('password', 'password123')
        ->press('ログイン') // 文言は docs/screens.md の注記に従い実ファイルを Read して確認
        ->waitForLocation('/'); // リダイレクト完了を待つ
}
```

### テストシナリオ

最低限のシステムテスト（Dusk）を書く。網羅すべき観点:

- ログインして蔵書一覧が表示できる
- 蔵書詳細から借用申請ができる
- 管理者が申請を承認できる
- 非 admin が `/admin` にアクセスすると `home` へリダイレクトされる（`error` フラッシュが表示される）

`php artisan dusk` で確認。

## このフェーズの完了基準

- [ ] `php artisan route:list` で `docs/api-spec.md` の全ルートが存在
- [ ] 各画面が（データなしでも）500 にならずに表示できる
- [ ] Policy が全リソースに存在
- [ ] レイアウト `layouts/app.blade.php` / `layouts/admin.blade.php` が存在
- [ ] `docs/architecture.md` の「Action 一覧」の 4 クラスが `app/Actions/` に存在
- [ ] `php artisan test` が all green
- [ ] `vendor/bin/pint --test` が違反 0

## やらないこと

- Seeder の投入（Phase 4 で実施）
- 本番デプロイ設定

## 完了後

`/verify` を実行し、結果を報告。
