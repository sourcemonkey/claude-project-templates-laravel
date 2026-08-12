#!/usr/bin/env bash
#
# リポジトリ衛生の検査。**何も変更しない（読み取りのみ）。**
#
# 各フェーズの完了基準のうち、機械的に判定できるものを 1 回で検査する。
#   - .env / .env.example の存在と整合
#   - 生成物が .gitignore で除外されているか
#   - テンプレート同梱ファイルが意図せず変更されていないか
#   - 未追跡ファイルに生成物らしきものが残っていないか
#
# 使い方: プロジェクトルートで bin/check-repo.sh
#
#   終了コード 0 = 必須項目をすべて満たす（WARN が残っていてもよい）
#   終了コード 1 = 未達の必須項目がある
#
# 存在しないものは検査しない。フェーズ 1〜5 のどの時点でも同じコマンドで走る
# （Phase 2 の時点では coverage/ や .env.dusk.local がまだ無いのが正常）。
#
# set -e は使わない。失敗しうるコマンドを意図的に走らせて結果を分類するため。
set -uo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR" || exit 1

ng_count=0
warn_count=0

if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_NG=$'\033[31m'; C_OFF=$'\033[0m'
else
    C_OK=''; C_WARN=''; C_NG=''; C_OFF=''
fi

ok()   { printf '%s[OK]%s   %s\n' "$C_OK" "$C_OFF" "$1"; }
warn() { printf '%s[WARN]%s %s\n' "$C_WARN" "$C_OFF" "$1"; warn_count=$((warn_count + 1)); }
ng()   { printf '%s[NG]%s   %s\n' "$C_NG" "$C_OFF" "$1"; ng_count=$((ng_count + 1)); }
hint() { printf '        → %s\n' "$1"; }
skip() { printf '[--]   %s\n' "$1"; }

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "git リポジトリではありません: $APP_DIR" >&2
    exit 1
fi

echo "検査対象: $APP_DIR"
echo

# ---- .env / .env.example -------------------------------------------------
if [ ! -f .env ]; then
    skip ".env が未生成（Phase 1 の完了前は正常）"
else
    if git check-ignore -q .env; then
        ok ".env は .gitignore で除外されている"
    else
        ng ".env が .gitignore で除外されていない（APP_KEY が漏れる）"
        hint ".gitignore に .env を追加してください"
    fi

    if [ ! -f .env.example ]; then
        ng ".env.example が存在しない（clone 後の composer run setup が成立しない）"
    elif git check-ignore -q .env.example; then
        ng ".env.example が .gitignore で除外されている（追跡対象であるべき）"
        hint ".gitignore の !/.env.example を確認してください"
    else
        ok ".env.example は追跡対象"

        # 差分は APP_KEY の 1 行だけが正常。それ以外が出たら同期漏れ
        diff_lines="$(diff .env .env.example | grep -c '^[<>]')"
        key_lines="$(diff .env .env.example | grep -c '^[<>].*APP_KEY')"
        if [ "$diff_lines" -eq 0 ]; then
            ok ".env と .env.example は同一"
        elif [ "$diff_lines" -eq "$key_lines" ]; then
            ok ".env と .env.example の差分は APP_KEY のみ"
        else
            ng ".env と .env.example に APP_KEY 以外の差分がある（$diff_lines 行）"
            hint "diff .env .env.example で確認し、.env.example 側を同期してください"
        fi
    fi
fi

# ---- 生成物が .gitignore で除外されているか ------------------------------
# 存在するものだけ検査する（フェーズによって生成される時期が違うため）
#
# 2 種類あることに注意:
#   - パス自体が除外されるべきもの（vendor/ など）
#   - **中身だけ**が除外されるべきもの（Dusk が作る tests/Browser/* は、
#     ディレクトリ自身と中の .gitignore は追跡し、中身を除外する規約。
#     ディレクトリを check-ignore に掛けると「除外されていない」と誤判定する）
artifacts="vendor node_modules public/hot storage/pail .phpunit.result.cache .mcp.json boost.json coverage .env.dusk.local"
content_only="tests/Browser/screenshots tests/Browser/console tests/Browser/source"

missing_ignore=""
checked=0
for path in $artifacts; do
    [ -e "$path" ] || continue
    checked=$((checked + 1))
    if ! git check-ignore -q "$path"; then
        missing_ignore="$missing_ignore $path"
    fi
done

for path in $content_only; do
    [ -d "$path" ] || continue
    checked=$((checked + 1))
    # 実在しないダミーパスでよい。check-ignore はパターン照合のみを行う
    if ! git check-ignore -q "$path/.probe"; then
        missing_ignore="$missing_ignore $path/（中身）"
    fi
done

if [ "$checked" -eq 0 ]; then
    skip "生成物がまだ存在しない（Phase 1 の完了前は正常）"
elif [ -z "$missing_ignore" ]; then
    ok "生成物 $checked 件はすべて .gitignore で除外されている"
else
    ng "以下の生成物が .gitignore で除外されていない:$missing_ignore"
    hint ".gitignore に追加してください（コミットに生成物が混入します）"
fi

# ---- テンプレート同梱ファイルの変更 --------------------------------------
# フェーズ中に docs/ や CLAUDE.md を直す運用があるため、変更＝異常ではない。
# 意図した変更かを人が判断できるよう一覧するに留める。
template_paths=".gitignore .npmrc .tool-versions CLAUDE.md compose.yaml docker docs .claude config/boost.php .ai"
existing=""
for p in $template_paths; do
    [ -e "$p" ] && existing="$existing $p"
done

changed=""
if [ -n "$existing" ]; then
    changed="$(git status --porcelain -- $existing 2>/dev/null)"
fi

if [ -z "$changed" ]; then
    ok "テンプレート同梱ファイルに変更なし"
else
    warn "テンプレート同梱ファイルに変更あり（意図したものか確認してください）"
    printf '%s\n' "$changed" | while IFS= read -r line; do
        printf '        %s\n' "$line"
    done
fi

# ---- 未追跡ファイルに生成物らしきものが残っていないか --------------------
# .gitignore の網羅漏れを名前で拾う。上の artifacts リストに無い新種を検出するため。
# -uall が要る: 既定の git status は未追跡ディレクトリを 1 行に畳むため、
# 中のファイル名（hot / *.cache 等）が見えず検出できない
suspicious="$(git status --porcelain -uall -- . 2>/dev/null \
    | sed -n 's/^?? //p' \
    | grep -E '(^|/)(vendor|node_modules|coverage)/|(^|/)hot$|\.cache$|\.log$|(^|/)pail/' || true)"

if [ -z "$suspicious" ]; then
    ok "未追跡ファイルに生成物らしきものは無い"
else
    ng "生成物らしき未追跡ファイルがある:"
    printf '%s\n' "$suspicious" | while IFS= read -r line; do
        printf '        %s\n' "$line"
    done
    hint ".gitignore への追加が漏れています"
fi

# ---- まとめ --------------------------------------------------------------
echo
if [ "$ng_count" -eq 0 ]; then
    if [ "$warn_count" -eq 0 ]; then
        echo "リポジトリ衛生の項目をすべて満たしています。"
    else
        echo "必須項目はすべて満たしています（警告 $warn_count 件）。"
    fi
    exit 0
fi

echo "未達の必須項目が $ng_count 件あります。"
exit 1
