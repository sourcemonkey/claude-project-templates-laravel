# Phase 2 でモデル設計上、手順書に明記が無く自分の判断で埋めた箇所

- フェーズ: Phase 2
- 状態: 未分類
- 初回観測: 2026-08-13
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase2-models.md` の手順に従いモデル・マイグレーション・ファクトリ・モデルテストを実装し、
`migrate` / `migrate:rollback` / `migrate` / `php artisan test`(66件)/ `vendor/bin/pint --test` /
`vendor/bin/phpstan analyse --memory-limit=512M`(0エラー)すべて成功した。エラー・警告は
発生していない。ただし、手順書に明記が無く自分の判断で埋めた箇所が複数あったため、
「共通の進め方」手順3に従い記録する(フェーズは成功しているため申し送りの分類は行わない)。

## 根拠

1. **`Lending::$fillable` を `['user_id', 'book_id', 'note']` に限定した。**
   `state` / `approved_at` / `due_on` / `returned_at` は含めていない。手順書は
   「状態遷移用の外部パッケージは使わず...モデルのメソッドは state 遷移(と対応する
   approved_at / returned_at の設定)に限定する」と書いているが、`$fillable` に何を
   含めるかは明記が無い。`requested_at`(NOT NULL)は `booted()` の `creating` イベントで
   `$lending->requested_at ??= now();` として自動設定する設計にした(fillable に含めず、
   Phase 3 の `RequestLendingAction` が明示的に渡さなくても済むようにした)。

   - 関連ファイル: `my-laravel-app/app/Models/Lending.php:33`(fillable)、`:39-43`(booted)

2. **`approve()` は `due_on` を設定しない設計にした。** `docs/api-spec.md` の
   `PATCH /admin/lendings/{lending}/approve` には副作用として「due_on = 14日後」が
   挙がっているが、`scaffold-phase2-models.md` は「モデルのメソッドは state 遷移(と
   対応する approved_at / returned_at の設定)に限定する」と明記しており due_on は
   挙がっていない。この記述を文字通り採用し、`due_on` の設定は Phase 3 の
   `ApproveLendingAction` 側の責務とした。

   - 関連ファイル: `my-laravel-app/app/Models/Lending.php:78-87`(approve メソッド)

3. **`Book::$fillable` に `available_copies` を含めた。** `docs/db-schema.md` の
   バリデーション要点に「編集フォームでは直接編集できるが、Form Request に
   `lte:total_copies` を必ず付ける」とあり、管理者が編集可能な項目として扱った。

   - 関連ファイル: `my-laravel-app/app/Models/Book.php:15-25`

4. **`AuditLogFactory` の `target_type` に固定文字列 `'App\Models\Book'` を使った。**
   手順書・docs に具体的な値の指定が無いため、任意の値として選んだ。

   - 関連ファイル: `my-laravel-app/database/factories/AuditLogFactory.php`

## なぜ自動で直さなかったか

いずれもエラーや矛盾ではなく、手順書に明記が無い箇所を実装のために埋めた設計判断。
「共通の進め方」手順3の「自分の判断で埋めた箇所」に該当するため、修正ではなく記録として残す。

## 選択肢

未記入(判定は対話セッションで行う)。

## 推奨

未記入(判定は対話セッションで行う)。

## 決めてほしいこと

上記 1〜4 の判断が Phase 3(`RequestLendingAction` / `ApproveLendingAction` /
`BookController` 等)の実装と整合するか確認してほしい。特に 2 は、Phase 3 の
Action 実装時に `due_on` を明示的に設定する箇所が必要になる。

## 暫定対応

なし(上記の設計のままコミットしている)。
