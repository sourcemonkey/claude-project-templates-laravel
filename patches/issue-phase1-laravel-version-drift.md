# laravel new が生成する Laravel Framework のバージョンが手順書記載の 13.20.0 より進んでいる

- フェーズ: Phase 1
- 状態: 未分類
- 初回観測: 2026-08-13
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase1-skeleton.md` の Step 8（`scripts.setup` の調整）は、既定の `composer.json` 生成物を
「Laravel Framework 13.20.0 で確認」したものとして記載している。今回のトライアルで
`laravel new tmp-skeleton --no-interaction --pest` を実行したところ、`composer.lock` に記録された
実際のバージョンは `v13.25.0` だった。

手順書記載の `composer.json` の `dev` / `setup` スクリプトの形（`@php artisan dev` への委譲、
`DevCommands::except('queue')` による除外)は今回もそのまま再現し、Step 8 の手順どおりの編集で
`php artisan dev:list` が `server` / `logs` / `vite` の 3 つになることを確認できた。実害は無かった。

## 根拠

```
$ grep -A2 '"name": "laravel/framework"' composer.lock | grep version
            "version": "v13.25.0",
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:343`
  （「既定の生成物（Laravel Framework 13.20.0 で確認）に次の 3 点を変更する」の記述）

## なぜ自動で直さなかったか

「実行モデル」節の規則により、Sonnet 系セッションは判断を伴う修正を行わず `patches/` へ回す。
バージョン表記の更新は「その場で直す」対象（誤字脱字）ではなく、手順書が今後も同じ書き方を
続けるかどうかの方針判断（バージョン表記を削るか、都度更新するか、範囲表記にするか）を伴う。

## 選択肢

未記入（判定は対話セッションで行う）

## 推奨

未記入（判定は対話セッションで行う）

## 決めてほしいこと

`scaffold-phase1-skeleton.md:343` の「Laravel Framework 13.20.0 で確認」という具体的なバージョン
表記を、今回観測した `v13.25.0` に更新するか、そのままにするか、あるいはバージョンを明記しない
書き方（例:「Laravel 13.17 以降の `laravel new` が生成する」のみに留める）に変えるか。

## 暫定対応

なし（手順書の記述どおりに Step 8 を実行し、完了基準はすべて満たした）。
