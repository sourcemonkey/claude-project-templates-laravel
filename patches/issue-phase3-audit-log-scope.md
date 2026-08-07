# 監査ログ（audit_logs）を書き込む Action / Controller の範囲が明記されていない

- フェーズ: Phase 3
- 状態: 未分類
- 初回観測: 2026-08-08
- 実行モデル: claude-sonnet-5

## 何が起きたか

`docs/architecture.md` の「Action 一覧」表は `ApproveLendingAction` の責務を
「state 変更 + 在庫減算 + 通知 + 監査ログ、トランザクション内」と明記している。
一方で他の 3 Action（Request/Reject/Return）や、Admin の Book/Category/Tag/User
CRUD の Controller には、監査ログを書く責務が明記されていない。

しかし `docs/seeds.md` の「監査ログ（3件）」節には次のサンプルが含まれる。

```
- 管理者太郎が書籍を1件更新: action: "update"
- 管理者太郎が貸出を1件approve: action: "approve"
- 管理者太郎がカテゴリを1件create: action: "create"
```

このうち `approve` は `ApproveLendingAction` の責務と一致するが、書籍の `update` と
カテゴリの `create` は、どの Action/Controller が書き込む想定なのか
`docs/architecture.md` に記載がない。

今回は `docs/architecture.md` の「Action 一覧」表に明記された範囲（承認時のみ）に
限定して実装し、`Admin\BookController` / `Admin\CategoryController` 等の CRUD は
監査ログを書き込まない実装にした。

## 根拠

- `my-laravel-app/docs/architecture.md` の「本プロジェクトの Action 一覧」表
- `my-laravel-app/docs/seeds.md` の「監査ログ（3件）」節（book update / category create の
  サンプルが存在するが、生成元が Action 一覧に無い）

## なぜ自動で直さなかったか

`--model sonnet` での実行のため、実装範囲に関わる判断は自動で確定させず記録に留める
（`prompts/trial-phase.md` の「実行モデル」節）。

## 選択肢

未記入（判定は対話セッションで行う）

## 推奨

未記入（判定は対話セッションで行う）

## 決めてほしいこと

Book/Category/Tag/User の CRUD（Admin\BookController::update() 等）でも監査ログを
書き込むべきか。書き込む場合、`docs/architecture.md` の「Action 一覧」表に
該当の Action を追加する（例: `UpdateBookAction`）か、あるいは Controller に
直接書き込む方針を明記する必要がある。`docs/seeds.md` のサンプルは Phase 4 の
Seeder が直接投入するダミーデータに過ぎず、実際に Phase 3 の実装が生成する
必要はない、という整理も妥当ではある。

## 暫定対応

`app/Actions/ApproveLendingAction.php` のみが `AuditLog::create()` を呼ぶ。
Book/Category/Tag/User の CRUD は監査ログを書き込まない。テンプレート本体
（docs/architecture.md）は変更していない。
