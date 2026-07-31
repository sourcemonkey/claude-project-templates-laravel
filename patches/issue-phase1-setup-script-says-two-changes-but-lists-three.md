# Phase 1 手順書 Step 8: 「次の 2 点を変更する」と書いてあるが実際は 3 点

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-08-01

## 何が起きたか

`scaffold-phase1-skeleton.md` の Step 8「composer.json の dev / setup スクリプトの調整」で、
`scripts.setup` の変更点が「次の 2 点を変更する」と書かれているが、続く箇条書きは
`1.` `2.` のあと JSON の完成形を挟んで `3.`（`boost:install` の追加）まである。

実装は「変更後」の JSON に `boost:install` が含まれているので正しく作れたが、
**冒頭の「2 点」だけを読んで JSON を見ずに作業すると `boost:install` が抜ける**。
抜けると新規クローンした利用者の `.mcp.json` / `docs/boost-guidelines.md` が生成されず、
`CLAUDE.md` の `@docs/boost-guidelines.md` が解決できない（Step 8 の `3.` 自身が
説明している問題がそのまま起きる）。

## 根拠

該当箇所（原文のまま）:

```
本プロジェクトは DB を Docker で動かし、かつ Seeder 込みで「最初から動く状態」にするため、次の 2 点を変更する:

1. **先頭に `docker compose up -d --wait db` を足す** — ...
2. **`@php artisan migrate --force` を `@php artisan migrate --seed --force` にする** — ...

変更後:

（JSON）

`npm install --ignore-scripts` は既定のまま残す（...）。

3. **`@php artisan boost:install --mcp --guidelines --no-interaction` を足す** — ...
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:338`（「次の 2 点を変更する」）
- 関連ファイル: 同上 `:360`（`3.` の項目）

## なぜ自動で直さなかったか

修正対象が `.claude/commands/` 配下でヘッドレスから書き込めないため
（「共通の進め方」手順 4 の `patches/` 経由に該当）。

**ただし本件は 1 行の差し替えで済むため、`patches/scaffold-phase1-skeleton.md`
（466 行の完全版）は作らなかった。** 全文を書き起こすと転記ミスをテンプレートへ
持ち込む危険のほうが大きいと判断した。下記の Edit を直接当ててほしい。

## 選択肢

1. **「2 点」→「3 点」に直し、`3.` の項目を JSON より前へ移す** — 影響: 手順書の
   1 箇所 + 段落の並べ替え / 懸念: なし
2. **「2 点」→「3 点」だけ直す** — 影響: 1 語のみ / 懸念: `3.` が JSON の後ろに
   残るので、番号の並びが読みにくいままになる

## 推奨

案 1。3 つの変更点を並べてから完成形の JSON を見せる形にすれば、
「JSON を見ずに箇条書きだけ読む」経路でも漏れない。

## 決めてほしいこと

案 1（`3.` を JSON より前へ移して「次の 3 点を変更する」に直す）でよいか。

## 暫定対応

トライアルでは「変更後」の JSON をそのまま採用したため、
`composer.json` の `scripts.setup` には `boost:install` が含まれており、
`composer run setup` からの `.mcp.json` / `docs/boost-guidelines.md` 生成も
2 回の実行で確認済み。テンプレート本体への差分は無い。
