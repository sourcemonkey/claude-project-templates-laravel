# フェーズトライアル自動化プロンプト

`claude -p "$(cat .claude/prompts/trial-phase.md)"` のようにリポジトリルートで
ヘッドレス実行し、対象フェーズの実行 → 問題点の洗い出し → ドキュメント修正 →
コミットを自動で行うためのプロンプト。全フェーズ分のセクションを最初から
用意してあり、「実行対象フェーズ」の1行を書き換えるだけで対象範囲を広げられる。

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
   - Phase 1 の `laravel new` 生成物のうち `.npmrc` は自動配置できない。
     残置された場合は完了報告に従って手動で移動する。
   - 手順書（`.claude/commands/*.md`）や本ファイル自体の修正はヘッドレス
     では行えない。修正済みの完全版を `patches/` ディレクトリに置いて
     ユーザーの適用を待つ（適用後に `patches/` は削除する）。

## 実行対象フェーズ

現在の実行対象: Phase 1 のみ

（精査が進んだら「Phase 1〜2」のように書き換える。この1行以外は編集不要。）

## 共通の進め方

以下の「実行対象フェーズ」に含まれる各フェーズについて、この手順を順に適用する。

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
8. 修正が完了したら、論理的な単位ごとに分けてコミットする
   （`team-rules/git-workflow.md` に従う。メッセージは日本語、Conventional
   Commits の type は英語のまま、`Co-Authored-By: Claude <noreply@anthropic.com>`
   を付与する）
9. 「やったこと / 次にやること / 詰まっていること」の3点で報告する

## Phase 1: スケルトン生成

**このセクションは「実行対象フェーズ」に Phase 1 が含まれる場合のみ実行する。
含まれない場合は何も実行せず、Phase 2 以降のセクションを確認する。**

- リセット: `bin/reset-phase.sh 1`
- 実行コマンド: `/scaffold-phase1-skeleton`
- 対象ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md`
- 完了確認: `/verify`（Phase 1 完了時のチェック項目）

「共通の進め方」の手順に従って実行・修正・コミットする。

## Phase 2: DB スキーマ・モデル生成

**このセクションは「実行対象フェーズ」に Phase 2 が含まれる場合のみ実行する。
含まれない場合は何も実行せず、Phase 3 以降のセクションを確認する。**

- リセット: `bin/reset-phase.sh 2`
- 実行コマンド: `/scaffold-phase2-models`
- 対象ファイル: `my-laravel-app/.claude/commands/scaffold-phase2-models.md`
- 完了確認: `/verify`（Phase 2 完了時のチェック項目）
- 前提: Phase 1 が単体で問題なく完走する状態になっていること

「共通の進め方」の手順に従って実行・修正・コミットする。

## Phase 3: 認証・UI

**このセクションは「実行対象フェーズ」に Phase 3 が含まれる場合のみ実行する。
含まれない場合は何も実行せず、Phase 4 のセクションを確認する。**

- リセット: `bin/reset-phase.sh 3`
- 実行コマンド: `/scaffold-phase3-ui`
- 対象ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md`
- 完了確認: `/verify`（Phase 3 完了時のチェック項目）
- 前提: Phase 1〜2 が問題なく完走する状態になっていること

「共通の進め方」の手順に従って実行・修正・コミットする。

## Phase 4: 仕上げ

**このセクションは「実行対象フェーズ」に Phase 4 が含まれる場合のみ実行する。
含まれない場合は何も実行しない。**

- リセット: `bin/reset-phase.sh 4`
- 実行コマンド: `/scaffold-phase4-finalize`
- 対象ファイル: `my-laravel-app/.claude/commands/scaffold-phase4-finalize.md`
- 完了確認: `/verify`（Phase 4 完了時のチェック項目）
- 前提: Phase 1〜3 が問題なく完走する状態になっていること

「共通の進め方」の手順に従って実行・修正・コミットする。
