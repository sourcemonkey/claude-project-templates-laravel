# Phase 3 手順書のページネーション検証例が、Livewire 一覧の画面仕様と噛み合わない

- フェーズ: Phase 3
- 状態: 未解決
- 初回観測: 2026-08-01

## 何が起きたか

`scaffold-phase3-ui.md` の「テストシナリオ」節にある**ページネーション検証の例**を
そのまま書いたところ、`?page=2` の assert が落ちた。

```
Failed asserting that the value at [books] fulfills the expectations defined by the closure.
Failed asserting that false is true.
```

原因は 2 段階ある。

1. 例は `$this->get('/books')->assertViewHas('books', ...)` の形なので、
   **`BookController::index()` が `books` を view に渡していること**を前提にしている。
   ところが `docs/screens.md` はメンバーの蔵書一覧を
   「検索 / ページネーション / タグ・カテゴリで絞り込み（**Livewire コンポーネント**）」と
   定めており、一覧の解決は Livewire 側にある。Controller は `books` を渡さない。
2. 例に合わせるため Controller 側にも `paginate(25)` を置くと、今度は
   **`?page=2` が常に 1 ページ目を返す**。Livewire の `WithPagination` が
   `Paginator::currentPageResolver` を「コンポーネントの `$paginators` を読む」形に
   差し替え、それが**同一テストプロセスの後続リクエストへ残る**ため、
   2 回目のリクエストで Controller の `paginate()` がコンポーネントのページ番号
   （1）を拾ってしまう。

## 根拠

失敗を切り分けるため、ページ番号そのものを assert した:

```php
$page2 = $this->actingAs($member)->get('/books?page=2')->assertOk();
expect($page2->viewData('books')->currentPage())->toBe(2);
```

```
Failed asserting that 1 is identical to 2.
```

同じ 30 件を作って **Livewire コンポーネントを持たない** `/admin/books?page=2` を
叩くと `currentPage()` は 2 を返す（＝ `?page=2` 自体は壊れていない）。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md:441-459`
- 関連ファイル: `my-laravel-app/docs/screens.md`（メンバー領域の表、`GET /books` の行）

## なぜ自動で直さなかったか

修正対象が `.claude/commands/` 配下でヘッドレスから書き込めないため
（「共通の進め方」手順 4 の `patches/` 経由に該当）。方針そのものは
`docs/screens.md` が一次情報として Livewire と定めているので迷いはない。

## 選択肢

1. **手順書のテスト例を `Livewire::test(BookSearch::class)` 側に直す** —
   影響: 手順書の 1 ブロックのみ。`docs/screens.md` の画面仕様はそのまま /
   懸念: Controller が薄くなり、`assertViewHas` に慣れた読み手には一瞬わかりにくい
2. **メンバー蔵書一覧を Controller ページネーションに変え、Livewire は検索欄だけにする** —
   影響: `docs/screens.md` の画面仕様の変更を伴う / 懸念: 「検索結果の絞り込みは
   Livewire」という `docs/architecture.md` の方針と衝突する

## 推奨

案 1。`docs/screens.md` が一次情報として一覧を Livewire と定めており、
手順書のテスト例だけがそれに追随できていない。修正版の完全版を
`patches/scaffold-phase3-ui.md` に置いた。

## 決めてほしいこと

`patches/scaffold-phase3-ui.md` を `my-laravel-app/.claude/commands/scaffold-phase3-ui.md`
へ適用してよいか（テスト例を `Livewire::test()` 形へ差し替える案 1）。

## 暫定対応

トライアルでは案 1 の形で実装・検証済み。

- `BookController::index()` は一覧を解決せず `view('books.index')` を返すだけにし、
  「Controller 側にも paginate を置くと currentPageResolver が残る」旨のコメントを
  実装に添えた
- `tests/Feature/PaginationTest.php` は
  `Livewire::test(BookSearch::class)->assertViewHas('books', ...)->call('gotoPage', 2)`
  でメンバー側を、`assertViewHas` で管理画面側（Livewire を持たない）を検証している

**これらは `my-laravel-app/` 配下の生成物なのでテンプレート本体への差分は無い**
（リセットで消える）。テンプレート側の差分は `patches/scaffold-phase3-ui.md` のみ。
