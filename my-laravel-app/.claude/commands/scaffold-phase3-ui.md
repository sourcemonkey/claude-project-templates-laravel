---
description: フェーズ3 - Controller / View / Policy を生成し UI を完成させる
---

# Phase 3: UI（Controller / View / Policy）

`docs/screens.md` と `docs/api-spec.md` に従って画面と認可を構築する。ルーティング・エンドポイント・認可マトリクスは `docs/api-spec.md`、画面構成は `docs/screens.md` が一次情報。

> **着手前に `docs/architecture.md` を Read すること。** レイヤの責務・`ActionResult` の形・
> 認可エラーの挙動・Policy の書き方が一次情報だが、`CLAUDE.md` から `@` 参照していないため
> 自動では文脈に入っていない。

> **実行場所**: 本手順書のコマンドは、断りが無い限りすべて **`my-laravel-app/` をカレント**として
> 書かれている。Bash ツールのカレントは呼び出しをまたいで持続するので、**最初に一度だけ**
> `cd my-laravel-app` し、以降は移動しない（ルートにも別物の `bin/` があり、そこから
> `bin/check-repo.sh` を打つと `exit 127` になる）。

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
5. **例外ハンドリング（`bootstrap/app.php`）**: `withExceptions()` 内で認可エラーを `render()` し、`flash('error', ...)` の上で `redirect()->route('home')` を返す（挙動と文言は `@docs/architecture.md` の「認可エラーの挙動」）。**コールバックの型**は後述の「認可エラーの render コールバック」に従うこと（誤った型を書くとコールバックが呼ばれない）
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
- **`layouts/admin.blade.php` には `@livewireScripts` を明示的に書くこと**。管理レイアウトを
  使う画面には Livewire コンポーネントを持たないもの（蔵書一覧・カテゴリ・タグ）があり、
  そこでは `livewire.js` が注入されず **Alpine が読み込まれないまま削除確認ダイアログが
  エラーも出さずに無効化される**（確認なしで削除が実行される）。詳細は `docs/stack.md` の
  Alpine の項参照。**`@livewireScripts` と `x-data` は両方必要**で、片方だけでは発火しない
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

**パスを列挙して渡さないこと。** 触ったディレクトリを書き漏らすうえ、`bootstrap` を明示指定すると、**引数なしなら除外される
`bootstrap/cache/*.php`**（Laravel が生成するキャッシュ）まで整形対象に入る。

## このフェーズの完了基準

まず `bin/check-repo.sh`（読み取りのみ）を実行し、終了コード 0 を確認してから以下を確認する。

**動的な検証（各画面の表示・Dusk・観測可能な振る舞いの assert）は Phase 4 の完了基準**であり、
ここでは静的に確認できるものと既存テストの非破壊だけを見る。

- [ ] `php artisan route:list` で `docs/api-spec.md` の全ルートが存在
- [ ] Policy が全リソースに存在
- [ ] `docs/architecture.md` の「Action 一覧」の 4 クラスが `app/Actions/` に存在
- [ ] レイアウト `layouts/app.blade.php` / `layouts/admin.blade.php` が存在し、
      `x-admin-layout` を解決する `app/View/Components/AdminLayout.php` がある
- [ ] `layouts/admin.blade.php` に `@livewireScripts` が書かれている
      （実際にダイアログが出るかは Phase 4 の Dusk が検証する）
- [ ] 削除確認を伴うフォームに `x-data` が付いている（同上）
- [ ] Breeze 生成物の `dashboard` / `profile` 参照が仕様に追従済み（`route('dashboard')` が残っていない）
- [ ] `tests/Browser/ExampleTest.php` が書き換え済み（`welcome.blade.php` の削除に追従）
- [ ] `php artisan test` が all green（Phase 1 の Breeze 認証テストを壊していない）
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse --memory-limit=512M` がエラー 0

## やらないこと

- **Feature / Dusk テストの新規作成（Phase 4 で実施）**。Breeze 生成テストの追従（`dashboard` →
  `home` 等）は本フェーズの作業に含まれるが、新しい検証を書き足すのは Phase 4 の担当
- Seeder の投入（Phase 5 で実施）
- 本番デプロイ設定

## 完了後

`/verify` を実行し、結果を報告。
