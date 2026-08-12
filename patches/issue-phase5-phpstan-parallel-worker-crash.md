# phpstan analyse が並列ワーカーのクラッシュで 1 度だけ失敗した

- フェーズ: Phase 5
- 状態: 未分類
- 初回観測: 2026-08-13
- 実行モデル: claude-sonnet-5

## 何が起きたか

「共通の進め方」手順 6-6（`vendor/bin/phpstan analyse` でエラー 0 を確認する手順）で、
オプション無しで実行したところ子プロセスのクラッシュで失敗した。同じコマンドに
`--memory-limit=1G` を付けて再実行したところエラー 0 で成功した。以降は再実行していない
ため、`--memory-limit` の指定が原因を解消したのか、単に再実行で解消したのかは
切り分けられていない。

## 根拠

1 回目（オプション無し）:

```
{"tool":"phpstan","result":"failed","errors":1,"general_errors":["Child process error (exit code 255):  while running parallel worker"]}
```

2 回目（`--memory-limit=1G` を付与）:

```
{"tool":"phpstan","result":"passed","errors":0}
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase5-finalize.md`（手順 6-6、
  `vendor/bin/phpstan analyse` を無条件に実行する記述）

## なぜ自動で直さなかったか

再現条件が不確か、かつ 1 回しか観測できておらず原因の特定に至っていない
（「共通の進め方」手順 4 の申し送り基準）。実行モデルが Sonnet 系のため、
判断を伴う変更は行わず記録のみに専念する規則が適用される。

## 選択肢

未記入（判定は対話セッションで行う）

## 推奨

未記入（判定は対話セッションで行う）

## 決めてほしいこと

再現するか確認したうえで、再現する場合は `docs/stack.md` か手順書に
`vendor/bin/phpstan analyse --memory-limit=1G`（または `--no-parallel` 等）への
変更を反映するか、それとも一過性の環境要因として記録のみに留めるか。

## 暫定対応

このセッションでは `--memory-limit=1G` を付けて再実行し、Phase 5 の完了基準
（phpstan エラー 0）を満たしたことを確認した。テンプレート本体への変更は行っていない。
