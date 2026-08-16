---
description: フェーズ4 - Phase 3 で作った UI を Feature / Dusk テストで検証する
---

# Phase 4: UI テスト（Feature / Dusk）

Phase 3 で実装した画面・認可・Action が `docs/` の定めどおりに動くことを、テストで検証する。
検証すべき振る舞いの一次情報は `docs/screens.md` / `docs/api-spec.md` / `docs/architecture.md`、
実装側の設計判断は Phase 3 手順書（`.claude/commands/scaffold-phase3-ui.md`）にある。

> **着手前に `docs/architecture.md` を Read すること。** レイヤの責務・`ActionResult` の形・
> 認可エラーの挙動・Policy の書き方が一次情報だが、`CLAUDE.md` から `@` 参照していないため
> 自動では文脈に入っていない。

> **実行場所**: 本手順書のコマンドは、断りが無い限りすべて **`my-laravel-app/` をカレント**として
> 書かれている。Bash ツールのカレントは呼び出しをまたいで持続するので、**最初に一度だけ**
> `cd my-laravel-app` し、以降は移動しない（ルートにも別物の `bin/` があり、そこから
> `bin/check-repo.sh` を打つと `exit 127` になる）。

> **前提**: Phase 3 が完走していること（`php artisan test` が green、`route:list` に仕様の全ルートが
> 並び、`tests/Browser/ExampleTest.php` が Phase 3 の Breeze 追従で書き換え済みであること）。

## 実行順序

1. `tests/DuskTestCase.php` の設定
2. `.env.dusk.local` の作成
3. `signInAs` / `makeUser` ヘルパーを `tests/Pest.php` に追加
4. Dusk のテストシナリオを書く
5. Feature テスト（主要フロー・ページネーション・各画面の 200 確認）を書く
6. `vendor/bin/pint` → `php artisan test` → `php artisan dusk`

### `tests/DuskTestCase.php` の設定（テストを書く前に必ず実施）

Dusk では `RefreshDatabase` 等のロールバックが効かないため、`Illuminate\Foundation\Testing\DatabaseTruncation` トレイトでテストごとに関連テーブルを truncate する:

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

- **`php artisan serve --env=dusk.local --no-reload`** で `APP_URL`（`http://localhost:8000`）が
  応答していること。Dusk は自前でサーバーを起動しない。**起動は Bash ツールの
  `run_in_background` で行い、停止は `TaskStop` で行う**（`kill <pid>` は承認待ちになる）

  > **`--env=dusk.local` と `--no-reload` は両方とも必須。** どちらが欠けても、ブラウザが
  > 叩くサーバーが**開発用の `bookkeeper`** を読み、`bookkeeper_test` にデータを作る
  > テストプロセスと DB が食い違う。テストが用意したデータが画面に出ず、`waitForText` や
  > ログインが**原因の分かりにくい形でタイムアウトする**。
- ChromeDriver がホストの Chrome とバージョン一致していること。ずれている場合は
  `php artisan dusk:chrome-driver --detect`（Phase 1 手順書参照）
- 非 TTY 環境では `Warning: TTY mode requires /dev/tty to be read/writable.` が出るが
  処理は継続するので無視してよい

### `signInAs` ヘルパー

ログイン後にリダイレクト完了を待たずに次の操作を行うと断続的に失敗するテストになる。次のヘルパーを用意すること。

> **置き場所は `tests/Pest.php` の「Functions」節**（`pest --init` が生成するコメントブロックの
> ある箇所）。**各 Dusk テストファイルに同じ関数を書いてはならない。** 2 つ以上のファイルで
> 宣言すると `Fatal error: Cannot redeclare function signInAs()` で `php artisan dusk` 全体が
> 起動しなくなる。

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

> **重要（先頭の `logout()` は省略不可）**: Dusk はブラウザをテスト間で再利用するため、前の
> セッションが残ったまま `/login` を開くとリダイレクトされ `no such element: ... body email`
> で落ちる。**単体では通り、まとめて走らせると落ちる**ので原因を掴みにくい。

> **補足（パスワード）**: `UserFactory` の既定パスワードは `password`。`signInAs` は
> `password123` を使うため、上記 `makeUser()` のように明示すること。

> **重要（`waitUntil('window.Livewire')` は省略不可）**: `livewire.js` のロード前に
> `press('ログイン')` すると**ネイティブ submit** が走り、`waitForLocation('/')` が
> `Waited 5 seconds for location [/].` でタイムアウトする（失敗時のスクリーンショットは
> **入力欄が空のログイン画面**になる）。**テストが少ないうちは偶然通り、Dusk が増えると
> 実行ごとに別のテストが落ちるフレーキーな症状**になるため、最初から入れておくこと。

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

**待機条件は必ず「操作によって状態が変わる側」に置く。** 「絞り込み後も残る要素」を条件に
すると、待機が成立した時点が絞り込み前なのか後なのか区別できない。

> **`wire:model` の入力欄は `#id` セレクタで指定する。** Dusk の `type('title', ...)` は
> `name` 属性を前提にしているが Livewire の入力欄は `name` を書かないのが普通で、
> `no such element: {"method":"css selector","selector":"body title"}` で落ちる。

### confirm ダイアログを伴う操作

削除ボタンのように `confirm()` を挟む操作は、次の 2 つを守ること。**`acceptDialog()` の前に
`waitForDialog()` を挟む**（生成前に呼ぶと `no such alert` で落ちる）。**`press()` の前に
対象フォームの Alpine 初期化を待つ**（初期化前に押すと素通りする）。

```php
$browser->waitUntil("document.querySelector('form[x-data]')?._x_dataStack !== undefined")
    ->press('削除')
    ->waitForDialog()
    ->acceptDialog()
    ->waitForText('書籍を削除しました');
```

> **`waitUntil('window.Alpine')` では足りない**（Alpine オブジェクトが生えただけで、
> 個々の要素の `x-data` 初期化は保証されない）。初期化を終えた要素には `_x_dataStack` が
> 生えるので、**そのフォーム自身**を見るのが正確な条件になる。

なお、ダイアログがそもそも出ず `waitForDialog()` が
`Waited 5 seconds for dialog.` で落ちる場合、原因は 3 つある。順に確認すること:

1. **フォームに `x-data` が無い**（`livewire.js` は読み込まれているのにダイアログが出ない
   場合はこれ）。Phase 3 手順書「画面実装の注意」の削除確認の項を参照。
   `layouts/app.blade.php` を使うメンバー画面（返却フォーム等）でも起きる
2. **そもそも Alpine が読み込まれていない**（管理画面で顕著）。Phase 3 手順書
   「画面実装の注意」の `@livewireScripts` の項を確認すること
3. **1・2 を満たしているが、ハイドレーション完了前に `press()` している**。`x-data` があり
   `@livewireScripts` もあるのに落ちる場合はこれ。上記のとおり `press()` の前に
   `_x_dataStack` の待機を挟む。**実行するたびに落ちるテストが変わる**場合は
   まずこれを疑うこと（1・2 が原因なら毎回同じ箇所で落ちる）

**1・2 は実装側の不備なので、テストで迂回せず Phase 3 の成果物を直すこと。**

#### フレーキー時の扱い（1 回だけ再実行してよい）

原因 3 は待機条件を精密にしても残りうる。**フルスイートで落ちたテストが単体では
通る場合に限り、`php artisan dusk` の再実行を 1 回だけ行ってよい。**

- **再実行して green なら、そのフェーズは完了基準を満たしたものとして扱う**
  （`aborted` にしない）
- **ただし報告に必ず書くこと。** どのテストが・どのメッセージで落ちたか、
  単体実行では通ったか、再実行後のフルスイートは green だったかを記す。
  黙って再実行すると、待機条件の不備が「安定している」と誤認されて残り続ける
- **2 回目以降も落ちる場合は再実行を重ねない。** それはフレーキーではなく
  原因 1・2 の実装漏れなので、上の 3 点を順に確認して直す

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
> `available_copies` を減らさない**ため、そのまま返却させると CHECK 制約
> `books_available_lte_total` に違反する。
>
> ```php
> $book = Book::factory()->create(['total_copies' => 2, 'available_copies' => 1]);
> $lending = Lending::factory()->approved()->create(['book_id' => $book->id]);
> ```
>
> **テストからは「state が Approved のまま変わらない」という形でしか見えない**ので
> （`Failed asserting that two variables reference the same object.`）、在庫制約が原因だと
> 気づきにくい。

`php artisan dusk` で確認する。**green になったことを「待機条件が正しい」ことの証明に
しないこと**（ハイドレーション待ちの漏れはサーバーが速く返れば通ってしまう）。待機の
書き方は前掲「Livewire で一覧が絞り込まれるのを待つ」の原則で担保する。

あわせて Feature テスト（`php artisan test`）でも
主要フロー（借用申請の業務ルール、認可、ロール変更、通知の既読化、返却、**ページネーション**）を押さえること。

**ファイルの配置・命名は問わない**（`tests/Feature/` 配下ならサブディレクトリを切ってよい）。
完了基準は観点で判定するため、構成を決める必要はない。

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
> Livewire::test(BookList::class)
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
> **(a) の画面で「Controller にも paginate を置いて `assertViewHas` で書く」ことはできない**
> （`?page=2` でも 1 ページ目が返るため `count() === 5` が落ちる。Phase 3 手順書参照）。
>
> **Livewire コンポーネントには `WithPagination` トレイトを付けること。** 付け忘れると
> 2 ページ目で検索条件を変えたときに**ページ番号がリセットされず「該当なし」になる**。
> 1 ページ目しか見ないテストでは検出できないため、
> `Livewire::test(BookList::class)->call('gotoPage', 2)->set('title', ...)` のように
> ページ送り後の絞り込みも 1 件検証しておく。

**各画面がデータなしでも 200 を返すことを確認する Feature テスト**を書く（完了基準に対応）。

> **「データありの詳細画面」も併せて 1 件ずつ叩くこと。** データなしの一覧は
> `@if ($items->isEmpty())` 側しか通らず、**行を描画する分岐が一度も実行されない**。
> `$log->created_at?->format(...)` のような null 参照はレコードが 1 件ある状態で初めて踏む。

## 観測可能な振る舞いは assert で固定する

`docs/` が**外から見える具体値**を定めている箇所は、**その値を直接検証する assert** をテストに
含めること。**実装に合わせて書いたテストは仕様違反でも green になる**ため、これが無いと
検出する手段が無くなる。

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

## Pint 自動修正

テストを書き終えてから実行する:

```sh
vendor/bin/pint
```

**パスを列挙して渡さないこと。** 触ったディレクトリを書き漏らすうえ、`bootstrap` を明示指定
すると**引数なしなら除外される `bootstrap/cache/*.php`** まで整形対象に入る。

## このフェーズの完了基準

まず `bin/check-repo.sh`（読み取りのみ）を実行し、終了コード 0 を確認してから以下を確認する。

- [ ] 各画面が（データなしでも）500 にならずに表示できる（Feature テストで確認）
- [ ] 未ログインで `GET /` が 200（nav の `@auth` ガード漏れがない）
- [ ] **`docs/` が定める観測可能な振る舞いに、対応する assert が存在する**（上記）
- [ ] メンバー蔵書一覧のページネーションが `Livewire::test()` で検証済み（`assertViewHas` を
      `$this->get('/books')` に対して書いていない）
- [ ] `php artisan test` が all green（Phase 1 の Breeze 認証テストを含む）
- [ ] `php artisan dusk` が all green
- [ ] **Dusk が次の 3 つを実際にブラウザで検証している**（`php artisan dusk` が green なだけでは足りない）
  - [ ] **蔵書一覧の検索・絞り込み**（Livewire の再描画を待つ。本ファイルの
        「Livewire で一覧が絞り込まれるのを待つ」節と `wire:model` の `id` の注意を参照）
  - [ ] **管理画面の削除確認ダイアログ**（`x-data` と `@livewireScripts` が両方無いと
        確認なしで削除が走る。`docs/stack.md` の Alpine の項を参照）
  - [ ] **貸出フローの 4 ボタン**（`借用を申請` / `返却` / `承認` / `却下` を `press()` で叩く。
        文言は `docs/screens.md` の表が一次情報）

  > **この 3 つを名指しするのは、書かなければ罠を踏まずに済んでしまうため。** 過去の
  > トライアルは Dusk 6 件で完了基準を満たしたが、報告の「今回参照しなかった注意書き」3 件が
  > すべて「該当する Dusk テストを書かなかったので踏まなかった」で、**手順書が積み上げてきた
  > 罠の記述がテストを書かないことで丸ごと迂回された**。
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse --memory-limit=512M` がエラー 0

## やらないこと

- 画面・Controller・Policy・Action の新規実装（Phase 3 で完了しているべき。
  テストで不備が見つかった場合は Phase 3 の成果物を直す）
- Seeder の投入（Phase 5 で実施）
- カバレッジ 80% の判定（Phase 5 で初めて測る）

## 完了後

`/verify` を実行し、結果を報告。
