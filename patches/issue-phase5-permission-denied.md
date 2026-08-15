# `kill` が許可リストに無く、バックグラウンドサーバーの停止で承認待ちになった

- フェーズ: Phase 5
- 状態: 未分類
- 初回観測: 2026-08-16
- 実行モデル: claude-sonnet-5

## 何が起きたか

手順 6-8（`composer run dev` での起動確認）の前に、Dusk 用に起動していた
`php artisan serve --env=dusk.local --no-reload` を止めようとして `kill <pid>` を
実行したところ、承認待ちで停止した（ヘッドレスのため承認できず、コマンドは実行されない）。

## 根拠

```
$ kill 16583
This command requires approval
```

ルートの `.claude/settings.json` には `Bash(pkill -f *)` はあるが、素の `kill` は
許可リストに無い。

- 関連ファイル: `.claude/settings.json:73`（`Bash(pkill -f *)` はあるが `kill` は無い）

## なぜ自動で直さなかったか

`--model sonnet` での実行のため、判断を伴うものはすべて `patches/` へ回す
（`prompts/trial-phase.md` の「実行モデル」節）。分類も同じ理由で行っていない。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

`Bash(kill *)`（または `Bash(kill -TERM *)` 等の限定形）を許可リストに追加するか。
対話セッションなら承認して進められる操作であり、`pkill -f *` は既に許可されている。

## 暫定対応

`TaskStop` ツール（`run_in_background: true` で起動したタスクの ID を渡して停止する
ハーネス機能）で代替し、`php artisan serve` と `composer run dev` の両方を問題なく
停止できた。ただしこの代替は「このセッション自身が `run_in_background` で起動した
プロセス」にしか使えず、汎用の `kill` の代替にはならない。
