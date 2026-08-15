# BookFactory の isbn 生成で `fake()->optional()->unique()->isbn13()` が Error を投げた

- フェーズ: Phase 2
- 状態: 未分類
- 初回観測: 2026-08-15
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase2-models.md` には Faker の連結順に関する記述が無いため、`BookFactory` の
`isbn`（nullable, unique）を自分の判断で `fake()->optional()->unique()->isbn13()` として実装した。
`php artisan test tests/Unit/Models` を実行したところ、`isbn` のユニーク制約テストに加え、
`Book::factory()` を内部で呼ぶ他モデル（`Lending` 等）のテストも含め計 7 件が
`Call to a member function isbn13() on null` で失敗した。

## 根拠

```
{"test":"P\\Tests\\Unit\\Models\\BookTest::__pest_evaluable_isbn_must_be_unique", ...
 "message":"Failed asserting that an instance of class Error is an instance of class Illuminate\\Database\\QueryException."}
```

```
{"test":"P\\Tests\\Unit\\Models\\LendingTest::__pest_evaluable_approve_transitions_from_requested_to_approved",
 "file":".../database/factories/BookFactory.php","line":23,
 "message":"Call to a member function isbn13() on null"}
```

- 関連ファイル: `my-laravel-app/database/factories/BookFactory.php:23`（修正後は `fake()->unique()->isbn13()`）

## なぜ自動で直さなかったか

`--model sonnet` 起動のため「実行モデル」節の規則により、判断を伴う修正は
その場修正の対象にせず `patches/` へ回す方針とした（ただし今回は
`my-laravel-app/` 側のファクトリという生成物であり、テンプレートの手順書・docs 自体の
誤りではないため、そのまま `fake()->unique()->isbn13()` に単純化してテストを green にし、
先へ進めている。テンプレート側の記述を直す判断ではなく生成物側の実装選択のため、
本ファイルは「起きた事象の記録」として残すのみで `patches/edit-*.md` は作成していない）。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

`scaffold-phase2-models.md` の「ファクトリ」節に、Faker の `optional()` は
チェーンの最外側に置かないと `null` に対して後続メソッドを呼んで `Error` になる
（`optional()->unique()->X()` ではなく `optional()->X()` か、あるいは nullable 値が
不要なら単に `unique()->X()` にする）という注意書きを追加すべきか。
追加する場合、`isbn` のように「nullable だが factory の既定では常に値を入れて構わない」
（テストでの上書きで null を明示すれば足りる）方針を明文化するかどうかも合わせて判断してほしい。

## 暫定対応

`BookFactory` の `isbn` 生成を `fake()->optional()->unique()->isbn13()` から
`fake()->unique()->isbn13()` に変更した（`my-laravel-app/database/factories/BookFactory.php:23`）。
これにより `isbn` は常に値が入る状態になり、nullable 自体の検証はモデルテストでは
行っていない（DB 制約としては nullable のままで、Phase 3 以降で明示的に `null` を渡すテストを
書けば検証できる）。
