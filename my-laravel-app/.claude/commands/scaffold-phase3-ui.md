---
description: フェーズ3 - Controller / View / Policy を生成し UI を完成させる
---

# Phase 3: UI（Controller / View / Policy）

`docs/screens.md` と `docs/api-spec.md` に従って画面と認可を構築する。ルーティング・エンドポイント・認可マトリクスは `docs/api-spec.md`、画面構成は `docs/screens.md` が一次情報。

## 実行順序

1. **ルーティング**: `docs/api-spec.md` の「全体構造」の通りに `routes/web.php` を記述。`Route::get('/', ...)` に対応する `HomeController::index()`（公開のランディングページ）もあわせて作成する
2. **Breeze 生成物の追従**（ルーティング置き換えの直後に行うこと。詳細は後述の「Breeze 生成物の追従」）
3. **基底 Controller に `AuthorizesRequests` を取り込む**（後述の「`$this->authorize()` を使う前提」）
4. **レイアウト**: `layouts/app.blade.php`（メンバー用）と `layouts/admin.blade.php`（管理者用）を作成。ヘッダ / フッタ / サイドバーの構造は `docs/screens.md` の「レイアウト」セクション参照

   > **管理レイアウトのログアウトに `route('logout')` を使わないこと。** Breeze（Livewire
   > スタック）はログアウトを名前付きルートではなく Volt のアクションとして提供するため、
   > **`logout` ルートは存在しない**（`docs/api-spec.md` の `routes/web.php` にも無い）。
   > POST フォームを `route('logout')` で組むと `Route [logout] not defined.` で 500 になる。
   > `layouts/admin.blade.php` は `<livewire:layout.navigation />` を持たないので、
   > `App\Livewire\Actions\Logout` を呼ぶ**小さな Livewire コンポーネント**をヘッダに置く
   > （詳細は `docs/screens.md` の管理レイアウトの注記）。`routes/web.php` に `logout` を
   > 足して解決してはならない。
5. **例外ハンドリング（`bootstrap/app.php`）**:
   - `withExceptions()` 内で認可エラーを `render()` し、`flash('error', 'この操作を行う権限がありません。')` の上で `redirect()->route('home')` を返す（挙動は `@docs/architecture.md` の「認可エラーの挙動」参照）
   - **コールバックの型は `Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException` にする**。`Illuminate\Auth\Access\AuthorizationException` を指定してはならない（後述の「認可エラーの render コールバック」）
6. **`EnsureUserIsAdmin` ミドルウェア**（`app/Http/Middleware/`）:
   - `$request->user()->isAdmin()` が false なら `flash('error', '管理者のみアクセスできます。')` の上で `redirect()->route('home')`
   - `bootstrap/app.php` の `withMiddleware()` で `admin` エイリアスとして登録
7. **メンバー領域・管理者領域の Controller / View**: `@docs/screens.md` の各領域の画面一覧と `@docs/api-spec.md` のルーティング定義から導出すること
8. **Policy**: `php artisan make:policy XxxPolicy --model=Xxx` でリソースごとに作成。認可ルールは `@docs/api-spec.md` の「認可マトリクス」通り。実装パターン（シングルトンリソースの Policy 直接呼び出し等）は `@docs/architecture.md` の「Policy」セクション参照
9. **Action クラス**: `@docs/architecture.md` の「Action 一覧」参照。各 Action の副作用は `@docs/api-spec.md` の「エンドポイント詳細」参照
10. **カスタムエラーページ**: `resources/views/errors/404.blade.php`, `419.blade.php`, `500.blade.php` を Tailwind スタイルに合わせて作成
11. **通知（メンバー向け）と監査ログ（管理者向け）画面**: `docs/screens.md` の画面一覧から導出

## Breeze 生成物の追従（ルーティング置き換えの直後に必須）

`docs/api-spec.md` の `routes/web.php` には Breeze が Phase 1 で追加する `dashboard` / `profile` の
2 ルートが**無い**。一方 Breeze の生成物はこの 2 つを参照しているため、仕様通りに置き換えるだけだと
`route('dashboard')` が `RouteNotFoundException` になり、**Phase 1 で green だった Breeze の
Feature テストが壊れる**。次を必ず行うこと。

1. `route('dashboard')` の参照を **`route('home')` に置き換える**（ログイン・登録・メール確認後の
   遷移先を `/` にする）。対象:
   - `resources/views/livewire/pages/auth/login.blade.php`
   - `resources/views/livewire/pages/auth/register.blade.php`
   - `resources/views/livewire/pages/auth/confirm-password.blade.php`
   - `resources/views/livewire/pages/auth/verify-email.blade.php`
   - `resources/views/livewire/layout/navigation.blade.php`
   - `app/Http/Controllers/Auth/VerifyEmailController.php`

   > **置換の手段**: `sed -i` による一括置換は Claude Code の Bash ツールが拒否する
   > （作業ディレクトリ内のファイルであっても `sed in '<path>' was blocked.` になる）。
   > `Edit` ツールでファイルごとに置換すること。同一ファイル内の複数箇所は
   > `replace_all` で一度に処理できる。

   > **補足**: `resources/views/livewire/profile/update-profile-information-form.blade.php` と
   > `resources/views/livewire/welcome/navigation.blade.php` も `dashboard` を参照するが、
   > どちらも手順 4 で削除するため置換は不要。置換対象を `grep -rn "dashboard" resources app`
   > で洗い出すと、この 2 つが「漏れ」に見えるので注意する。
2. Breeze の Feature テストの assert も同様に更新する:
   - `tests/Feature/Auth/AuthenticationTest.php`（`route('dashboard')` → `route('home')`、
     ナビ描画確認の `$this->get('/dashboard')` → 認証必須の任意の画面。例: `/books`）
   - `tests/Feature/Auth/RegistrationTest.php`
   - `tests/Feature/Auth/EmailVerificationTest.php`
   - `tests/Feature/Auth/PasswordConfirmationTest.php`（`assertRedirect('/dashboard')` → `'/'`）
3. プロフィール画面を仕様に合わせる:
   - Breeze の `Route::view('profile', 'profile')` を廃し、`GET /profile/edit`（`ProfileController@edit`）にする
   - name / email の更新は Breeze の Volt（`profile.update-profile-information-form`）ではなく
     仕様の `PATCH /profile`（`ProfileController@update` + `UpdateProfileRequest`）で行う。
     当該 Volt はどの画面からも参照されなくなるため、手順 4 で**削除する**
   - パスワード変更・退会の Volt コンポーネントは Breeze の生成物をそのまま `/profile/edit` に載せる
   - `tests/Feature/ProfileTest.php` をこの構成に合わせて書き換える
     （`assertSeeVolt('profile.update-profile-information-form')` の行は、当該 Volt を
     画面から外すため**削除する**。残すと `profile page is displayed` が失敗する）
4. 不要になったビューを削除する: `resources/views/dashboard.blade.php`,
   `resources/views/profile.blade.php`, `resources/views/welcome.blade.php`,
   `resources/views/livewire/welcome/`,
   `resources/views/livewire/profile/update-profile-information-form.blade.php`（手順 3 で
   画面から外れて未使用になるため。`resources/views/livewire/profile/` にはパスワード変更・
   退会の 2 つだけが残る）

   > 削除は `git clean -fdxq <path>` で行う（いずれも `laravel new` / `breeze:install` が
   > 生成した git 未追跡ファイルであり、追跡ファイルを巻き込む事故が起きない）。
   >
   > **パスはセッションのカレントディレクトリ基準で書くこと。** `my-laravel-app/` に
   > いる状態で `git clean -fdxq my-laravel-app/resources/views/...` と書くと
   > `my-laravel-app/my-laravel-app/...` を指し、
   > `warning: could not open directory 'my-laravel-app/my-laravel-app/'` が返って
   > **何も削除されない**（`prompts/trial-phase.md` の pathspec の注意も参照）。
5. `resources/views/livewire/layout/navigation.blade.php` のナビ項目を `docs/screens.md` の
   レイアウト（蔵書 / 自分の貸出 / 通知、管理者には管理）に差し替える

   > **重要（未ログイン時の nav）**: Breeze 生成の navigation は `auth()->user()->name` /
   > `auth()->user()->email` を**無条件に**参照する。Breeze の構成では nav を出す画面が
   > すべて認証必須だったため問題にならなかったが、本仕様では `GET /`（ランディング）が
   > 公開画面かつ `layouts/app.blade.php` を使うため、**未ログインで `/` を開くと
   > `Attempt to read property "name" on null` で 500 になる**。ユーザー名・ドロップダウン・
   > 各ナビ項目を `@auth` で囲み、`@guest` 側にはログイン / 新規登録へのリンクを置くこと。
6. **`tests/Browser/ExampleTest.php` を書き換える**: `dusk:install` が生成するこのテストは
   `visit('/')->assertSee('Laravel')` で **welcome ページの文言**を見に行く。手順 4 で
   `welcome.blade.php` を削除するため、そのままだと
   `Did not see expected text [Laravel] within element [body].` で `php artisan dusk` が落ちる。
   本プロジェクトのランディングに実在する文言（例: `BookKeeper`）へ差し替えること。

## `$this->authorize()` を使う前提

Laravel 11 以降の `app/Http/Controllers/Controller.php` は空の抽象クラスで、
`AuthorizesRequests` トレイトを持たない。`$this->authorize()` を呼ぶ前に取り込むこと:

```php
abstract class Controller
{
    use \Illuminate\Foundation\Auth\Access\AuthorizesRequests;
}
```

## 認可エラーの render コールバック

`bootstrap/app.php` の `withExceptions()` に登録する認可エラーのコールバックは
**`AccessDeniedHttpException` を型に取る**:

```php
$exceptions->render(function (AccessDeniedHttpException $e, Request $request) {
    if ($request->expectsJson()) {
        return null;
    }

    return redirect()->route('home')->with('error', 'この操作を行う権限がありません。');
});
```

`AuthorizationException` を型にすると**コールバックは決して呼ばれない**。Laravel の
`Handler::render()` は登録済みコールバック（`renderViaCallbacks()`）を実行する**前に**
`prepareException()` で `AuthorizationException` を `AccessDeniedHttpException` へ
変換するため。誤った型で書くとテストは 302 ではなく 403 を受け取って失敗する。

## 画面実装の注意

- **検索**: Spatie Query Builder（`QueryBuilder::for(Book::class)->allowedFilters(...)->allowedSorts(...)->paginate(25)`）を Livewire コンポーネントの `render()` 内で使う
  - 許可するフィルタ・ソートは `docs/db-schema.md` の「Spatie Query Builder 対応」セクション参照
  - **v7 の `allowedFilters()` / `allowedSorts()` は可変長引数のみ**を受け取る。配列渡し
    （`allowedFilters([...])`）は `TypeError: Argument #1 must be of type AllowedFilter|string, array given` になる
  - **Eager Load は `for()` に渡すクエリ側で指定する**（`QueryBuilder::for(Book::with(['category', 'tags']))`）。
    `QueryBuilder` に `->with()` を繋ぐと larastan が戻り値を `Eloquent\Builder` と推論し、
    後続の `allowedFilters()` を「未定義メソッド」と判定して `phpstan analyse` が落ちる
  - Livewire から使う場合、Spatie Query Builder はリクエストのクエリ文字列を読むため、
    コンポーネントの状態を `request()->merge(['filter' => [...]])` で渡してから `for()` を呼ぶ
- **ページネーション**: Laravel 標準の `->paginate(25)`。件数は `docs/screens.md` の通り 25 件/ページ

  > **一覧を Livewire コンポーネントに持たせた画面では、Controller 側に `paginate()` を
  > 置かないこと。** Livewire の `WithPagination` は `Paginator::currentPageResolver` を
  > 「コンポーネントの `$paginators` を読む」形へ差し替え、それが**同一テストプロセスの
  > 後続リクエストにも残る**。そのため Controller 側にも同じ一覧の `paginate()` があると、
  > 2 回目以降のリクエストで `?page=2` を渡しても**常に 1 ページ目が返る**
  > （画面は正常に見えるので、テストを書いて初めて気付く）。
  >
  > `docs/screens.md` がメンバーの蔵書一覧・貸出一覧を Livewire コンポーネントと
  > 定めているため、これらの Controller は `view('books.index')` を返すだけにする。
  > 検証方法は後述の「テストシナリオ」参照。
- **enum の画面表示**: `LendingState` / `NotificationKind` / `UserRole` の日本語表記は `docs/screens.md` の「enum の表示ラベル」表が一次情報。**各 Enum クラスに `label(): string` を実装し、ビューからは `{{ $lending->state->label() }}` で参照する**。Blade 側に `@if` の連鎖や配列マッピングを書かない（`team-rules/coding-standards.md` の「Blade に複雑な `@if` の連鎖を書かない」に従う）

  > **enum の値そのものを Blade で比較しないこと。** 「返却ボタンを出すか」「承認・却下を
  > 出すか」の判定を `@if (in_array($lending->state, [App\Enums\LendingState::Approved, ...]))`
  > と書くと、Blade に enum クラスの完全修飾名が散る。`Lending` に `isReturnable()` /
  > `isRequested()` のような述語メソッドを置き、ビューからは `@if ($lending->isReturnable())`
  > で参照する（`team-rules/coding-standards.md` の「真偽値を返すメソッドは is / has / can」）。
- **借用申請フォーム**: 通常の Blade `<form>` + `@csrf` で `route('lendings.store')` に POST する。`Route::post` 側は `StoreLendingRequest` で `book_id` / `note` をバリデーションする
- **Livewire**: サーバー往復を伴う動的処理（検索結果の絞り込み、状態フィルタ）に使う。`wire:model.live` で入力と同時に結果を更新する
  - **`wire:model` の入力欄には `id` を付け、Dusk からは `#id` セレクタで指定すること。** Dusk の
    `type('title', ...)` のような**名前指定は `name` 属性を前提**にしているが、Livewire の入力欄は
    `wire:model` でバインドするため `name` を書かないのが普通で、
    `no such element: {"method":"css selector","selector":"body title"}` で落ちる
    （Breeze 生成のログインフォームは `name` を持つので `type('email', ...)` が通る。この違いが
    紛らわしい）。検索欄を `<input id="title" wire:model.live="title">` とし、テスト側は
    `->type('#title', 'Ruby')` と書く
  - **選択肢（カテゴリ・タグの一覧など）は `render()` から view へ渡すこと。** Blade 内で
    `\App\Models\Category::orderBy(...)->get()` と書かない（`team-rules/coding-standards.md` の
    「ビジネスロジックは Model か Action / Service クラスに置く」に反する）
- **削除確認**: Livewire コンポーネント内は `wire:confirm="削除しますか？"`。非 Livewire のフォームは Alpine.js で `<form x-data x-on:submit="confirm('削除しますか？') || $event.preventDefault()">`。**`x-data`（空でよい）を必ず付けること**。Alpine v3 は `x-data` スコープ内の要素しか `x-on:` ディレクティブを処理しないため、`x-data` の無い素の `<form x-on:submit>` は**エラーも出さず無視され、確認なしで削除・却下・返却が実行される**。これは `livewire.js` が読み込まれ Alpine が起動していても起きる（Alpine 読み込みの有無とは別問題。詳細は `docs/stack.md` の Alpine の項参照）。ナビの `x-data="{ open: false }"` は nav にスコープされるため外側のフォームには効かない
- **削除失敗（`restrictOnDelete`）の扱い**: 貸出履歴のある書籍・ユーザー、書籍が紐づくカテゴリの `destroy` は、削除前に `exists()` で関連の有無を事前チェックし、あれば `back()->with('error', ...)` で戻す。**`try/catch (QueryException)` で書くと larastan が Dead catch で落とす**。実装パターンと固定のフラッシュ文言は `docs/db-schema.md` の「削除不可の画面挙動」参照
- **フラッシュ**: `layouts/app.blade.php` の上部で `session('status')` / `session('error')` を Tailwind の色で表示
- **エラー表示**: フォーム部分の Blade コンポーネントを作成し、`$errors->first('field')` を表示
- **管理者レイアウトのコンポーネント登録**: Breeze は `x-app-layout` / `x-guest-layout` を
  **クラスコンポーネント**（`app/View/Components/AppLayout.php` / `GuestLayout.php`）として提供している。
  `x-admin-layout` を使うには `app/View/Components/AdminLayout.php` を同じ形で作ること
  （`resources/views/layouts/admin.blade.php` を置くだけでは解決されない）
- **`layouts/admin.blade.php` には `@livewireScripts` を明示的に書くこと**。Livewire v3 は
  **そのページが Livewire コンポーネントを実際に描画したときだけ** `livewire.js`（Alpine を
  同梱する）を注入する。管理レイアウトを使う画面には Livewire コンポーネントを持たないもの
  （蔵書一覧・カテゴリ・タグ）があり、そこでは **Alpine が読み込まれず `x-on:submit` の
  削除確認ダイアログがエラーも出さずに無効化される**（確認なしで削除が実行される）。
  `resources/js/app.js` は `laravel new` の生成物では実質空で Alpine を import していないため、
  この経路での補完も効かない。`layouts/app.blade.php` は `<livewire:layout.navigation />` を
  含むため自動注入が働き、この問題は起きない。詳細は `docs/stack.md` の Alpine の項参照
  （ただし Alpine が読み込まれても、前述のとおりフォーム側に `x-data` が無ければ発火しない。
  両方を満たすこと）
- **フォームの部分ビュー（`_form.blade.php` 等）に `@props` を使わないこと**。`@props` は
  Blade コンポーネント（`x-` 記法で解決されるもの）専用のディレクティブで、`@include` した
  ビューでは機能しない。既定値が要る変数は `@php($book = $book ?? null)` のように書く

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

`make:policy --model=` が生成する雛形には `restore` / `forceDelete` も含まれるが、
ソフトデリートを使わない本プロジェクトでは削除してよい。承認・却下のように
CRUD に対応しないアビリティ（`approve` / `reject`）は Policy にメソッドを足し、
Controller から `$this->authorize('approve', $lending)` で呼ぶ。返却（`returnBook`）も
同様に Policy のアビリティとして定義する（本人のみ許可）。

> **未公開書籍（`published = false`）の非表示は Policy で表現しないこと。** `docs/screens.md`
> はメンバーに **404 を返す**と定めており、Policy の `view` を false にすると認可エラーの
> ハンドリング（`home` へリダイレクト + `error` フラッシュ）に流れて **404 にならない**。
> `BookPolicy::view()` は `true` のままにし、`BookController::show()` で
> `if (! $book->published && ! $request->user()->isAdmin()) { throw new NotFoundHttpException; }`
> のように存在判定として扱う。

Controller では各アクションで `$this->authorize('update', $book);` を呼ぶ。`index` アクションでは Laravel の Policy に Pundit の `Scope` 相当の仕組みがないため、絞り込みが必要なリソース（例: Lending は自分の貸出のみ）は Controller 内で明示的に分岐する:

```php
// 全件表示（BookController::index() 等）
$books = QueryBuilder::for(Book::class)->allowedFilters(...)->paginate(25);

// 絞り込みあり（LendingController::index() 等）
$lendings = $request->user()->isAdmin()
    ? Lending::query()
    : $request->user()->lendings();
$lendings = QueryBuilder::for($lendings)->allowedFilters(...)->paginate(25);
```

> **注意（独自 Notification の取得）**: `User::notifications()` は Breeze が付与する
> `Notifiable` トレイトの Laravel 標準通知リレーションであり、本プロジェクトの
> `App\Models\Notification` ではない（`docs/db-schema.md` の注記参照）。
> 自分の通知一覧は `Notification::where('user_id', $request->user()->id)` で取得する。

## Pint 自動修正

Action・Policy・Controller・Livewire コンポーネントの実装が完了したら自動修正可能な違反を解消する:

```sh
vendor/bin/pint
```

**パスを列挙して渡さないこと。** 触ったディレクトリを書き漏らす（Phase 3 のトライアルで
`app/Models` が漏れた）うえ、`bootstrap` を明示指定すると、**引数なしなら除外される
`bootstrap/cache/*.php`**（Laravel が生成するキャッシュ）まで整形対象に入る。

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

### `.env.dusk.local` の作成

Dusk は `.env.dusk.local` があればそれを読む。無いと `.env` がそのまま使われ、
`DatabaseTruncation` が**開発用の `bookkeeper` データベースを truncate してしまう**。
`.env` をコピーして `DB_DATABASE=bookkeeper_test` に変えたものを置くこと
（`.gitignore` の `/.env.*` により追跡対象外になる）。

### Dusk 実行時の前提

- **`php artisan serve --env=dusk.local`** で `APP_URL`（`http://localhost:8000`）が応答して
  いること。Dusk は自前でサーバーを起動しない

  > **`--env=dusk.local` を必ず付けること。** 素の `php artisan serve` は `.env`
  > （開発用の `bookkeeper`）を読むため、`.env.dusk.local`（`bookkeeper_test`）で
  > truncate / seed する**テストプロセスとブラウザが叩くサーバーとで DB が食い違う**。
  > テストが用意したデータが画面に出ず、`waitForText` 等が軒並みタイムアウトする
  > （データが無いだけなので、原因が分かりにくい形で落ちる）。
- ChromeDriver がホストの Chrome とバージョン一致していること。ずれている場合は
  `php artisan dusk:chrome-driver --detect`（Phase 1 手順書参照）
- 非 TTY 環境では `Warning: TTY mode requires /dev/tty to be read/writable.` が出るが
  処理は継続するので無視してよい

### `signInAs` ヘルパー

Dusk でログイン後の画面操作を行う際、リダイレクト完了を待たずに次の操作を行うと断続的に失敗するテストになる。次のヘルパーを用意すること。

> **置き場所は `tests/Pest.php` の「Functions」節**（`laravel new --pest` が生成する
> コメントブロックのある箇所）。**各 Dusk テストファイルに同じ関数を書いてはならない。**
> Pest はテストファイルをすべて読み込むため、2 つ以上のファイルで同じ関数を宣言すると
> ```
> Fatal error: Cannot redeclare function signInAs() (previously declared in
> .../tests/Browser/AdminBookCrudTest.php:9) in .../tests/Browser/LendingFlowTest.php on line 15
> ```
> で `php artisan dusk` 全体が起動すらしなくなる。Dusk のテストファイルは Phase 4 で
> 複数になる（借用フロー・返却・書籍 CRUD）ため、最初から共有の置き場に書くこと。

```php
// tests/Pest.php の「Functions」節
function signInAs(Browser $browser, User $user): void
{
    $browser->logout() // 前テストのセッションを必ず切る（下記の注意参照）
        ->visit('/login')
        ->waitUntil('window.Livewire') // ハイドレーション完了を待つ（下記の注意参照）
        ->waitForInput('email')
        ->type('email', $user->email)
        ->type('password', 'password123')
        ->press('ログイン') // 文言は docs/screens.md の注記に従い実ファイルを Read して確認
        ->waitForLocation('/'); // リダイレクト完了を待つ
}

/** signInAs が使う password123 を設定済みのユーザーを作る */
function makeUser(bool $admin = false): User
{
    $factory = User::factory();

    if ($admin) {
        $factory = $factory->admin();
    }

    return $factory->create(['password' => Hash::make('password123')]);
}
```

`tests/Pest.php` の冒頭に `use App\Models\User;` / `use Illuminate\Support\Facades\Hash;` /
`use Laravel\Dusk\Browser;` を足すこと。

> **重要（先頭の `logout()` は省略不可）**: Dusk はブラウザインスタンスをテスト間で再利用する。
> 前のテストのログインセッションが残ったまま `/login` を開くと認証済みとしてリダイレクトされ、
> `email` 入力欄が存在しないため
> `no such element: Unable to locate element: {"method":"css selector","selector":"body email"}`
> で落ちる。単体で走らせると通り、まとめて走らせると落ちるため原因を掴みにくい。

> **補足（パスワード）**: `UserFactory` の既定パスワードは `password` である。
> `signInAs` が `password123` を使うため、上記 `makeUser()` のように
> `User::factory()->create(['password' => Hash::make('password123')])` と明示すること。

> **重要（`waitUntil('window.Livewire')` は省略不可）**: Breeze のログインフォームは
> Livewire コンポーネントである。`livewire.js` のロード前に `press('ログイン')` すると
> **Livewire のハンドラではなくネイティブ submit** が走り、action 属性の無いフォームが
> 空の値で `/login` にリロードされる。結果 `waitForLocation('/')` が
> `Waited 5 seconds for location [/].` でタイムアウトする（失敗時のスクリーンショットは
> **入力欄が空のログイン画面**になる）。テストが数件のうちは偶然通ってしまい、
> **Phase 4 で Dusk が増えると実行ごとに別のテストが落ちるフレーキーな症状**として
> 顕在化するため、最初から入れておくこと。

### Livewire で一覧が絞り込まれるのを待つ

**絞り込みの結果「件数が減る」ことを検証するときは、`waitUntilMissingText()` で
消える側を待つこと。** 残る側を `waitForText()` してから `assertDontSee()` を書くと落ちる:

```php
// NG: 「プロを目指す人のためのRuby入門」は入力前から表示されているため
//     waitForText が即座に通り、Livewire の再描画を待たずに assertDontSee へ進む
$browser->waitForText('こころ')
    ->type('#title', 'Ruby')
    ->waitForText('プロを目指す人のためのRuby入門')
    ->assertDontSee('こころ');   // Saw unexpected text [こころ] within element [body].

// OK: 消える側を待てば再描画の完了が保証される
$browser->waitForText('こころ')
    ->type('#title', 'Ruby')
    ->waitUntilMissingText('こころ')
    ->assertSee('プロを目指す人のためのRuby入門');
```

`wire:model.live` は入力のたびにサーバーへ往復するため、`type()` の直後は**まだ絞り込み前の
一覧が描画されている**。「絞り込み後も残る要素」を待機条件にすると、待機が成立した時点が
絞り込み前なのか後なのか区別できない。**待機条件は必ず「操作によって状態が変わる側」に置く**
（これは削除確認の `waitForText('書籍を削除しました')` が効く理由と同じ原則）。

### confirm ダイアログを伴う操作

削除ボタンのように `confirm()` を挟む操作は、`acceptDialog()` の**前に
`waitForDialog()` を挟む**こと。`press()` はクリック直後に戻るため、
ダイアログ生成前に `acceptDialog()` を呼ぶと `no such alert` で落ちる。

また、`press()` の**前に `waitUntil('window.Alpine')` を挟む**こと。確認ダイアログは
Alpine の `x-on:submit` が発火させるため、Alpine のロード前に押すと素通りする。

```php
$browser->waitUntil('window.Alpine') // Alpine のロードを待ってから押す
    ->press('削除')
    ->waitForDialog()
    ->acceptDialog()
    ->waitForText('書籍を削除しました');
```

なお、ダイアログがそもそも出ず `waitForDialog()` が
`Waited 5 seconds for dialog.` で落ちる場合、原因は 3 つある。順に確認すること:

1. **フォームに `x-data` が無い**（`livewire.js` は読み込まれているのにダイアログが出ない
   場合はこれ）。Alpine v3 は `x-data` スコープ内の要素しか `x-on:` を処理しないため、
   `<form x-on:submit="confirm(...)">` は `x-data` が無いと発火しない。`<form x-data
   x-on:submit="...">` にする（「画面実装の注意」の削除確認の項参照）。`layouts/app.blade.php`
   を使うメンバー画面（返却フォーム等）でも起きる
2. **そもそも Alpine が読み込まれていない**（管理画面で顕著）。「画面実装の注意」の
   `@livewireScripts` の項を確認すること
3. **1・2 を満たしているが、ハイドレーション完了前に `press()` している**。`x-data` があり
   `@livewireScripts` もあるのに落ちる場合はこれ。上記のとおり `press()` の前に
   `waitUntil('window.Alpine')` を挟む。**実行するたびに落ちるテストが変わる**場合は
   まずこれを疑うこと（1・2 が原因なら毎回同じ箇所で落ちる）

### テストシナリオ

最低限のシステムテスト（Dusk）を書く。網羅すべき観点:

- ログインして蔵書一覧が表示できる
- 蔵書詳細から借用申請ができる
- 管理者が申請を承認できる
- 非 admin が `/admin` にアクセスすると `home` へリダイレクトされる（`error` フラッシュが表示される）

> `Book::factory()` の既定は在庫満杯（Phase 2 手順書の「ファクトリ」節参照）のため、
> `Lending::factory()` が連鎖生成した書籍はそのまま承認できる。逆に在庫切れ（承認失敗）を
> 検証するテストでは `Book::factory()->outOfStock()` を明示すること。

> **返却を検証するテストは、Dusk でも Feature でも「1 冊消費済み」の書籍を用意すること。**
> `Lending::factory()->approved()` / `->overdue()` は **state を設定するだけで
> `available_copies` を減らさない**。ファクトリの既定は在庫満杯なので、そのまま返却させると
> `ReturnLendingAction` の `increment('available_copies')` が `total_copies` を超え、
> CHECK 制約 `books_available_lte_total` に違反する。
>
> ```php
> $book = Book::factory()->create(['total_copies' => 2, 'available_copies' => 1]);
> $lending = Lending::factory()->approved()->create(['book_id' => $book->id]);
> ```
>
> **`QueryException` は Action の `catch (DomainException)` に掛からず 500 になるため、
> テストからは「state が Approved のまま変わらない」という形でしか見えない**
> （`Failed asserting that two variables reference the same object.` で、在庫制約が原因だと
> 分かりにくい）。Phase 4 の Dusk だけでなく、本フェーズの Feature テストでも同じ罠を踏む。

`php artisan dusk` で確認する。**green になったことを「待機条件が正しい」ことの証明に
しないこと**（ハイドレーション待ちの漏れはサーバーが速く返れば通ってしまう）。待機の
書き方は前掲「Livewire で一覧が絞り込まれるのを待つ」の原則で担保する。

あわせて Feature テスト（`php artisan test`）でも
主要フロー（借用申請の業務ルール、認可、ロール変更、通知の既読化、返却、**ページネーション**）を押さえること。

> **ページネーションは件数を assert して検証すること。** `paginate(25)` を書き忘れて全件表示に
> なっていても、1 ページ目に 25 件以上並ぶだけで**画面は正常に見え、テストも通ってしまう**。
> 26 件以上の書籍を作って検証する。
>
> **検証の書き方は「その一覧を誰が解決しているか」で変わる。**
>
> **(a) 一覧が Livewire コンポーネントの画面**（メンバーの蔵書一覧・貸出一覧）。
> Controller は `view(...)` を返すだけで `books` を渡さないため、`assertViewHas` を
> `$this->get('/books')` に対して書いても**取れない**。コンポーネントを直接テストする:
>
> ```php
> Book::factory()->count(30)->create(['published' => true]);
> $this->actingAs($member);
>
> Livewire::test(BookSearch::class)
>     ->assertViewHas('books', fn ($books) => $books->count() === 25 && $books->total() === 30)
>     ->call('gotoPage', 2)
>     ->assertViewHas('books', fn ($books) => $books->count() === 5);
> ```
>
> **(b) Controller が一覧を解決する画面**（管理画面の蔵書一覧など、Livewire を持たないもの）:
>
> ```php
> Book::factory()->count(30)->create();
>
> $this->actingAs($admin)->get('/admin/books')
>     ->assertOk()
>     ->assertViewHas('books', fn ($books) => $books->count() === 25);
>
> $this->actingAs($admin)->get('/admin/books?page=2')
>     ->assertOk()
>     ->assertViewHas('books', fn ($books) => $books->count() === 5);
> ```
>
> **(a) の画面で「Controller にも paginate を置いて `assertViewHas` で書く」ことはできない。**
> Livewire の `WithPagination` が差し替えた `Paginator::currentPageResolver` が同一
> テストプロセスの後続リクエストへ残り、Controller 側の `paginate()` が `?page=2` でも
> **1 ページ目を返す**ため、`currentPage()` が 1 のまま `count() === 5` が落ちる
> （「画面実装の注意」のページネーションの項も参照）。
>
> **Livewire コンポーネントには `WithPagination` トレイトを付けること。** 付け忘れると、
> 2 ページ目を開いた状態で検索条件を変えたときに**ページ番号がリセットされず「該当なし」に
> なる**。この不具合は 1 ページ目しか見ないテストでは検出できないため、
> `Livewire::test(BookSearch::class)->call('gotoPage', 2)->set('title', ...)` のように
> ページ送り後の絞り込みも 1 件検証しておく。

**各画面がデータなしでも 200 を返すことを確認する Feature テスト**（完了基準の
「各画面が（データなしでも）500 にならずに表示できる」に対応）も書いておくと、
Blade 側の null 参照を Dusk より早く・安く検出できる。

> **「データありの詳細画面」も併せて 1 件ずつ叩くこと。** データなしの一覧は Blade の
> `@if ($items->isEmpty())` 側しか通らず、**行を描画する分岐が一度も実行されない**。
> `$log->created_at?->format(...)` のような null 参照は、レコードが 1 件ある状態で
> 初めて踏む。

## 観測可能な振る舞いは assert で固定する

`docs/` が**外から見える具体値**を定めている箇所は、**その値を直接検証する assert** をテストに
含めること。実装が仕様と違っていても、**実装に合わせて書いたテストは green になる**ため、
これが無いと仕様違反を検出する手段が無くなる（`php artisan test` も `dusk` も pint も phpstan も
通ってしまう）。

対象と assert の例:

| `docs/` の定め | 書くべき assert |
|---|---|
| 未公開書籍の詳細は **404**（`docs/screens.md`） | `$this->get(...)->assertNotFound()` |
| 認可エラーは `home` へリダイレクト（`docs/architecture.md`） | `assertRedirect(route('home'))` |
| フラッシュ文言の固定値（同上の表） | `assertSessionHas('error', 'この操作を行う権限がありません。')` |
| 削除不可時の文言（`docs/db-schema.md`） | `assertSessionHas('error', '貸出履歴があるため削除できません。')` |
| ボタン・ラベルの固定値（`docs/screens.md`） | `assertSee('借用を申請')` / Dusk の `press('承認')` |
| 一覧は **25 件/ページ**（`docs/screens.md`） | 26 件以上を作り、上記 (a) / (b) の形で 1 ページ目・2 ページ目の件数を検証 |

**「メンバーには見えない」「削除できない」といった結果の粒度で満足しないこと。** ステータス
コードや文言まで一致させて初めて、仕様どおりの実装だと言える。

## このフェーズの完了基準

まず `bin/check-repo.sh` を実行する（`.env` と `.env.example` の整合・生成物の
`.gitignore` 除外・テンプレート同梱ファイルの変更有無を 1 回で検査する。読み取りのみ）。
終了コード 0 を確認してから、以下の残りの項目を確認する。


- [ ] `php artisan route:list` で `docs/api-spec.md` の全ルートが存在
- [ ] 各画面が（データなしでも）500 にならずに表示できる
- [ ] 未ログインで `GET /` が 200（nav の `@auth` ガード漏れがない）
- [ ] Policy が全リソースに存在
- [ ] レイアウト `layouts/app.blade.php` / `layouts/admin.blade.php` が存在し、`x-admin-layout` が解決できる
- [ ] `layouts/admin.blade.php` に `@livewireScripts` があり、管理画面の削除確認ダイアログが実際に出る
- [ ] `docs/architecture.md` の「Action 一覧」の 4 クラスが `app/Actions/` に存在
- [ ] Breeze 生成物の `dashboard` / `profile` 参照が仕様に追従済み（`route('dashboard')` が残っていない）
- [ ] **`docs/` が定める観測可能な振る舞いに、対応する assert が存在する**（下記）
- [ ] メンバー蔵書一覧のページネーションが `Livewire::test()` で検証済み（`assertViewHas` を
      `$this->get('/books')` に対して書いていない）
- [ ] `php artisan test` が all green（Phase 1 の Breeze 認証テストを含む）
- [ ] `php artisan dusk` が all green（`tests/Browser/ExampleTest.php` の書き換えを含む）
- [ ] **Dusk が次の 3 つを実際にブラウザで検証している**（`php artisan dusk` が green なだけでは足りない）
  - [ ] **蔵書一覧の検索・絞り込み**（Livewire の再描画を待つ。本ファイルの
        「Livewire で一覧が絞り込まれるのを待つ」節と `wire:model` の `id` の注意を参照）
  - [ ] **管理画面の削除確認ダイアログ**（`x-data` と `@livewireScripts` が両方無いと
        確認なしで削除が走る。`docs/stack.md` の Alpine の項を参照）
  - [ ] **貸出フローの 4 ボタン**（`借用を申請` / `返却` / `承認` / `却下` を `press()` で叩く。
        文言は `docs/screens.md` の表が一次情報）

  > **この 3 つを名指しするのは、書かなければ罠を踏まずに済んでしまうため。** 2026-08-06 の
  > Phase 1〜3 トライアルは Dusk 6 件で完了基準を満たしたが、報告の「今回参照しなかった
  > 注意書き」3 件がすべて「該当する Dusk テストを書かなかったので踏まなかった」だった。
  > **手順書が積み上げてきた罠の記述が、テストを書かないことで丸ごと迂回された。**
  > 上の 3 つはいずれも過去のトライアルで実際に踏んで記録された事象であり、
  > 検証されないまま Phase 4 へ進むと同じ失敗が再現する。
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse --memory-limit=512M` がエラー 0

## やらないこと

- Seeder の投入（Phase 4 で実施）
- 本番デプロイ設定

## 完了後

`/verify` を実行し、結果を報告。
