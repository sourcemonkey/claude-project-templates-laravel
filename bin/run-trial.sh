#!/usr/bin/env bash
#
# フェーズトライアルを**フェーズごとに別セッション**で順に実行する。
# 使い方は usage() を参照（引数なしで実行すると表示される）。
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

# フェーズを増減したら、この上限と bin/reset-phase.sh の PHASE_COMMANDS / case を直すこと。
PHASE_MAX=5

usage() {
    cat <<USAGE
フェーズトライアルをフェーズごとに別セッションで実行する。

使い方:
  bin/run-trial.sh <フェーズ>          そのフェーズだけ実行（例: bin/run-trial.sh 3）
  bin/run-trial.sh <開始> <終了>       開始〜終了を順に実行（例: bin/run-trial.sh 1 ${PHASE_MAX}）

フェーズ番号は 1〜${PHASE_MAX}:
  1 スケルトン生成 / 2 モデル / 3 UI 実装 / 4 UI テスト / 5 仕上げ

環境変数:
  CC_TRIAL_MODEL     使うモデル（既定: sonnet）
  CC_TRIAL_LOG_DIR   ログの出力先（既定: \$HOME/claude-trial-logs）

前提:
  Phase 1 から始める場合、起動前に bin/reset-phase.sh 1 を DB 破棄あり（y）で
  実行しておくこと。本スクリプトは破壊的操作を行わない。

**引数なしでは実行しない。** 通しの実行は数時間・数千万トークンを要するため、
確認のつもりの起動で走り出さないよう対象を必ず明示させる。
USAGE
}

if [ "$#" -eq 0 ]; then
    usage
    exit 0
fi

if [ "$#" -gt 2 ]; then
    echo "引数は 1 つか 2 つです（指定: $# 個）。" >&2
    echo >&2
    usage >&2
    exit 1
fi

FROM="$1"
TO="${2:-$1}"

for n in "$FROM" "$TO"; do
    case "$n" in
        ''|*[!0-9]*)
            echo "フェーズ番号は数字で指定してください（指定: '$n'）。" >&2; exit 1 ;;
    esac
    if [ "$n" -lt 1 ] || [ "$n" -gt "$PHASE_MAX" ]; then
        echo "フェーズ番号は 1〜${PHASE_MAX} です（指定: $n）。" >&2; exit 1
    fi
done

if [ "$FROM" -gt "$TO" ]; then
    echo "開始フェーズが終了フェーズより後です（$FROM 〜 $TO）。" >&2
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo "プロンプトが見つかりません: $PROMPT_FILE" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

if [ "$FROM" -eq "$TO" ]; then
    TARGET="Phase ${FROM}"
else
    TARGET="Phase ${FROM}〜${TO}"
fi

echo "モデル: ${MODEL} / 対象: ${TARGET} / ログ: ${LOG_DIR}"
echo

phase="$FROM"
while [ "$phase" -le "$TO" ]; do
    log="$LOG_DIR/trial-phase${phase}-$(date '+%Y%m%d-%H%M%S').log"
    echo "===== Phase $phase 開始 $(date '+%H:%M:%S') ====="

    # 「実行対象フェーズ」の 1 行はプロンプト末尾の指示で上書きする。
    # trial-phase.md 自体は書き換えないので、並行実行や再実行で衝突しない。
    claude -p --model "$MODEL" "$(cat "$PROMPT_FILE")

---

**この実行での対象は Phase ${phase} のみとする。** 他のフェーズには手を出さないこと。
前提条件 1・2 の分岐も Phase ${phase} を「今回のフェーズ」として判定する。" 2>&1 | tee "$log"

    # フェーズの結末はマーカーで判定する。終了コードでは判別できない
    # （「前提条件を満たさないので終了します」と報告して正常終了しても 0 になる）。
    if grep -q "^\[phase-result\] phase=${phase} status=ok" "$log"; then
        # `claude -p` は最終メッセージだけを標準出力へ出す。したがって end マーカーが
        # ログに無ければ、報告より前のメッセージで出力したことになり、報告作成分の
        # 消費が「マーカー外」へ落ちる（実測で 0.6M 相当）。失敗ではないので続行する。
        if ! grep -q "^\[phase-tokens\] phase=${phase} event=end" "$log"; then
            echo "⚠ Phase $phase: [phase-tokens] event=end がログにありません。" >&2
            echo "  報告より前に出力したため、報告作成分の消費が計測から漏れています" >&2
            echo "  （prompts/trial-phase.md「フェーズごとのトークン計測」参照）。" >&2
        fi
        # トークン表は bin/phase-tokens.sh の出力をそのまま貼る決まり。合計行が無ければ
        # 途中で切って貼っている（フェーズ以外の区間が報告から消える）。
        if grep -q "^| 区間 | API 呼び出し" "$log" && ! grep -q "^| \*\*合計\*\* |" "$log"; then
            echo "⚠ Phase $phase: トークン表に合計行がありません（加工して貼っています）。" >&2
            echo "  bin/phase-tokens.sh の出力はそのまま貼ってください" >&2
            echo "  （prompts/trial-phase.md 手順 8 の「フェーズ別のトークン消費」）。" >&2
        fi
        echo "===== Phase $phase 完了 $(date '+%H:%M:%S') ====="
        echo
        phase=$((phase + 1))
        continue
    fi

    echo >&2
    if grep -q "^\[phase-result\] phase=${phase} status=aborted" "$log" ; then
        echo "Phase $phase が中断しました。以降のフェーズは実行しません。" >&2
        grep "^\[phase-result\]" "$log" >&2
    elif [ "$(wc -l < "$log")" -le 5 ]; then
        # `claude -p` は最終メッセージだけを出すため、正常に完走したログは数十行になる
        # （実測で 35〜44 行）。数行しか無い場合はプロンプトを読む前に終わっており、
        # 原因はテンプレートではなく実行環境側にある。ログをそのまま見せて切り分ける。
        echo "Phase $phase: セッションがほとんど何も出力しませんでした。" >&2
        echo "プロンプトを読む前に終了した可能性が高く、原因は実行環境側にあります。" >&2
        echo "  例: 認証切れ（claude login で再ログイン）、モデル名の誤り、CLI の起動失敗" >&2
        echo "--- ログ全文 ---" >&2
        cat "$log" >&2
        echo "----------------" >&2
    else
        echo "Phase $phase の結末マーカーが見つかりません。以降のフェーズは実行しません。" >&2
        echo "セッションは起動したので、途中で終了したか、マーカーの出力を忘れています。" >&2
    fi
    echo "ログ: $log" >&2
    exit 1
done

echo "${TARGET} をすべて完了しました。"
echo
echo "トークン消費の集計:"
echo "  bin/phase-tokens.sh --all"
