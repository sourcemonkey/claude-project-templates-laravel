# Phase 3 実装時に手順書へ明記が無く自己判断で埋めた箇所

- フェーズ: Phase 3
- 状態: 未分類
- 初回観測: 2026-08-14
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase3-ui.md` と `docs/screens.md` / `docs/api-spec.md` / `docs/architecture.md` に従って
Controller / View / Policy / Action を実装した。手順は最後まで詰まらず完走し、`php artisan test`
（66 tests, 0 failures）・`vendor/bin/pint --test`・`vendor/bin/phpstan analyse --memory-limit=512M`
はいずれも green。ただし実装の過程で、手順書に明記が無く自分の判断で決めた箇所が複数あった。
Phase 4（Dusk・Feature テスト追加）が本セッションの実装詳細を前提にテストを書くことになるため、
今回どう決めたかを記録する。

## 根拠（判断で埋めた箇所の一覧）

1. **Livewire コンポーネントの命名・配置**: `docs/screens.md` は「蔵書一覧・自分の貸出一覧・
   貸出申請一覧（管理者）」を「Livewire コンポーネント」とだけ指定し、クラス名やビュー名は
   指定していない。今回は以下で実装した:
   - `App\Livewire\Books\BookList`（view: `livewire.books.book-list`、タグ: `<livewire:books.book-list />`）
   - `App\Livewire\Lendings\LendingList`（member 用。view: `livewire.lendings.lending-list`）
   - `App\Livewire\Admin\Lendings\LendingList`（admin 用。view: `livewire.admin.lendings.lending-list`）
   - `App\Livewire\Layout\AdminLogout`（`layouts/admin.blade.php` のログアウトボタン。
     view: `livewire.layout.admin-logout`）
   - 検索欄の `wire:model.live` 対象 input には `docs/screens.md` の Dusk 向け注記に従い
     `id="title"` / `id="author"` / `id="category"` / `id="tag"`（member 蔵書検索）、
     `id="state"`（member/admin 貸出一覧の状態フィルタ）を付けた。

2. **admin 配下のうちどのページを Livewire にするか**: `docs/screens.md` は
   `GET /books`（member）・`GET /lendings`（member）・`GET /admin/lendings` の 3 つだけに
   「（Livewire コンポーネント）」と明記している。`GET /admin/books` / `/admin/users` /
   `/admin/categories` / `/admin/tags` / `/admin/audit-logs` にはこの注記が無いため、
   **非 Livewire（`GET` クエリ文字列 + Spatie QueryBuilder を Controller で直接呼ぶ）**と
   解釈して実装した。この解釈が誤っている場合、Phase 4 でこれらの画面に対して
   `wire:model` 前提の Dusk 操作を書くと失敗する。

3. **`Admin\DashboardController::index()` に `$this->authorize()` を呼んでいない**:
   `docs/architecture.md` は「Controller では各アクションで `$this->authorize()` を呼ぶ」と
   書くが、ダッシュボードは単一モデルに紐づかず対応する Policy アビリティが無い。
   `admin` ミドルウェアが既にアクセス制御しているため、ここでは authorize 呼び出しを
   省略した。

4. **`NotificationPolicy` の新規作成**: `docs/architecture.md` の Policy 節は Book 中心の例のみ
   示しており、Notification 用 Policy の作成は明記されていない。一方 `docs/api-spec.md` は
   `PATCH /notifications/{notification}/read` を「本人のみ」と定めているため、
   `app/Policies/NotificationPolicy.php`（`update` アビリティで `user_id` 一致を見る）を
   自分の判断で追加した。

5. **CRUD 後のリダイレクト先**: `docs/api-spec.md` の「エンドポイント詳細」は
   貸出関連（申請・承認・却下・返却・通知既読）のリダイレクト先のみ規定しており、
   カテゴリ/タグ/蔵書/プロフィールの CRUD 後のリダイレクト先は書かれていない。
   今回は以下で実装した:
   - カテゴリ・タグの作成/更新/削除: `back()`（一覧ページへ戻る、フラッシュ付き）
   - 蔵書の作成/更新: `redirect()->route('admin.books.edit', $book)`
   - 蔵書の削除: `redirect()->route('admin.books.index')`
   - プロフィール更新: `redirect()->route('profile.edit')`

6. **`AuditLog.changes_json` の中身**: `docs/db-schema.md` はカラムの型（nullable JSON）のみ
   規定し、値の形は決めていない。`ApproveLendingAction` では
   `['state' => 'Approved', 'due_on' => $lending->due_on->toDateString()]` を書き込んだ。

7. **`resources/views/home.blade.php` / エラーページ（404/419/500）の具体的なコピー・レイアウト**:
   `docs/screens.md` は「見出しに BookKeeper を含める」以外を規定していない。
   ボタン配置・エラーページの文言は自由に実装した。

## なぜ自動で直さなかったか

いずれも「妥当な解が複数あり得る実装判断」であり、手順書・docs の記述の誤りではない
（「共通の進め方」手順 4 の「その場で直す」対象ではなく、`patches/issue-*.md` への
申し送り対象）。加えて本セッションは `claude-sonnet-5` で起動されており、「実行モデル」節の
規則により手順書・docs 本体の追記は行わず記録のみ行った。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

上記 1〜7 の判断のうち、Phase 4（Feature/Dusk テスト追加）着手前に `docs/screens.md` /
`docs/api-spec.md` / `docs/architecture.md` へ明記しておくべきものがあれば教えてほしい。
特に 1・2（Livewire コンポーネントの命名・どの画面が Livewire か）は Phase 4 のテストコードが
直接参照する可能性が高い。

## 暫定対応

Phase 3 の実装はそのまま採用し、上記の判断内容で `my-laravel-app/` に反映済み
（`my-laravel-app/` 自体はコミット対象外のため、この申し送りにのみ判断内容を残す）。
