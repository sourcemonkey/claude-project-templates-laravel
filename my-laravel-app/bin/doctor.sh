#!/usr/bin/env bash
#
# 開発環境の前提条件を検査する。**何も変更しない（読み取りのみ）。**
#
# 使い方: プロジェクトルートで bin/doctor.sh
#
#   終了コード 0 = 必須項目をすべて満たす（WARN が残っていてもよい）
#   終了コード 1 = 未達の必須項目がある。出力の「対処」に従って解消してから再実行する
#
# 設計方針:
#   - PHP / Node のバージョンは .tool-versions が一次情報。このスクリプトに数値を書かない
#   - DB のポート・コンテナ名・ボリューム名は compose.yaml から導出する。二重管理しない
#   - 判断を求めない。各項目は「満たす / 満たさない」と「対処」だけを出す
#
# set -e は使わない。失敗しうるコマンドを意図的に走らせて結果を分類するスクリプトのため。
set -uo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR" || exit 1

TOOL_VERSIONS="$APP_DIR/.tool-versions"
COMPOSE_FILE="$APP_DIR/compose.yaml"

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

# .tool-versions から指定ツールのバージョンを取り出す
tool_version() {
    awk -v tool="$1" '$1 == tool { print $2; exit }' "$TOOL_VERSIONS"
}

# major.minor が一致するか（パッチ差は許容して WARN に落とすため分けて判定する）
same_series() {
    [ "${1%.*}" = "${2%.*}" ]
}

# PHP 拡張の有無。`php -m | grep -q` は使わない: grep -q が最初のマッチで終了すると
# php 側が SIGPIPE で落ち、pipefail によりパイプライン全体が非 0 になる。一覧の
# 前方にある拡張ほど再現しやすく、「導入済みなのに未導入と報告する」形で偽陰性になる。
php_modules=""
if command -v php >/dev/null 2>&1; then
    php_modules="$(php -m 2>/dev/null | tr '[:upper:]' '[:lower:]')"
fi

has_php_module() {
    case $'\n'"$php_modules"$'\n' in
        *$'\n'"$1"$'\n'*) return 0 ;;
        *) return 1 ;;
    esac
}

echo "検査対象: $APP_DIR"
echo

# ---- .tool-versions 自体の存在 -------------------------------------------
if [ ! -f "$TOOL_VERSIONS" ]; then
    ng ".tool-versions が見つかりません: $TOOL_VERSIONS"
    hint "テンプレート同梱ファイルです。リポジトリの状態を確認してください"
    exit 1
fi

# ---- PHP -----------------------------------------------------------------
want_php="$(tool_version php)"
if ! command -v php >/dev/null 2>&1; then
    ng "PHP: 未インストール（.tool-versions の要求は ${want_php}）"
    hint "asdf / mise 等で php $want_php を導入してください"
else
    have_php="$(php -r 'echo PHP_VERSION;' 2>/dev/null)"
    # php -r を使わない形（許可リストの方針に合わせる。ここはスクリプト内なので影響しないが揃えておく）
    [ -n "$have_php" ] || have_php="$(php -v 2>/dev/null | awk 'NR==1 { print $2 }')"

    if [ "$have_php" = "$want_php" ]; then
        ok "PHP $have_php"
    elif same_series "$have_php" "$want_php"; then
        warn "PHP ${have_php}（.tool-versions は ${want_php}。パッチ差のみ）"
        hint "動作に支障が出ることは稀ですが、揃えるなら asdf / mise で $want_php を導入してください"
    else
        ng "PHP ${have_php}（.tool-versions は ${want_php}）"
        hint "asdf / mise 等で php $want_php を導入してください"
        hint "which -a php: $(command -v -a php 2>/dev/null | tr '\n' ' ')"
    fi
fi

# ---- PHP 拡張: zip（laravel/dusk v8.x が ext-zip を要求する）-------------
if command -v php >/dev/null 2>&1; then
    if has_php_module zip; then
        ok "PHP 拡張 zip"
    else
        ng "PHP 拡張 zip が無効（laravel/dusk が ext-zip を要求する）"
        hint "pecl install zip でビルドし、php --ini の conf.d 配下の ini に extension=zip.so を追記"
        hint "libzip が未導入なら先に brew install libzip"
        hint "※ ホストの PHP 全体に影響する変更です"
    fi
fi

# ---- PHP 拡張: pcov（Phase 5 のカバレッジ判定でのみ必要。中断しない）-----
if command -v php >/dev/null 2>&1; then
    if has_php_module pcov; then
        ok "PHP 拡張 pcov（カバレッジ計測）"
    else
        warn "PHP 拡張 pcov が未導入（カバレッジ判定にのみ必要）"
        hint "Phase 1〜4 は影響を受けません。Phase 5 に入る前に導入してください"
        hint "手順は docs/stack.md の「テストカバレッジ設定（正規形）」"
    fi
fi

# ---- Composer ------------------------------------------------------------
if ! command -v composer >/dev/null 2>&1; then
    ng "Composer: 未インストール（アプリ生成の composer create-project に必須）"
    hint "https://getcomposer.org/download/ から 2 系を導入してください"
else
    composer_ver="$(composer --version 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+\.[0-9]+/) { print $i; exit } }')"
    case "$composer_ver" in
        2.*) ok "Composer $composer_ver" ;;
        "")  ng "Composer: バージョンを判別できませんでした"
             hint "composer --version の出力を確認してください" ;;
        *)   ng "Composer ${composer_ver}（2 系が必要）"
             hint "composer self-update --2 で 2 系へ更新してください" ;;
    esac
fi

# ---- Node.js -------------------------------------------------------------
want_node="$(tool_version nodejs)"
if ! command -v node >/dev/null 2>&1; then
    ng "Node.js: 未インストール（.tool-versions の要求は ${want_node}）"
    hint "asdf / mise 等で nodejs $want_node を導入してください"
else
    have_node="$(node -v 2>/dev/null | sed 's/^v//')"
    if [ "$have_node" = "$want_node" ]; then
        ok "Node.js $have_node"
    else
        # バージョン不一致は npm run build 時の Vite ネイティブバインディング解決失敗につながる
        if same_series "$have_node" "$want_node"; then
            warn "Node.js ${have_node}（.tool-versions は ${want_node}。パッチ差のみ）"
        else
            ng "Node.js ${have_node}（.tool-versions は ${want_node}）"
            hint "不一致のまま進めると npm run build が Vite のネイティブバインディング解決に失敗することがあります"
        fi
        # .tool-versions は asdf / mise の形式。nodenv / nvm が PATH で先に解決すると無視される
        node_paths="$(command -v -a node 2>/dev/null | tr '\n' ' ')"
        hint "which -a node: $node_paths"
        case "$node_paths" in
            *nodenv*|*nvm*)
                hint "nodenv / nvm が併存しています。.tool-versions は asdf / mise の形式なので無視されます"
                hint "推奨: 併存しているマネージャを PATH から外し asdf / mise に一本化する"
                hint "代替: 優先されているマネージャ側で $want_node を入れ、プロジェクトにローカルピン留めする" ;;
        esac
    fi
fi

# ---- Docker --------------------------------------------------------------
docker_ready=0
if ! command -v docker >/dev/null 2>&1; then
    ng "Docker: 未インストール"
    hint "Docker Desktop か Docker Engine + Compose v2 を導入してください"
elif ! docker info >/dev/null 2>&1; then
    ng "Docker: インストール済みだがデーモンに接続できません"
    hint "Docker Desktop を起動してから再実行してください"
else
    ok "Docker デーモン"
    docker_ready=1

    if docker compose version >/dev/null 2>&1; then
        ok "Docker Compose v2（$(docker compose version --short 2>/dev/null)）"
    else
        ng "Docker Compose v2 が使えません（docker-compose の旧 v1 は対象外）"
        hint "Docker Desktop を更新するか Compose v2 プラグインを導入してください"
    fi
fi

# ---- DB ポートの空き -----------------------------------------------------
# ポート・コンテナ名は compose.yaml から導出する（数値をこのスクリプトに書かない）
db_port="$(sed -n 's/.*"127\.0\.0\.1:\([0-9]\{1,5\}\):[0-9]\{1,5\}".*/\1/p' "$COMPOSE_FILE" | head -1)"
db_container="$(awk -F': *' '/container_name:/ { print $2; exit }' "$COMPOSE_FILE" | tr -d '\r')"

if [ -z "$db_port" ]; then
    warn "compose.yaml から DB のホストポートを読み取れませんでした。ポート検査を省略します"
else
    port_user=""
    if ! command -v lsof >/dev/null 2>&1; then
        # 検査できないことを「空き」と報告しない
        warn "lsof が無いためポート $db_port の使用状況を確認できませんでした"
        hint "docker compose up -d --wait db が起動しない場合はポート競合を疑ってください"
        db_port=""
    else
        port_user="$(lsof -nP -iTCP:"$db_port" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 { print $1 }')"
    fi

    if [ -z "$db_port" ]; then
        : # 上で警告済み
    elif [ -z "$port_user" ]; then
        ok "ポート $db_port は空き"
    elif [ "$docker_ready" = "1" ] && [ -n "$db_container" ] \
        && [ -n "$(docker ps --filter "name=^${db_container}$" --quiet 2>/dev/null)" ]; then
        # 自プロジェクトの DB コンテナが掴んでいる状態は正常（2 回目以降の実行で必ずこうなる）
        ok "ポート $db_port は本プロジェクトの DB コンテナ（${db_container}）が使用中"
    else
        ng "ポート $db_port を別のプロセスが使用中（${port_user}）"
        hint "そのプロセスを停止するか、compose.yaml のホスト側ポートを変更してください"
    fi
fi

# ---- DB ボリュームの衝突 -------------------------------------------------
# Compose のプロジェクト名はディレクトリ名（basename）由来。同名ディレクトリが複数あると
# 同じボリュームを共有し、初期化済みデータが残って MYSQL_USER の作成がスキップされる
if [ "$docker_ready" = "1" ]; then
    volume_name="$(basename "$APP_DIR")_db-data"
    if [ -n "$(docker volume ls --filter "name=^${volume_name}$" --quiet 2>/dev/null)" ]; then
        warn "DB ボリューム $volume_name が既に存在します"
        hint "初回セットアップなら docker compose down -v で破棄してから始めてください"
        hint "（残っていると bookkeeper_test の作成と app ユーザーの権限付与がスキップされます）"
        hint "同名ディレクトリを並行して使う場合は COMPOSE_PROJECT_NAME を分けてください"
    else
        ok "DB ボリューム $volume_name は未作成（初回セットアップ可能な状態）"
    fi
fi

# ---- まとめ --------------------------------------------------------------
echo
if [ "$ng_count" -eq 0 ]; then
    if [ "$warn_count" -eq 0 ]; then
        echo "すべての項目を満たしています。"
    else
        echo "必須項目はすべて満たしています（警告 $warn_count 件）。"
    fi
    exit 0
fi

echo "未達の必須項目が $ng_count 件あります。上記の「→」の対処を行ってから再実行してください。"
exit 1
