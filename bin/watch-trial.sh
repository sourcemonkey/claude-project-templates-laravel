#!/usr/bin/env bash
#
# 実行中のヘッドレストライアル（claude -p "$(cat prompts/trial-phase.md)"）の
# トランスクリプトを整形して tail -f する。ヘッドレス実行は同時に 1 つの想定。
#
# 使い方: 別ターミナルで bin/watch-trial.sh
#   💬 = モデルの発言 / ▶ = ツール実行 / ⚠ = ツールのエラー結果
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Claude Code のプロジェクトスラッグ: 絶対パスの / と . を - に置換したもの
SLUG="$(echo "$ROOT" | sed 's/[\/.]/-/g')"
TRANSCRIPT_DIR="$HOME/.claude/projects/$SLUG"

# ヘッドレスセッションの見分け方: 先頭付近の user メッセージに
# trial-phase.md の見出しがそのまま入っている（対話セッションには現れない）
MARKER="# フェーズトライアル自動化プロンプト"

# `head -5 "$f" | grep -q "$MARKER"` と書いてはいけない。マーカーは 1 行目にあるため
# grep -q が即座に終了し、head が残りの行（プロンプト全文を含み 1 行 40KB を超える）を
# 書こうとした時点で SIGPIPE で死ぬ。set -o pipefail によりパイプライン全体が非 0 になり、
# **マッチしているのに不一致と判定してスキップする**。先頭行がパイプバッファ（64KB）に
# 収まるうちは偶然通るため、プロンプトが育った時点で顕在化する。
is_trial() {
    case "$(head -5 "$1")" in
        *"$MARKER"*) return 0 ;;
        *) return 1 ;;
    esac
}

session_file=""
for f in $(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null); do
    if is_trial "$f"; then
        session_file="$f"
        break
    fi
done

if [ -z "$session_file" ]; then
    echo "トライアルセッションのトランスクリプトが見つかりません: $TRANSCRIPT_DIR" >&2
    echo "（claude -p がまだ起動直後の場合は数秒待って再実行してください）" >&2
    exit 1
fi

echo "watching: $session_file" >&2

tail -n 50 -f "$session_file" | jq -r --unbuffered '
    if .type == "assistant" then
        .message.content[]?
        | if .type == "text" then "💬 " + .text
          elif .type == "tool_use" then
              "▶ " + .name + ": "
              + ((.input.command // .input.file_path // .input.description // "") | tostring | .[0:160])
          else empty end
    elif .type == "user" then
        .message.content[]?
        | select(type == "object" and .type == "tool_result" and .is_error == true)
        | "⚠ " + ((.content | tostring) | .[0:300])
    else empty end
'
