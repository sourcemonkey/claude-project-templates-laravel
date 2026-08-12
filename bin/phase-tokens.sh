#!/usr/bin/env bash
#
# ヘッドレストライアル（claude -p "$(cat prompts/trial-phase.md)"）のトランスクリプトから、
# フェーズごとのトークン消費を集計して Markdown の表で出力する。
#
# 使い方:
#   bin/phase-tokens.sh                最新のトライアルセッションを集計
#   bin/phase-tokens.sh --all          複数セッションを横断して集計（bin/run-trial.sh 用）
#   bin/phase-tokens.sh <セッションID>  セッションを指定して集計
#   bin/phase-tokens.sh <path.jsonl>   トランスクリプトを直接指定
#   bin/phase-tokens.sh --list         候補セッションを新しい順に一覧
#
# フェーズの切り分けは、トライアルセッションが出力するマーカー
#   [phase-tokens] phase=<N> event=begin | end
# に依る（prompts/trial-phase.md の「共通の進め方」参照）。マーカーの無い区間は
# 「マーカー外」に集計される。
#
# 表は stdout、セッションのパスや警告は stderr に出るので、そのままリダイレクトして
# 報告へ貼り付けられる。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Claude Code のプロジェクトスラッグ: 絶対パスの / と . を - に置換したもの
SLUG="$(echo "$ROOT" | sed 's/[\/.]/-/g')"
TRANSCRIPT_DIR="$HOME/.claude/projects/$SLUG"

# ヘッドレスセッションの見分け方: 先頭付近の user メッセージに
# trial-phase.md の見出しがそのまま入っている（対話セッションには現れない）
MARKER="# フェーズトライアル自動化プロンプト"

# `head -5 "$1" | grep -q "$MARKER"` と書いてはいけない。マーカーは 1 行目にあるため
# grep -q が即座に終了し、head が残りの行（プロンプト全文を含み 1 行 40KB を超える）を
# 書こうとした時点で SIGPIPE で死ぬ。set -o pipefail によりパイプライン全体が非 0 になり、
# **マッチしているのに不一致と判定してスキップし、古いセッションを拾う**。
is_trial() {
    case "$(head -5 "$1")" in
        *"$MARKER"*) return 0 ;;
        *) return 1 ;;
    esac
}

list_sessions() {
    for f in $(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null); do
        if is_trial "$f"; then
            echo "$(date -r "$f" '+%Y-%m-%d %H:%M')  $(basename "$f" .jsonl)"
        fi
    done
}

# 同一 message.id が content ブロックの数だけ重複記録され、各行が同じ usage を持つ。
# message.id で最初の 1 行だけを採用しないと数倍に膨らむ。
JQ_PROGRAM='
def n: if . == null then 0 else . end;

# 3 桁区切り（44 = ",")
def comma:
    tostring | explode | reverse | to_entries
    | map(if .key > 0 and (.key % 3) == 0 then [44, .value] else [.value] end)
    | flatten | reverse | implode;

def pad2: tostring | if length < 2 then "0" + . else . end;

def hms:
    if . == null then "-"
    else (. | floor) as $s
        | "\($s / 3600 | floor):\((($s % 3600) / 60 | floor) | pad2):\(($s % 60) | pad2)"
    end;

# 2026-08-05T11:44:27.010Z のようなミリ秒付きは fromdateiso8601 が受け付けない
def ts2num: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;

def zero: {calls: 0, input: 0, cc: 0, cr: 0, out: 0, peak: 0, first: null, last: null};

def add($u; $t):
    ((($u.input_tokens | n) + ($u.cache_creation_input_tokens | n) + ($u.cache_read_input_tokens | n)) as $ctx
    | .calls += 1
    | .input += ($u.input_tokens | n)
    | .cc += ($u.cache_creation_input_tokens | n)
    | .cr += ($u.cache_read_input_tokens | n)
    | .out += ($u.output_tokens | n)
    | .peak = ([.peak, $ctx] | max)
    | .first = (if .first == null then $t else ([.first, $t] | min) end)
    | .last = (if .last == null then $t else ([.last, $t] | max) end));

def cell($a): [
    ($a.calls | comma), ($a.input | comma), ($a.cc | comma), ($a.cr | comma),
    ($a.out | comma), (($a.input + $a.cc + $a.cr + $a.out) | comma), ($a.peak | comma)
];

[ .[] | select(.type == "assistant" and (.message.id != null)) ] as $rows
| (reduce $rows[] as $r (
    {seen: {}, cur: "マーカー外", labels: [], acc: {}, spans: {}};

    # 先に usage を現区間へ計上する。begin を出力した API 呼び出し自体は
    # そのフェーズの準備であり、フェーズ内の消費ではないため。
    (if .seen[$r.message.id] or ($r.message.usage == null) then .
     else
        .seen[$r.message.id] = true
        | .cur as $c
        | (if (.acc | has($c)) then . else .acc[$c] = zero | .labels += [$c] end)
        | .acc[$c] |= add($r.message.usage; ($r.timestamp | ts2num))
     end)

    # マーカーは同一 message.id の別行に載ることがあるので重複排除の外で見る
    | ([$r.message.content[]? | select(.type == "text") | .text] | join("\n")) as $text
    | ([$text | match("\\[phase-tokens\\][ \t]*phase=([0-9]+)[ \t]*event=(begin|end)"; "g")]) as $ms
    | ($r.timestamp | ts2num) as $ts
    | reduce $ms[] as $m (.;
        ("Phase " + $m.captures[0].string) as $lab
        | if $m.captures[1].string == "begin"
          then .cur = $lab
             | .spans[$lab].start = ((.spans[$lab].start) // $ts)
          else .cur = "マーカー外"
             | .spans[$lab].end = $ts
          end)
)) as $st

| (($st.labels + ($st.spans | keys)) | map(select(startswith("Phase"))) | unique
   | sort_by(sub("^Phase "; "") | tonumber)) as $phases
| ($phases + ($st.labels | map(select(startswith("Phase") | not)))) as $order
| ($st.acc | to_entries | map(.value)
   | reduce .[] as $a (zero;
        .calls += $a.calls | .input += $a.input | .cc += $a.cc | .cr += $a.cr
        | .out += $a.out | .peak = ([.peak, $a.peak] | max)
        | .first = (if .first == null then $a.first else ([.first, $a.first] | min) end)
        | .last = (if .last == null then $a.last else ([.last, $a.last] | max) end))) as $total

| "| 区間 | API 呼び出し | input | cache 作成 | cache 読取 | output | 合計 | ピーク文脈 | 経過 |",
  "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
  ($order[] as $l
   | ($st.acc[$l] // zero) as $a
   | ($st.spans[$l] // {}) as $sp
   | "| \($l) | " + (cell($a) | join(" | "))
     + " | " + (if $sp.start != null and $sp.end != null then (($sp.end - $sp.start) | hms)
                elif ($l | startswith("Phase")) and $a.first != null then (($a.last - $a.first) | hms)
                else "-" end) + " |"),
  ("| **合計** | " + (cell($total) | join(" | "))
   + " | " + (if $total.first != null then (($total.last - $total.first) | hms) else "-" end) + " |")
'

# 「経過」列はフック（PreToolUse の待機など）による停止時間を含む。作業時間の
# 指標として読まないこと。実測（2026-08-06）では Phase 3 の経過 4:44:31 のうち
# 4:16 が limit-guard.sh による 5 時間枠のリセット待ちで、実作業は約 30 分だった。
elapsed_note() {
    echo "※ 「経過」はフックの待機時間を含む。作業時間の指標ではない。" >&2
}

if [ "${1:-}" = "--list" ]; then
    list_sessions
    exit 0
fi

# --all: 複数セッションを横断して 1 枚の表にまとめる。bin/run-trial.sh は
# フェーズごとに別セッションで起動するため、既定の自動検出（最新 1 本）では
# 最後のフェーズしか見えない。
#
# **新しい順にたどり、既に集めたフェーズと重なるセッションが現れた時点で打ち切る。**
# そこが前回の実行との境目だからである。
#
# **重なりだけでは足りない。** `bin/run-trial.sh 1 2` のように範囲を絞って実行すると、
# 前回ランの Phase 3 は「まだ集めていないフェーズ」なので重ならず、そのまま採用されて
# しまう（2026-08-12 に発生。Phase 1〜2 の実行なのに合計へ前回の Phase 3 が入った）。
# `run-trial.sh` はフェーズを**連番でしか実行しない**ため、番号の連続性も条件に加える。
#
# 「フェーズごとに最新のセッションを採る」という採り方にしてはいけない。jq は
# **ファイル全体を処理する**ため、Phase 3 のために採用した古い通し実行のセッションから
# その Phase 1・2 まで一緒に集計され、**二重計上になる**（2026-08-07 に実際に起きた。
# Phase 1 が 69 + 66 = 135 呼び出しと表示された）。重なりで打ち切る形なら、
# 採用したセッション群のフェーズが重複しないことが構成上保証される。
if [ "${1:-}" = "--all" ]; then
    session_files=""
    collected=" "
    min_phase=""
    for f in $(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null); do
        is_trial "$f" || continue
        # マーカーが無ければ grep が非 0 を返す。set -e で落ちないよう吸収する
        phases="$(grep -o '\[phase-tokens\] *phase=[0-9]*' "$f" 2>/dev/null \
            | grep -o '[0-9]*$' | sort -u || true)"
        [ -n "$phases" ] || continue

        overlap=0
        for p in $phases; do
            case "$collected" in
                *" $p "*) overlap=1; break ;;
            esac
        done
        [ "$overlap" -eq 0 ] || break

        cand_max=""
        cand_min=""
        for p in $phases; do
            if [ -z "$cand_max" ] || [ "$p" -gt "$cand_max" ]; then cand_max="$p"; fi
            if [ -z "$cand_min" ] || [ "$p" -lt "$cand_min" ]; then cand_min="$p"; fi
        done

        # 2 本目以降は、直前に採ったセッションの最小フェーズの 1 つ手前を担当する
        # セッションでなければ別ランとみなして打ち切る
        if [ -n "$min_phase" ] && [ "$cand_max" -ne $((min_phase - 1)) ]; then
            break
        fi

        for p in $phases; do collected="$collected$p "; done
        min_phase="$cand_min"
        session_files="$f $session_files"
    done

    if [ -z "$session_files" ]; then
        echo "マーカーを持つトライアルセッションが見つかりません: $TRANSCRIPT_DIR" >&2
        exit 1
    fi

    # shellcheck disable=SC2086
    set -- $session_files
    echo "sessions: $# 本（最後の実行。フェーズが重なるか連番が途切れた手前で打ち切り）" >&2
    for f in "$@"; do
        p="$(grep -o '\[phase-tokens\] *phase=[0-9]*' "$f" | grep -o '[0-9]*$' | sort -u | tr '\n' ',' | sed 's/,$//')"
        echo "  $(basename "$f" .jsonl)  Phase $p" >&2
    done
    elapsed_note
    jq -s -r "$JQ_PROGRAM" "$@"
    exit $?
fi

session_file=""
if [ -n "${1:-}" ]; then
    if [ -f "$1" ]; then
        session_file="$1"
    elif [ -f "$TRANSCRIPT_DIR/$1.jsonl" ]; then
        session_file="$TRANSCRIPT_DIR/$1.jsonl"
    else
        echo "指定されたセッションが見つかりません: $1" >&2
        exit 1
    fi
else
    for f in $(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null); do
        if is_trial "$f"; then
            session_file="$f"
            break
        fi
    done
fi

if [ -z "$session_file" ]; then
    echo "トライアルセッションのトランスクリプトが見つかりません: $TRANSCRIPT_DIR" >&2
    echo "（bin/phase-tokens.sh --list で候補を確認できます）" >&2
    exit 1
fi

echo "session: $session_file" >&2

if ! grep -q '\[phase-tokens\] *phase=' "$session_file"; then
    echo "警告: [phase-tokens] マーカーが見つかりません。マーカー導入前のセッションか、" >&2
    echo "      トライアルが出力を忘れています。全区間が「マーカー外」に集計されます。" >&2
fi


elapsed_note
jq -s -r "$JQ_PROGRAM" "$session_file"
