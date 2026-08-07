#!/usr/bin/env bash
#
# フェーズトライアルを**フェーズごとに別セッション**で順に実行する。
#
# 使い方:
#   bin/run-trial.sh                 Phase 1〜4 を順に実行
#   bin/run-trial.sh 1 3             Phase 1〜3 を実行
#   bin/run-trial.sh 2 4             Phase 2〜4 を実行（Phase 1 完走済みの状態から）
#   CC_TRIAL_MODEL=opus bin/run-trial.sh     モデルを変える（既定: sonnet）
#
# なぜ 1 セッションで通さないか:
#   API はステートレスで毎回全履歴を再送するため、コストは「呼び出し数 × その時点の
#   文脈量」で決まる。1 セッションでフェーズを重ねると文脈が単調に増え、総コストは
#   呼び出し数に対して二次関数的に伸びる。実測（2026-08-06）では Phase 1 と Phase 2 が
#   同じ 69 呼び出しでありながら Phase 2 が 41% 高く、Phase 3 は平均文脈 315K で
#   66M トークンを消費した。フェーズごとに区切れば各セッションが空の文脈から始まり、
#   通しで 3 分の 1 程度に収まる見込み。
#
# 前提:
#   Phase 1 から始める場合、起動前に bin/reset-phase.sh 1 を DB 破棄あり（y）で
#   実行しておくこと。本スクリプトは破壊的操作を行わない。
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

PROMPT_FILE="$ROOT/prompts/trial-phase.md"
MODEL="${CC_TRIAL_MODEL:-sonnet}"
LOG_DIR="${CC_TRIAL_LOG_DIR:-$HOME/claude-trial-logs}"

FROM="${1:-1}"
TO="${2:-4}"

if [ ! -f "$PROMPT_FILE" ]; then
    echo "プロンプトが見つかりません: $PROMPT_FILE" >&2
    exit 1
fi

case "$FROM$TO" in
    *[!0-9]*) echo "フェーズ番号は数字で指定してください（例: bin/run-trial.sh 2 4）" >&2; exit 1 ;;
esac

mkdir -p "$LOG_DIR"

echo "モデル: $MODEL / 対象: Phase $FROM〜$TO / ログ: $LOG_DIR"
echo

phase="$FROM"
while [ "$phase" -le "$TO" ]; do
    log="$LOG_DIR/trial-phase${phase}-$(date '+%Y%m%d-%H%M%S').log"
    echo "===== Phase $phase 開始 $(date '+%H:%M:%S') ====="

    # 「実行対象フェーズ」の 1 行はプロンプト末尾の指示で上書きする。
    # trial-phase.md 自体は書き換えないので、並行実行や再実行で衝突しない。
    claude -p --model "$MODEL" "$(cat "$PROMPT_FILE")

---

**この実行での対象は Phase ${phase} のみとする。** 上の「実行対象フェーズ」の記述より
こちらを優先する。この実行の最初のフェーズは Phase ${phase} であり、前提条件 1・2 の
分岐もそれに従って判定する。" 2>&1 | tee "$log"

    # フェーズの結末はマーカーで判定する。終了コードでは判別できない
    # （「前提条件を満たさないので終了します」と報告して正常終了しても 0 になる）。
    if grep -q "^\[phase-result\] phase=${phase} status=ok" "$log"; then
        echo "===== Phase $phase 完了 $(date '+%H:%M:%S') ====="
        echo
        phase=$((phase + 1))
        continue
    fi

    echo >&2
    if grep -q "^\[phase-result\] phase=${phase} status=aborted" "$log" ; then
        echo "Phase $phase が中断しました。以降のフェーズは実行しません。" >&2
        grep "^\[phase-result\]" "$log" >&2
    else
        echo "Phase $phase の結末マーカーが見つかりません。以降のフェーズは実行しません。" >&2
        echo "セッションが途中で終了したか、マーカーの出力を忘れています。" >&2
    fi
    echo "ログ: $log" >&2
    exit 1
done

echo "Phase $FROM〜$TO をすべて完了しました。"
echo
echo "トークン消費の集計:"
echo "  bin/phase-tokens.sh --all"
