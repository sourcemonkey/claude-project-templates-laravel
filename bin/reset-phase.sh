#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/my-laravel-app"
# git clean の除外パターン・表示用に使うリポジトリルートからの相対パス
APP_REL="${APP_DIR#"$REPO_ROOT"/}"

PHASE="${1:-}"

# リセット後に再実行すべきスラッシュコマンド名（フェーズ番号がキー）
declare -a PHASE_COMMANDS=(
  [1]="scaffold-phase1-skeleton"
  [2]="scaffold-phase2-models"
  [3]="scaffold-phase3-ui"
  [4]="scaffold-phase4-finalize"
)

usage() {
  echo "使い方: bin/reset-phase.sh <phase番号>" >&2
  echo "  例: bin/reset-phase.sh 1" >&2
}

if [ -z "$PHASE" ]; then
  usage
  exit 1
fi

echo "=== Phase ${PHASE} リセット ==="

# daemon 未接続だと docker compose down -v が黙って失敗し、stale ボリュームが
# 残ったまま「リセット完了」と誤報告してしまうため、先に接続を確認する
if ! docker info > /dev/null 2>&1; then
  echo "エラー: Docker daemon に接続できません。" >&2
  echo "Docker Desktop を起動してから再実行してください。" >&2
  exit 1
fi

# テンプレート同梱状態（Laravel 未生成）まで完全に巻き戻す共通処理。
#
# 設計メモ: 各フェーズの生成物（vendor / node_modules / .env / 生成された app 配下・
# マイグレーション、さらに Phase 2 以降が *変更* する User.php・tests/Pest.php・
# phpunit.xml 等）はいずれも git 管理外である。そのため「直前のフェーズ完了時点」を
# git だけで再現することはできず、決定論的に戻せる基準はテンプレート状態のみとなる。
# よって Phase 2 以降のリセットもテンプレート状態まで巻き戻し、トライアル側で
# 「Phase 1 → … → Phase (N-1)」を順に実行してから Phase N を実行する運用とする。
# （中間スナップショット方式にすれば Phase N 単体の巻き戻しも可能だが、vendor 込みの
#  スナップショットは重く運用も複雑になるため現状は採用しない。）
reset_to_template() {
  # 1. 開発サーバー停止
  echo ">> 開発サーバーを停止..."
  pkill -f "php artisan serve" 2>/dev/null || true
  pkill -f "artisan queue:listen" 2>/dev/null || true
  pkill -f "vite" 2>/dev/null || true

  # 2. DB コンテナ・ボリューム破棄
  echo ">> Docker コンテナ・ボリュームを破棄..."
  docker compose -f "$APP_DIR/compose.yaml" down -v 2>/dev/null || true

  # 3. Laravel 生成ファイルを削除（gitignore 対象含む）
  #    ただし個人ローカル設定（承認履歴・個人メモ）はリセットのたびに
  #    消えると蓄積・選別の運用が成り立たないため除外する。
  echo ">> 未追跡ファイルを削除..."
  # 除外パターンは先頭 / を付けてリポジトリルート基準の絶対パスで書く。
  # スラッシュを含まないパターン（例: 'settings.local.json'）は .gitignore と
  # 同じく任意階層にマッチするため、node_modules 配下の無関係な同名ファイル
  # （例: node_modules/resolve/.claude/settings.local.json）まで保護され、
  # node_modules ごと削除されずに残ってしまう。
  git -C "$REPO_ROOT" clean -fdx \
    -e "/$APP_REL/.claude/settings.local.json" \
    -e "/$APP_REL/CLAUDE.local.md" \
    "$APP_DIR/"

  # 4. テンプレートファイルへの変更を復元
  echo ">> テンプレートファイルを復元..."
  git -C "$REPO_ROOT" checkout -- "$APP_DIR/"
}

case "$PHASE" in
  1)
    reset_to_template
    echo ""
    echo "✅ リセット完了。${APP_REL} は Phase 1 実行前（Laravel 未生成）の状態に戻りました。"
    ;;
  2 | 3 | 4)
    reset_to_template
    PREV=$((PHASE - 1))
    echo ""
    echo "✅ リセット完了。${APP_REL} はテンプレート状態（Laravel 未生成）に戻りました。"
    echo ""
    if [ "$PREV" -eq 1 ]; then
      echo "ℹ️  Phase ${PHASE} のトライアルは Phase 1 完了状態が前提です。"
    else
      echo "ℹ️  Phase ${PHASE} のトライアルは Phase 1〜${PREV} 完了状態が前提です。"
    fi
    echo "   Phase 1 の生成物は git 管理外のため中間スナップショットが無く、リセットは"
    echo "   テンプレート状態まで巻き戻します。リセット後は次の順で実行してください:"
    # スラッシュコマンド名はフェーズごとに接尾辞が異なるため、実名を引いて案内する
    STEPS=""
    for i in $(seq 1 "$PHASE"); do
      [ -n "$STEPS" ] && STEPS="${STEPS} → "
      STEPS="${STEPS}/${PHASE_COMMANDS[$i]}"
    done
    echo "     ${STEPS}"
    ;;
  *)
    echo "Phase ${PHASE} は未対応です（1〜4 を指定してください）。" >&2
    usage
    exit 1
    ;;
esac
