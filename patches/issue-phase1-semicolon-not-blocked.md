# `;` 連結コマンドが Bash ツールでブロックされなかった

- フェーズ: Phase 1
- 状態: 未分類
- 初回観測: 2026-08-15
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase1-skeleton.md` Step 9-5(起動確認)で、`/` `/login` `/register` への
`curl` 3 つを「同一ブロックで複数呼び出しにする」よう指示されているところを、誤って
`;` で連結した 1 個の Bash コマンドとして実行してしまった。`prompts/trial-phase.md`
前提条件 6 の表は「`&&` / `||` / `;` の連結」を Bash ツールが拒否すると明記しているが、
実際にはブロックされず、3 つとも `200` を返して正常終了した。

## 根拠

実行したコマンド(原文):

```
curl -sS --retry 5 --retry-all-errors --retry-delay 1 -o /dev/null -w "/: %{http_code}\n" http://localhost:8000; curl -sS --retry 5 --retry-all-errors --retry-delay 1 -o /dev/null -w "/login: %{http_code}\n" http://localhost:8000/login; curl -sS --retry 5 --retry-all-errors --retry-delay 1 -o /dev/null -w "/register: %{http_code}\n" http://localhost:8000/register
```

結果(拒否されず実行された):

```
/: 200
/login: 200
/register: 200
```

- 関連ファイル: `prompts/trial-phase.md` 前提条件 6 の表(`&&` / `||` / `;` の連結の行)

## なぜ自動で直さなかったか

実行モデルが Sonnet 系のため、「実行モデル」節の規則により判断を伴う切り分け
(手順書の記述が現在の Bash ツール仕様と乖離しているのか、たまたま今回だけ通ったのか)
を行わず、観測のみを記録する。

## 選択肢

未記入(判定は対話セッションで行う)

## 推奨

未記入(判定は対話セッションで行う)

## 決めてほしいこと

前提条件 6 の「`;` の連結は拒否される」という記述は現在の Bash ツールの実際の挙動と
一致しているか。一致していない(拒否されなくなっている)場合、表の記述を更新するか、
もしくは「拒否されるとは限らないが規約として連結しない」という趣旨に書き換える必要が
あるか。

## 暫定対応

停止コマンド(`pkill` 3 つ)は正しく個別の Bash 呼び出しに分けて実行し直した。
テンプレート本体(手順書・docs)への変更は行っていない。
