# Phase 2 実行時の解釈・判断の記録（観測のみ）

- フェーズ: Phase 2
- 状態: 未分類
- 初回観測: 2026-09-02
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase2-models.md` の手順に従い、`users` テーブル補正・残りのモデル・
マイグレーション・ファクトリ・モデルテストを一通り実装した。エラーで詰まった箇所は
無く、`php artisan test`（67 件）・`vendor/bin/pint --test`・
`vendor/bin/phpstan analyse --memory-limit=512M`・`bin/check-repo.sh` はすべて green。
以下は手順書に明記が無く、自分の判断で埋めた箇所。

## 根拠

1. **`Lending` の遷移メソッドが `save()` を呼ぶかどうか**: 手順書 `scaffold-phase2-models.md:183`
   は「モデルのメソッドは state 遷移(と対応する approved_at/returned_at の設定)に限定する」
   としているが、永続化(`save()`)をメソッド内で行うかは明記が無い。今回は `approve()` /
   `reject()` / `returnBook()` の末尾で `$this->save()` を呼ぶ実装にした
   （Action 側が `due_on` を追加で設定して再度 `save()` する前提）。

2. **`LendingFactory` の `overdue()` / `returned()` state の具体的な日数**: `approved()` は
   `docs/architecture.md` 相当の 14 日後ルールに合わせたが、`overdue()`
   （`approved_at` を 20 日前、`due_on` を 6 日前に設定）と `returned()`
   （`approved_at` を 10 日前、`due_on` を 4 日後、`returned_at` を現在に設定）の具体的な
   日数は `docs/db-schema.md` / `docs/seeds.md` に記載が無く、辻褄が合うように自分で決めた。

3. **`Category` / `Tag` / `Book` の一部フィールドの Faker 選択**: `name`（`words(2, true)` /
   `word()`）、`title`（`sentence(3)`）、`author`（`name()`）、`publisher`（`company()`）、
   `published_on`（`date()`）、`description`（`optional()->sentence()` /
   `optional()->paragraph()`）は `docs/db-schema.md` に型の指定のみで Faker メソッドの
   指定が無いため、妥当と判断した値を自分で選んだ。

3 件とも `my-laravel-app/app/Models/Lending.php`、
`my-laravel-app/database/factories/LendingFactory.php`、
`my-laravel-app/database/factories/{Category,Tag,Book}Factory.php` に反映済み。

## なぜ自動で直さなかったか

`--model sonnet` 実行のため、判断を伴うものはすべて記録に回す
（`prompts/trial-phase.md` の「実行モデル」節）。分類（手順書の欠陥か、モデル能力の
限界かなど）もこのモードでは行わない。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

上記 3 点の実装が仕様として妥当か。妥当であれば、手順書に明記するか判断待ち。

## 暫定対応

なし（実装はそのままコミットに含める。手順書側への回避策の追記はしていない）。
