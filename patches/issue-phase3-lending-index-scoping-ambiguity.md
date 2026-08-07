# LendingController::index() の絞り込み方針が architecture.md と screens.md で読み方が割れる

- フェーズ: Phase 3
- 状態: 未分類
- 初回観測: 2026-08-08
- 実行モデル: claude-sonnet-5

## 何が起きたか

`docs/architecture.md` の Policy セクションに次の例がある。

```php
// 絞り込みあり（LendingController::index() 等）
$lendings = $request->user()->isAdmin()
    ? Lending::query()
    : $request->user()->lendings();
```

この例をそのまま読むと、`LendingController::index()`（メンバー向け `/lendings`）は
admin なら全件、member なら自分の分だけを返す実装に見える。

一方 `docs/screens.md` の画面一覧は `GET /lendings` を「自分の貸出一覧」と明記しており、
`docs/api-spec.md` も member 用ルート（`LendingController`）と admin 用ルート
（`Admin\LendingController` の `貸出申請一覧`）を別クラス・別ルートとして定義している。

今回は screens.md の記述を優先し、**`LendingController::index()` は
`$request->user()->isAdmin()` の分岐を持たせず、常に `$request->user()->lendings()`
のみを返す**実装にした（全件を見る手段は既に `Admin\LendingController::index()` として
別に存在するため）。

## 根拠

- `my-laravel-app/docs/architecture.md` の「Policy」セクション、上記コード例
- `my-laravel-app/docs/screens.md` の「メンバー領域」表、`GET /lendings` の行
  （「自分の貸出一覧」）
- `my-laravel-app/docs/api-spec.md` の全体構造（`LendingController` と
  `Admin\LendingController` が別クラス）

## なぜ自動で直さなかったか

`--model sonnet` での実行のため、判断を伴う記述の解釈は自動で確定させず記録に留める
（`prompts/trial-phase.md` の「実行モデル」節）。

## 選択肢

未記入（判定は対話セッションで行う）

## 推奨

未記入（判定は対話セッションで行う）

## 決めてほしいこと

`docs/architecture.md` の当該コード例は、実際には admin 用と member 用の
2 つの `LendingController` が存在する設計を踏まえると誤解を招く書き方になっていないか。
「絞り込みが必要なリソースの一般例」として書かれた説明が、たまたま具体的なクラス名
（`LendingController::index()`）を使ってしまったことで、本プロジェクトの実際のルーティング
（member 用と admin 用が別コントローラ）と矛盾して見える。書き方を直すか、
「（一般的なパターンの例であり、本プロジェクトでは admin 用と member 用が別コントローラに
分かれている）」といった注記を足すか。

## 暫定対応

`my-laravel-app/app/Http/Controllers/LendingController.php` の `index()` は
分岐なしで `view('lendings.index')` を返すのみとし、実際のクエリは
`app/Livewire/LendingSearch.php` 内で常に `auth()->user()->lendings()` を使う形にした
（`Admin\LendingController` 側は `Lending::query()` で全件）。テンプレート本体
（docs/architecture.md）は変更していない。
