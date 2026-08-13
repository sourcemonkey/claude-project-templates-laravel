# Laravel Boost

**Boost の組み込みガイドラインのうち `## Project Rules` 節を本ファイルで上書きしている。**
v2.5.0 の同節は `.ai/rules/index.md` を開いてから作業を始めることを MUST として要求するが、
**本プロジェクトに `.ai/rules/` は存在しない**。ルールの一次情報は `team-rules/` と `docs/`
であり、置き場を増やさない方針のため、その誘導をここで差し替える（`docs/stack.md` の
「`laravel/boost` の導入範囲」参照）。

Tools / Searching Documentation / Artisan / Tinker は Boost の記述をそのまま維持している。

## Tools

- Laravel Boost is an MCP server with tools designed specifically for this application. Prefer Boost tools over manual alternatives like shell commands or file reads.
- Use `database-query` to run read-only queries against the database instead of writing raw SQL in tinker.
- Use `database-schema` to inspect table structure before writing migrations or models.
- Use `get-absolute-url` to resolve the correct scheme, domain, and port for project URLs. Always use this before sharing a URL with the user.
- Use `browser-logs` to read browser logs, errors, and exceptions. Only recent logs are useful, ignore old entries.

## Searching Documentation (IMPORTANT)

- Always use `search-docs` before making code changes. Do not skip this step. It returns version-specific docs based on installed packages automatically.
- Pass a `packages` array to scope results when you know which packages are relevant.
- Use multiple broad, topic-based queries: `['rate limiting', 'routing rate limiting', 'routing']`. Expect the most relevant results first.
- Do not add package names to queries because package info is already shared. Use `test resource table`, not `filament 4 test resource table`.

### Search Syntax

1. Use words for auto-stemmed AND logic: `rate limit` matches both "rate" AND "limit".
2. Use `"quoted phrases"` for exact position matching: `"infinite scroll"` requires adjacent words in order.
3. Combine words and phrases for mixed queries: `middleware "rate limit"`.
4. Use multiple queries for OR logic: `queries=["authentication", "middleware"]`.

## プロジェクトのルール

**`.ai/rules/` は使わない。** ルールの置き場は次の 2 つ。

- `team-rules/*.md` — チーム共通の規約（コーディング / git / レビュー / セキュリティ）
- `docs/*.md` — このプロジェクトの仕様（スタック / アーキテクチャ / DB / 画面 / API / Seed）

**`CLAUDE.md` から `@` 参照しているものは自動で文脈に入るが、一部は意図的に外してある**
（読む場面が限られるものを常時載せないため）。どれをいつ Read するかは `CLAUDE.md` の
「仕様ドキュメント」節の表が一次情報。

食い違った場合は **`docs/*.md` と `team-rules/` が優先**し、Boost のガイドラインは
それらが触れていない領域を補完する（`CLAUDE.md` の「仕様ドキュメント」節が一次情報）。

**`record-rule` ツールは使わない。** 恒久的なルールは上記のいずれかへ直接書く。
どちらに書くか判断できない場合は、書かずにユーザーへ確認する。

## Artisan

- Run Artisan commands directly via the command line (e.g., `php artisan route:list`). Use `php artisan list` to discover available commands and `php artisan [command] --help` to check parameters.
- Inspect routes with `php artisan route:list`. Filter with: `--method=GET`, `--name=users`, `--path=api`, `--except-vendor`, `--only-vendor`.
- Read configuration values using dot notation: `php artisan config:show app.name`, `php artisan config:show database.default`. Or read config files directly from the `config/` directory.

## Tinker

- Execute PHP in app context for debugging and testing code. Do not create models without user approval, prefer tests with factories instead. Prefer existing Artisan commands over custom tinker code.
- Always use single quotes to prevent shell expansion: `php artisan tinker --execute 'Your::code();'`
  - Double quotes for PHP strings inside: `php artisan tinker --execute 'User::where("active", true)->count();'`
