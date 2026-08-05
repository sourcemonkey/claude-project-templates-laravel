# Boost v2.5.0 のガイドラインが存在しない `.ai/rules/index.md` の読み込みを必須と指示する

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-08-05

## 何が起きたか

Phase 1 Step 6 の `php artisan boost:install --mcp --guidelines --no-interaction` は成功し、
`docs/boost-guidelines.md` が生成される。`.ai/guidelines/volt/core.blade.php` による Volt
ガイドラインの上書きも意図どおり効いている（完了基準を満たす）。

しかし生成された `docs/boost-guidelines.md` の `=== boost rules ===` 節に、**このテンプレートに
存在しないディレクトリ `.ai/rules/` を読めという指示**が含まれている。`my-laravel-app/CLAUDE.md`
は `@docs/boost-guidelines.md` でこのファイルを読み込むため、**以降の全セッションが、ファイルを
1 つも作る前に存在しないパスを開きにいくことになる**。

Phase 1 の実行自体は止まらないため、完了基準では検出されない。

## 根拠

`my-laravel-app/docs/boost-guidelines.md` の `=== boost rules ===` 節（原文）:

```
## Project Rules

- This project keeps committed, area-grouped rules in `.ai/rules` (settled decisions, non-obvious traps, standing constraints). Framework and package guidelines that only apply to specific paths (testing, frontend, components) also live there, under `.ai/rules/boost` — this is not just recorded decisions, it is load-bearing guidance you have not seen inline. Before you enter plan mode or create/edit any file, you MUST first: open @.ai/rules/index.md (it maps file globs to rule files), read every rule file whose globs cover the path(s) in scope, and run `grep -rin 'keyword' .ai/rules` to catch what a path match alone misses. Do not write code until you have read and are following every matching rule.
- Record durable rules with `record-rule` so the next agent or teammate inherits them instead of working them out again. Pass a `glob` (e.g. `app/Http/Controllers/**`), a short `title`, and a few-line `note`. Always use `record-rule`, never your native memory or notes tool — native memory is personal and session-scoped; only `.ai/rules` is shared with the team and persists in the repo.
```

実際のディレクトリ構成（`.ai/rules` は存在しない）:

```
$ ls -la .ai/ .ai/rules
ls: .ai/rules: No such file or directory
.ai/:
drwxr-xr-x@  3 fumiaki.sato  staff    96 Jul 26 16:52 guidelines
```

導入されたバージョン:

```
$ composer show laravel/boost
laravel/boost  v2.5.0
```

- 関連ファイル: `my-laravel-app/.ai/guidelines/volt/core.blade.php`（既存の上書き機構）
- 関連ファイル: `my-laravel-app/docs/stack.md`（`laravel/boost` の導入範囲を記述。`.ai/rules` に言及なし）
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:244-263`（Step 6 Laravel Boost）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「妥当な解が複数あり、どれを採るかが**方針の選択**になる」に当たる。
Boost の新機構（`.ai/rules` + `record-rule` MCP ツール）をテンプレートの規約体系
（`team-rules/` + `docs/` + `.ai/guidelines/`）にどう位置づけるかは設計判断であり、
ヘッドレスの単独判断で決めるべきではない。

## 選択肢

1. **`.ai/guidelines/boost/core.blade.php` で `boost rules` 節を上書きする** — 影響: 既存の
   `volt/core.blade.php` と同じ機構なので追加コストが低く、`.ai/rules` への言及と `record-rule`
   の指示を、本テンプレートの `team-rules/` / `docs/` を読めという指示に差し替えられる。
   懸念: Boost 側の `boost rules` には MCP ツール（`search-docs` / `database-schema` 等）の
   有用な説明も含まれるため、上書き時にそれらを書き写して維持する必要がある。
2. **`.ai/rules/index.md` をテンプレート同梱ファイルとして作る** — 影響: Boost の想定どおりの
   構成になり、指示が空振りしない。懸念: ルールの置き場が `team-rules/` / `docs/` /
   `.ai/rules/` の 3 系統になり、`CLAUDE.md` が定める「`docs/*.md` と `team-rules/` が優先」の
   関係が曖昧になる。`record-rule` でエージェントが勝手に書き足す先にもなる。
3. **何もしない** — 影響: ゼロ。懸念: 全セッションが冒頭で存在しないファイルを開こうとし、
   `grep -rin 'keyword' .ai/rules` も毎回失敗する。指示が「MUST」と書かれているため、
   無視してよいと判断できずに手が止まる可能性がある。

## 推奨

案 1。既存の `.ai/guidelines/` 上書き機構をそのまま使え、ルールの置き場を増やさずに済む。
`docs/stack.md` の「`laravel/boost` の導入範囲」節にも、Volt と同じく上書き対象として明記する。

## 決めてほしいこと

Boost の `boost rules` 節を `.ai/guidelines/boost/core.blade.php` で上書きして
`.ai/rules` への誘導を止めるか（案 1）、それとも `.ai/rules/index.md` を同梱して
Boost の想定構成に合わせるか（案 2）。

## 暫定対応

なし。Phase 1 の実行は完走しており、テンプレート本体には何も入れていない。
