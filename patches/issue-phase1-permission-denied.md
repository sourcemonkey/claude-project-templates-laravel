# `git status --short --cached` が許可リストに無く承認待ちで拒否される

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-30

## 何が起きたか

Phase 1 のコミット前に、`git add` したファイルだけが staged になっているかを確認しようとして
`git status --short --cached` を実行したところ、権限で拒否された。`git diff --cached --name-only`
に切り替えて同じ確認ができたため、トライアル自体は止まっていない。

ルート `CLAUDE.md` の「このリポジトリ自身の git 運用」は main へ直接コミットする際に
**「コミット前に `git status` で意図しないファイルの混入を確認する」**ことを求めており、
staged の内容を絞って見る用途は今後も繰り返し発生する。

## 根拠

拒否されたコマンド（原文）:

```
git status --short --cached
```

返ってきたメッセージ（原文）:

```
This command requires approval
```

`git status` はオプション無しなら Claude Code が読み取り専用コマンドとして自動承認するが、
`--cached` を付けるとこの判定から外れる（`prompts/trial-phase.md` の前提条件 6 が
`git -c <key>=<value>` について述べているのと同種の現象）。

- 関連ファイル: `.claude/settings.json`（許可リスト。ヘッドレスからは書き込めない）
- 関連ファイル: `CLAUDE.md` の「このリポジトリ自身の git 運用」

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の**許可リストの不足**に当たる。反映先の `.claude/settings.json` は
ヘッドレスから書き込めない。

## 選択肢

1. **`Bash(git status:*)` を許可リストに足す** — 影響: `git status` の全オプションが通る。/
   懸念: `git status` は read-only なので実害は考えにくいが、前置パターンの粒度としては広い。
2. **何も足さず `git diff --cached --name-only` を使う運用に寄せる**（今回の回避策）— 影響:
   設定変更なし。/ 懸念: 次に走る Claude Code が同じところで一度止まる。手順書のどこにも
   書かれていないため学習が引き継がれない。
3. **`prompts/trial-phase.md` の前提条件 6 に「`git status --cached` は自動承認されない」を
   追記する**（案 2 と併用）— 影響: 手順側で回避できる。/ 懸念: 許可リストの設計は変わらない。

## 推奨

案 1。`git status` は副作用が無く、deny リストの `Bash(git push*)` 等とも競合しない。
`-c` を前置する形（`git -c foo=bar status`）とは違い、`git status` のサブコマンド以降に
付くオプションだけなので deny の迂回経路にもならない。

## 決めてほしいこと

`.claude/settings.json` の許可リストに `Bash(git status:*)` を追加してよいか。
（追加しない場合は案 3 として `prompts/trial-phase.md` に注意書きを足す。）

## 暫定対応

`git diff --cached --name-only` で代替した。テンプレート本体には手を入れていない。
