# Phase 2 実行中に自分の判断で埋めた箇所（記録のみ）

- フェーズ: Phase 2
- 状態: 未分類
- 初回観測: 2026-08-12
- 実行モデル: claude-sonnet-5

## 何が起きたか

Phase 2（`/scaffold-phase2-models`）を手順書どおりに実行し、エラー・権限拒否は 1 件も
発生しなかった（`php artisan test` / `vendor/bin/pint --test` / `vendor/bin/phpstan analyse` /
`bin/check-repo.sh` すべて green、マイグレーションの可逆性も確認済み）。

一方で、`docs/db-schema.md` / `docs/architecture.md` / `docs/api-spec.md` に明記が無く、
自分の判断で値・構成を決めた箇所がある。手順書の欠陥ではなく実装時の穴埋めだが、
「実行モデル」節の規則により Sonnet 系セッションはこれを判断済みとして扱わず記録に留める。

- **`LendingFactory` の state メソッドが設定する `due_on` / `approved_at` の具体的なオフセット**
  （`approved()`: `due_on = +14日`、`overdue()`: `approved_at = -17日`, `due_on = -3日`、
  `returned()`: `approved_at = -14日`, `due_on = now()`）。`docs/api-spec.md` の
  `ApproveLendingAction`（`due_on = 14日後`）と `docs/db-schema.md` の Seed 例
  （延滞は `due_on = 3日前`）から類推したが、Phase 2 の範囲では明記されていない
- **`AuditLogFactory` の既定値**（`target_type = 'App\Models\Book'`, `action = 'update'`,
  `changes_json = null`）。Phase 2 のモデルテストでのみ使う値のため実害は無いはずだが、
  Phase 4 の Seeder 実装時に異なる既定を期待していないか確認の余地がある
- **`NotificationFactory` の既定 `kind`**（`LendingApproved` を既定にした）。同上の理由で
  Phase 2 の範囲では実害無し
- **モデルテストの網羅範囲**。手順書が要求する 7 観点
  （presence / uniqueness / enum cast / relation / CHECK制約 / 削除時の挙動 / role の
  mass assignment 防止）はすべて満たしたが、各モデルにどのテストを何件書くかは
  手順書に具体例が無いため自分で決めた（`tests/Unit/Models/*.php` 参照）

## 根拠

該当箇所はいずれもエラーではなく、実装ファイルそのものが根拠になる。

- `my-laravel-app/database/factories/LendingFactory.php`
- `my-laravel-app/database/factories/AuditLogFactory.php`
- `my-laravel-app/database/factories/NotificationFactory.php`
- `my-laravel-app/tests/Unit/Models/*.php`

## なぜ自動で直さなかったか

「共通の進め方」手順 3 により、フェーズが成功していても「自分の判断で埋めた箇所」は
記録が必須のため。手順書自体に欠陥は見つかっていない。

## 選択肢

未記入（判定は対話セッションで行う）

## 推奨

未記入（判定は対話セッションで行う）

## 決めてほしいこと

上記の穴埋め値・テスト網羅範囲は Phase 3・Phase 4 の実装（特に `ApproveLendingAction` や
Seeder）と矛盾しないか。矛盾が無ければこのまま採用し、本ファイルは削除してよい。

## 暫定対応

なし（フェーズはこのまま完走している）。
