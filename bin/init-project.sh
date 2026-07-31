#!/usr/bin/env bash
#
# init-project.sh
#
# Phase 4 まで完了した状態のテンプレートリポジトリから、
# 「開発用リポジトリ」として独立した git リポジトリを初期化する。
#
# **開発用リポジトリでは my-laravel-app/ がルートになる**。本番で運用するのは
# Laravel アプリそのものであり、prompts/ や patches/、bin/reset-phase.sh（アプリを
# 破棄するスクリプト）はテンプレート開発の道具でしかないため持ち込まない。
#
# 出来上がる構造:
#   <コピー先>/           ← git init されるルート。composer.json はここ
#   ├── CLAUDE.md         ← アプリ固有 + ルート CLAUDE.md の carry-over 範囲
#   ├── team-rules/       ← チーム共通ルール（CLAUDE.md が @ 参照）
#   ├── docs/  app/  config/  ...
#   └── composer.json
#
# 使い方:
#   bash bin/init-project.sh
#
# 設計上の前提:
#   - このスクリプトはテンプレートリポジトリの直下（bin/ 配下）に置かれ、
#     リポジトリのルートからの相対パスで自分の位置を解決する
#   - **必ず別ディレクトリへコピーする**。同一ディレクトリ内で階層を持ち上げる方式は
#     途中で失敗すると復旧できないため採らない（コピー元は無傷で残す）
#   - コピー先に既にファイルが存在する場合は中止する（上書きしない）

set -Eeuo pipefail

# ---- 共通ユーティリティ ---------------------------------------------------

color_red()    { printf '\033[31m%s\033[0m' "$*"; }
color_green()  { printf '\033[32m%s\033[0m' "$*"; }
color_yellow() { printf '\033[33m%s\033[0m' "$*"; }
color_cyan()   { printf '\033[36m%s\033[0m' "$*"; }

info()  { printf '%s %s\n' "$(color_cyan '[info]')"  "$*"; }
warn()  { printf '%s %s\n' "$(color_yellow '[warn]')" "$*"; }
error() { printf '%s %s\n' "$(color_red '[error]')"   "$*" >&2; }
ok()    { printf '%s %s\n' "$(color_green '[ok]')"    "$*"; }

abort() {
  error "$*"
  exit 1
}

# `~` を展開する（変数展開時の `~` は展開されないため）
expand_tilde() {
  local path="$1"
  # `${path#~/}` の ~ はパターン中のリテラル '~' を意味し、ホームディレクトリへの
  # 展開ではない（意図的）。SC2088 を抑制する。
  # shellcheck disable=SC2088
  case "$path" in
    "~")    printf '%s' "$HOME" ;;
    "~/"*)  printf '%s' "$HOME/${path#~/}" ;;
    *)      printf '%s' "$path" ;;
  esac
}

# 必須コマンドの存在チェック
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || abort "必要なコマンドが見つかりません: $1"
}

# ---- リポジトリルートの特定 -----------------------------------------------

# スクリプトが bin/init-project.sh に置かれている前提で、リポジトリルートを算出
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 想定構造の簡易チェック（テンプレ由来のファイル群がそろっているか）
check_repo_root() {
  local missing=()
  for f in CLAUDE.md my-laravel-app/CLAUDE.md my-laravel-app/docs my-laravel-app/.claude; do
    [ -e "$REPO_ROOT/$f" ] || missing+=("$f")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    error "テンプレートのルートとして想定されるファイルが見つかりません:"
    for f in "${missing[@]}"; do
      printf '  - %s/%s\n' "$REPO_ROOT" "$f" >&2
    done
    abort "このスクリプトはテンプレートリポジトリ直下の bin/ に配置されている前提です。"
  fi
}

# ---- コピー先パスの入力 --------------------------------------------------

prompt_destination() {
  local input
  while true; do
    cat <<EOF

コピー先のパスを入力してください。
  - 絶対パス  例: /Users/you/work/your-new-project
  - ~ 起点    例: ~/work/your-new-project

EOF
    read -r -p "コピー先: " input
    [ -n "$input" ] || { warn "空欄は不可です"; continue; }

    input="$(expand_tilde "$input")"

    # 相対パスは受け付けない（事故防止）
    case "$input" in
      /*) ;;
      *)  warn "絶対パスまたは ~ 起点で指定してください: $input"; continue ;;
    esac

    # 既存ディレクトリかつ空でない、または既存ファイルなら中止
    if [ -e "$input" ]; then
      if [ -d "$input" ]; then
        if [ -n "$(ls -A "$input" 2>/dev/null)" ]; then
          error "指定パスは既にファイルを含むディレクトリです: $input"
          warn  "誤上書きを避けるため中止します。空のディレクトリ、または存在しないパスを指定してください。"
          exit 1
        fi
      else
        error "指定パスは既存ファイルです: $input"
        exit 1
      fi
    fi

    # コピー元と同一パスは禁止（テンプレートリポジトリ自身を上書きしてしまうため）
    if [ "$input" = "$REPO_ROOT" ]; then
      warn "テンプレートリポジトリ自身は指定できません。別のディレクトリを指定してください。"
      continue
    fi

    DEST="$input"
    return
  done
}

# ---- 確認プロンプト -------------------------------------------------------

confirm_or_abort() {
  local msg="$1"
  local answer
  read -r -p "$msg [y/N]: " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) abort "中止しました" ;;
  esac
}

# ---- コピーして初期化 ----------------------------------------------------
#
# 開発用リポジトリでは **my-laravel-app/ がリポジトリのルートになる**（本番で運用
# するのは Laravel アプリそのものであり、prompts/ や patches/、bin/reset-phase.sh は
# テンプレート開発の道具でしかないため）。したがって単純な全体コピーではなく、
#
#   my-laravel-app/*  → コピー先の直下
#   team-rules/       → そのまま（CLAUDE.md が @ 参照している）
#   CLAUDE.md         → アプリの CLAUDE.md + ルート CLAUDE.md の carry-over 範囲
#
# という再配置を行う。テンプレート専用のもの（prompts/ patches/ bin/ ルート README・
# ルート .claude/settings.json・env.example）は持ち込まない。

run_copy() {
  info "コピー元: $REPO_ROOT/my-laravel-app（＋ team-rules / CLAUDE.md）"
  info "コピー先: $DEST（ここが新しいリポジトリのルートになります）"
  confirm_or_abort "実行してよいですか?"

  mkdir -p "$DEST"

  # 1) my-laravel-app/ の中身をコピー先の直下へ
  #
  # 除外するもの:
  #   .claude/settings.local.json        — ユーザー個別の承認履歴
  #   CLAUDE.local.md                    — 個人ローカルメモ
  #   node_modules / vendor / storage/logs — 再生成可能（コピー時間短縮。setup で復元される）
  #
  # 除外しないもの（重要）:
  #   .env                               — Laravel の起動に必須（APP_KEY 含む）。git では .gitignore で除外される
  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude='.claude/settings.local.json' \
      --exclude='CLAUDE.local.md' \
      --exclude='node_modules/' \
      --exclude='vendor/' \
      --exclude='storage/logs/' \
      "$REPO_ROOT"/my-laravel-app/ "$DEST"/
  else
    warn "rsync が無いため tar でコピーします"
    ( cd "$REPO_ROOT/my-laravel-app" && tar -cf - \
        --exclude='./.claude/settings.local.json' \
        --exclude='./CLAUDE.local.md' \
        --exclude='./node_modules' \
        --exclude='./vendor' \
        --exclude='./storage/logs' \
        . ) | ( cd "$DEST" && tar -xf - )
  fi

  # 2) team-rules/ をそのまま持ち込む（CLAUDE.md が @ 参照している）
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$REPO_ROOT"/team-rules/ "$DEST"/team-rules/
  else
    mkdir -p "$DEST/team-rules"
    ( cd "$REPO_ROOT/team-rules" && tar -cf - . ) | ( cd "$DEST/team-rules" && tar -xf - )
  fi

  # 3) CLAUDE.md を合成する
  #    アプリの CLAUDE.md（プロジェクト固有）＋ ルート CLAUDE.md の carry-over 範囲
  #    （@team-rules 参照・厳守事項・コミュニケーション）。マーカー外はテンプレート
  #    開発専用なので持ち込まない。
  {
    cat "$REPO_ROOT/my-laravel-app/CLAUDE.md"
    printf '\n'
    sed -n '/<!-- carry-over:start -->/,/<!-- carry-over:end -->/p' "$REPO_ROOT/CLAUDE.md" \
      | grep -v '<!-- carry-over:'
  } > "$DEST/CLAUDE.md"

  ok "コピー完了: $DEST"
  info "配置: my-laravel-app/ の中身が直下に展開され、team-rules/ と統合済み CLAUDE.md が置かれました"

  init_git_repo "$DEST"
}

# ---- 共通: git init から初回コミットまで ----------------------------------

init_git_repo() {
  local dir="$1"

  cd "$dir"

  info "git リポジトリを初期化します: $dir"
  git init --initial-branch=main >/dev/null

  # ユーザ設定が無いと commit 出来ないため事前チェック
  if [ -z "$(git config user.email || true)" ] || [ -z "$(git config user.name || true)" ]; then
    warn "git の user.name / user.email が未設定です。"
    warn "コミット前に設定してください:"
    warn "  git -C \"$dir\" config user.name  \"Your Name\""
    warn "  git -C \"$dir\" config user.email \"you@example.com\""
    warn "設定後、以下を実行すれば初回コミットが作れます:"
    warn "  cd \"$dir\" && git add . && git status && git commit -m 'chore: initial scaffold (template + phase 1-4)'"
    return
  fi

  git add .

  # 秘密情報の取り込みチェック（簡易）
  if git diff --cached --name-only | grep -E '(^|/)\.env$' >/dev/null; then
    error "秘密情報と思われるファイルがコミット候補に含まれています:"
    git diff --cached --name-only | grep -E '(^|/)\.env$' >&2
    warn "中止します。.gitignore を確認してください。"
    exit 1
  fi

  info "コミット対象のファイル一覧（先頭 30 件）:"
  git diff --cached --name-only | head -n 30
  local total
  total="$(git diff --cached --name-only | wc -l | tr -d ' ')"
  info "合計 ${total} ファイル"

  confirm_or_abort "この内容で初回コミットしますか?"
  git commit -m "chore: initial scaffold (template + phase 1-4)" >/dev/null
  ok "初回コミット完了"

  cat <<EOF

次のステップ:

  1) GitHub などにリモートリポジトリを作成
  2) cd "$dir"
  3) git remote add origin git@github.com:your-org/your-new-project.git
  4) git push -u origin main

EOF
}

# ---- main ----------------------------------------------------------------

main() {
  require_cmd git
  check_repo_root
  prompt_destination
  run_copy
}

main "$@"
