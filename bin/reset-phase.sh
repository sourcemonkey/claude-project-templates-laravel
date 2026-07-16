#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/my-laravel-app"

PHASE="${1:-}"

usage() {
  echo "使い方: bin/reset-phase.sh <phase番号>" >&2
  echo "  例: bin/reset-phase.sh 1" >&2
}

if [ -z "$PHASE" ]; then
  usage
  exit 1
fi

echo "=== Phase ${PHASE} リセット ==="

case "$PHASE" in
  1)
    # 1. 開発サーバー停止
    echo ">> 開発サーバーを停止..."
    pkill -f "php artisan serve" 2>/dev/null || true
    pkill -f "artisan queue:listen" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true

    # 2. DB コンテナ・ボリューム破棄
    echo ">> Docker コンテナ・ボリュームを破棄..."
    docker compose -f "$APP_DIR/compose.yaml" down -v 2>/dev/null || true

    # 3. Laravel 生成ファイルを削除（gitignore 対象含む）
    #    Phase 1 のリセットはテンプレート同梱状態（Laravel 未生成）まで
    #    完全に巻き戻す。Phase 2 以降は「直前のフェーズ完了時点」まで
    #    戻す必要があるため、別のケースとして追加する。
    echo ">> 未追跡ファイルを削除..."
    git -C "$REPO_ROOT" clean -fdx "$APP_DIR/"

    # 4. テンプレートファイルへの変更を復元
    echo ">> テンプレートファイルを復元..."
    git -C "$REPO_ROOT" checkout -- "$APP_DIR/"
    ;;
  *)
    echo "Phase ${PHASE} 用のリセット処理は未実装です。" >&2
    usage
    exit 1
    ;;
esac

echo ""
echo "✅ リセット完了。${APP_DIR#$REPO_ROOT/} は Phase ${PHASE} 実行前の状態に戻りました。"
