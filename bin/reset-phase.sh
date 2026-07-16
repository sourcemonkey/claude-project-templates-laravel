#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/my-laravel-app"

echo "=== Phase リセット ==="

# 1. 開発サーバー停止
echo ">> 開発サーバーを停止..."
pkill -f "php artisan serve" 2>/dev/null || true
pkill -f "artisan queue:listen" 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true

# 2. DB コンテナ・ボリューム破棄
echo ">> Docker コンテナ・ボリュームを破棄..."
docker compose -f "$APP_DIR/compose.yaml" down -v 2>/dev/null || true

# 3. Laravel 生成ファイルを削除（gitignore 対象含む）
echo ">> 未追跡ファイルを削除..."
git -C "$REPO_ROOT" clean -fdx my-laravel-app/

# 4. テンプレートファイルへの変更を復元
echo ">> テンプレートファイルを復元..."
git -C "$REPO_ROOT" checkout -- my-laravel-app/

echo ""
echo "✅ リセット完了。my-laravel-app/ はフェーズ実行前の状態に戻りました。"
