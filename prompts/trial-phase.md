# フェーズトライアル自動化プロンプト

`claude -p "$(cat prompts/trial-phase.md)"` のようにリポジトリルートで
ヘッドレス実行し、対象フェーズの実行 → 問題点の洗い出し → ドキュメント修正 →
コミットを自動で行うためのプロンプト。「実行対象フェーズ」の1行を
書き換えるだけで対象範囲を広げられる。

## 前提条件

実行前に以下が満たされていることを確認する。満たされていない場合は作業を
進めず、その旨を報告して終了する。

1. **Docker daemon が起動していること**: `docker info` で接続確認できること。
   未起動の場合 `bin/reset-phase.sh` はエラー終了する（Docker Desktop を
   起動してから再実行する）。
2. **実行セッションに許可リストが効いていること**: 本プロンプトはリポジトリ
   ルートで `claude -p` 起動されるため、適用されるのは**ルートの**
   `.claude/settings.json` のみ。`my-laravel-app/.claude/settings.json` は
   ルート起動のセッションには適用されない。フェーズ実行に必要な許可
   （`php artisan *`, `composer *`, `docker compose *`, `laravel new *`,
   `Edit`, `Write` 等）はルート側の許可リストに含めておくこと。
3. **スラッシュコマンドの読み込み**: ルート起動のセッションには
   `my-laravel-app/.claude/commands/` のスラッシュコマンドが読み込まれない
   場合がある。`/scaffold-phaseN-xxx` が実行できないときは、対象のコマンド
   ファイル（`my-laravel-app/.claude/commands/scaffold-phaseN-xxx.md`）を
   Read し、その手順を直接実行する。
4. **センシティブファイル保護の制約を織り込むこと**: Claude Code の
   センシティブファイル保護により、ヘッドレスセッションでは `.npmrc` および
   `.claude/` 配下のファイルへの書き込み・移動・削除が承認できず失敗する
   （許可リストの `Edit` / `Write` 許可よりも優先される）。この制約により:
   - Phase 1 の `.npmrc` はテンプレート同梱・git 追跡ファイルに格上げ済みの
     ため、ヘッドレスで自動配置できなくても直下に存在し問題にならない。
     `tmp-skeleton/.npmrc` が残置されても手動対応は不要（次回リセットの
     `git clean` で除去される）。
   - 手順書（`my-laravel-app/.claude/commands/*.md`）の修正はヘッドレスでは
     行えない。修正済みの完全版を `patches/` ディレクトリに置いてユーザーの
     適用を待つ（適用後に `patches/` は削除する）。
   - 一方、**本ファイル（`prompts/trial-phase.md`）は `.claude/` の外にあり
     ヘッドレスからも直接修正できる**。トライアル中に判明した前提条件の誤り・
     手順の不足・実行対象フェーズの更新は、`patches/` を経由せずその場で
     反映してよい。

## 実行対象フェーズ

現在の実行対象: Phase 1〜2

（精査が進んだら「Phase 1〜3」のように広げる。この1行以外は編集不要。）

## 共通の進め方

「実行対象フェーズ」に含まれる各フェーズについて、この手順を順に適用する。

1. リポジトリルートで `bin/reset-phase.sh <フェーズ番号>` を実行し、そのフェーズ
   実行前の状態にリセットする
2. `my-laravel-app/` ディレクトリに移動し、対象のスラッシュコマンド
   （`/scaffold-phaseN-xxx`）を実行する
3. 実行中に発生したエラー・警告・非対応バージョン等の問題を記録する
4. 見つかった問題はまず根本原因を特定する。原因が
   `my-laravel-app/.claude/commands/scaffold-phaseN-xxx.md` の手順の誤りで
   あればそのファイルを修正する。`my-laravel-app/docs/*.md`、
   `my-laravel-app/CLAUDE.md`、`team-rules/*.md` の前提が誤っている場合は
   そちらも合わせて修正する
5. `bin/reset-phase.sh` の該当フェーズの分岐が現状に合わない、または未実装
   （`*)` にフォールバックしている）場合は、そのフェーズのリセット処理を
   実装・修正する
6. `/verify` でそのフェーズの完了基準を満たしているかセルフチェックする
7. 満たしていなければ 3〜6 を繰り返す
8. 修正が完了したら、論理的な単位ごとに分けて **`main` ブランチへ直接
   コミットする**。**本プロンプトによる起動をもってコミットの明示的な指示と
   みなす**ため、提案に留めず実際にコミットすること。ブランチは切らない。
   このとき `team-rules/git-workflow.md` の次の 2 条項は**本トライアルには
   適用しない**（これ以外の条項には従う）:
   - 「ユーザーの明示的な指示なしに `git commit` しない」
   - 「フェーズ実行中は Claude Code 側からコミットの提案・実行を行わない」

   `git push` 禁止・ファイルの明示指定・メッセージ規約などの詳細はルート
   `CLAUDE.md` の「このリポジトリ自身の git 運用」に従う
9. 結果を報告する（形式はルート `CLAUDE.md` のコミュニケーション節に従う）

## 各フェーズの実行

「実行対象フェーズ」に含まれるフェーズだけを番号順に、「共通の進め方」の
手順に従って実行・修正・コミットする。含まれないフェーズは何も実行しない。

| フェーズ | 内容 | リセット | 実行コマンド | 前提 |
|---|---|---|---|---|
| Phase 1 | スケルトン生成 | `bin/reset-phase.sh 1` | `/scaffold-phase1-skeleton` | — |
| Phase 2 | DB スキーマ・モデル生成 | `bin/reset-phase.sh 2` | `/scaffold-phase2-models` | Phase 1 が単体で完走すること |
| Phase 3 | 認証・UI | `bin/reset-phase.sh 3` | `/scaffold-phase3-ui` | Phase 1〜2 が完走すること |
| Phase 4 | 仕上げ | `bin/reset-phase.sh 4` | `/scaffold-phase4-finalize` | Phase 1〜3 が完走すること |

対象ファイルは `my-laravel-app/.claude/commands/<実行コマンド名>.md`、
完了確認は各フェーズとも `/verify`（該当フェーズのチェック項目）。
