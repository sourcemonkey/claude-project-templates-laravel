# `Lending::approve()` が `due_on` を設定するかどうかが手順書間で読み分けを要する

- フェーズ: Phase 2
- 状態: 未分類
- 初回観測: 2026-08-16
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase2-models.md` の「Lending の state 遷移」節に従い `Lending` モデルへ
`approve()` / `reject()` / `returnBook()` を実装する際、`approve()` が `due_on`
（14 日後）を設定すべきかどうかが 2 つの記述から一意に決まらなかった。

`state` = `Approved` と `approved_at` の設定は `approve()` 内で行い、`due_on` は
設定しない実装にした（次の「根拠」節の解釈による）。

## 根拠

`scaffold-phase2-models.md:196`:

> 在庫減算・通知などの副作用は Action（Phase 3）側で行い、モデルのメソッドは state 遷移
> （と対応する `approved_at` / `returned_at` の設定）に限定する。

この文は模型メソッドの責務を「state 遷移」「`approved_at` の設定」「`returned_at` の設定」
の 3 つに**明示的に**限定しており、`due_on` は列挙されていない。

一方 `api-spec.md`（`PATCH /admin/lendings/{lending}/approve` の項）:

> 副作用: state を `Approved`、`approved_at` 設定、`due_on = 14 日後`、
> `books.available_copies -= 1`、通知作成
>
> すべて 1 トランザクション内（`ApproveLendingAction` で実装）

こちらは `due_on` の設定を `state` / `approved_at` と同列に並べたうえで、
「すべて `ApproveLendingAction` で実装」と締めており、`due_on` が Action 側の
責務であることを示唆しているとも読めるが、`state` / `approved_at` も同じ並びに
含まれているため、この一文だけでは「`ApproveLendingAction` が model の
`approve()` を呼んだ**上で** `due_on` だけ追加で設定する」のか「`due_on` も
含めて `approve()` 呼び出し 1 つで完結する」のかを区別できない。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase2-models.md:196`
- 関連ファイル: `my-laravel-app/docs/api-spec.md`（`### PATCH /admin/lendings/{lending}/approve` の項）

## なぜ自動で直さなかったか

`--model sonnet` での実行のため、判断を伴うものはすべて `patches/` へ回す
（`prompts/trial-phase.md` の「実行モデル」節）。分類（手順書の欠陥か誤読を招く
書き方かモデル能力の限界か）も同じ理由で行っていない。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

`Lending::approve()` は `due_on`（14 日後）を自分で設定すべきか、それとも
Phase 3 の `ApproveLendingAction` が model の `approve()` 呼び出し後に
別途 `due_on` を設定すべきか。

## 暫定対応

今回のセッションでは `Lending::approve()` に `due_on` を含めず、`state` と
`approved_at` のみ設定する実装にした（`my-laravel-app/app/Models/Lending.php`）。
Phase 3 の `ApproveLendingAction` 実装時に、この関数が `due_on` を
設定する前提で書く必要がある。この前提が誤っていた場合、`Lending::approve()`
への `due_on` 引数追加（または Action 側での直接代入）の手直しが要る。
