# BookFactory の available_copies が 0 になりうるため、承認系テストが確率的に落ちる

- フェーズ: Phase 3
- 状態: 未解決
- 初回観測: 2026-07-20

## 何が起きたか

Phase 3 の Dusk テスト「管理者が申請を承認できる」を、手順書の
「テストシナリオ」節に沿って次のように書いた。

```php
$lending = Lending::factory()->create();
// ... /admin/lendings/{id} で「承認」を押す
```

初回実行で、承認後に出るはずの `借用申請を承認しました` が表示されず
タイムアウトした。実際に返っていたのは `ApproveLendingAction` の失敗メッセージ
`在庫が無いため承認できません。` だった。

原因は `Lending::factory()` が連鎖生成する `Book::factory()` の在庫。
Phase 2 手順書のファクトリ指示（「先に `total_copies` を決め、
`available_copies` はその範囲内で採る」）に素直に従うと

```php
$totalCopies = fake()->numberBetween(1, 5);
'available_copies' => fake()->numberBetween(0, $totalCopies),
```

となり、**`available_copies` が 0 になる**（`total_copies` が 1 のときは 1/2 の確率、
5 のときで 1/6）。この本に対する貸出を承認しようとすると
`ApproveLendingAction` の在庫チェックで弾かれる。

再実行すると乱数次第で通ってしまうため、「たまに落ちるテスト」になる。

## 根拠

失敗時の出力（原文）:

```
{"tool":"pest","result":"failed","tests":5,"passed":4,"assertions":5,
"duration_ms":15234,"errors":1,"error_details":[{"test":
"P\\Tests\\Browser\\LendingFlowTest::__pest_evaluable_an_admin_can_approve_a_lending_request",
"file":".../vendor/php-webdriver/webdriver/lib/WebDriverWait.php","line":71,
"message":"Waited 5 seconds for text [借用申請を承認しました]."}]}
```

在庫チェックの実装（`docs/api-spec.md` の「エンドポイント詳細」に沿ったもの）:

```php
if (! $book->hasAvailableCopy()) {
    return new ActionResult(false, '在庫が無いため承認できません。');
}
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase2-models.md`（「ファクトリ」節の
  `Book` ファクトリに関する指示）
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md`（「テストシナリオ」節の
  「管理者が申請を承認できる」）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「妥当な解が複数あり、どれを採るかが方針の選択になる」に当たる。
ファクトリの既定値をどう定義するかは、他のテスト（在庫切れの検証など）の書き方にも影響する。

## 選択肢

1. **`BookFactory` の既定を `available_copies = total_copies` にし、在庫 0 が要る
   テストは `outOfStock()` state で明示する** — 影響: Phase 2 手順書のファクトリ指示と
   `BookFactory` の実装を変更。/ 懸念: 「在庫が一部貸出中」という中間状態が既定から
   外れるため、一覧画面の見え方が単調になる（Seeder は `docs/seeds.md` が
   明示値を持つので影響しない）
2. **`available_copies` を `numberBetween(1, $totalCopies)` にする（0 を除くだけ）** —
   影響: 変更が 1 行。/ 懸念: 在庫 0 を作りたいテストは結局明示指定が要るので、
   `outOfStock()` state が無いぶん 1 より不便。既定値の意味も説明しづらい
3. **ファクトリは変えず、Phase 3 手順書の「テストシナリオ」に
   「承認テストでは在庫を明示すること」と注記する** — 影響: 手順書 1 箇所。/
   懸念: 罠が残り続け、Seeder や別のテストを書くたびに同じ判断が要る

## 推奨

案 1。ファクトリの既定は「素直に使って通る値」であるべきで、在庫切れは
異常系として state で明示するほうが、テストの意図が読み手に伝わる。

## 決めてほしいこと

`BookFactory` の既定を「`available_copies = total_copies`（在庫満杯）+ `outOfStock()` state」に
変更してよいか？（Yes / No。No の場合は案 2・案 3 のどちらか）

## 暫定対応

トライアルを進めるため、Dusk テスト側で在庫を明示した。

```php
// tests/Browser/LendingFlowTest.php
$book = Book::factory()->create(['total_copies' => 2, 'available_copies' => 2]);
$lending = Lending::factory()->create(['book_id' => $book->id]);
```

**テンプレート本体（`BookFactory` / 手順書）には変更を入れていない。**
案 1 または案 2 を採る場合、この明示指定は不要になるので取り消してよい。
