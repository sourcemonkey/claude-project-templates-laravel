# Phase 1 で権限拒否されたコマンド

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

Phase 1 のトライアル中、次のコマンドがルートの `.claude/settings.json` の
許可リストに無く実行できなかった。

## 根拠

拒否されたコマンド（原文のまま）:

```
composer why livewire/livewire
```

エラー:

```
This command requires approval
```

`Bash(composer *)` ではなく個別のサブコマンドが列挙されている形になっており、
`composer why` が漏れている（`composer require` / `composer install` /
`composer run setup` 等は通った）。

## なぜ自動で直さなかったか

反映先の `.claude/settings.json` はセンシティブファイル保護によりヘッドレスから
書き込めないため（「共通の進め方」手順 4 の「権限拒否・ツール制約」に該当）。

## 選択肢

1. **`Bash(composer why*)` を追加する** — 影響: 依存の逆引きができるようになる /
   懸念: なし（読み取り専用のサブコマンド）
2. **追加しない** — 影響: 現状維持 / 懸念: 依存関係の調査のたびに
   `grep` で `vendor/*/composer.json` を読む迂回が必要になる

## 推奨

案 1。`composer why` は読み取り専用で副作用がなく、依存バージョンの解決理由を
調べる際の一次情報になる。

## 決めてほしいこと

ルートの `.claude/settings.json` に `Bash(composer why*)` を追加してよいか。

## 暫定対応

`grep -n '"livewire/livewire"' -B 2 -A 2 vendor/livewire/volt/composer.json` で
volt 側のバージョン制約を直接読み、`composer why` の代わりとした。
テンプレート本体への差分はなし。
