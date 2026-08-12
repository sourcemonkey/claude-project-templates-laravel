# Phase 3 実行時に自分の判断で埋めた箇所の記録

- フェーズ: Phase 3
- 状態: 未分類
- 初回観測: 2026-08-12
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase3-ui.md` の手順に従って UI（Controller / View / Policy / Action）一式を実装した。
完了基準（`php artisan route:list` の全ルート存在、Policy 全リソース存在、Action 4 クラス存在、
レイアウト・`@livewireScripts`・`x-data`・Breeze 追従・`php artisan test` all green・
`vendor/bin/pint --test` 0 件・`vendor/bin/phpstan analyse --memory-limit=512M` 0 件）は
すべて満たした。詰まった箇所（エラーで手が止まった箇所）は無かった（ツール呼び出しは
すべて 1 回で成功し、`php artisan test` / `phpstan` / `pint --test` / `php artisan view:cache`
がいずれも一発で通った）。

一方、手順書・docs には記述が無く自分で決めた実装判断がいくつかある。フェーズ設計上の
欠陥ではなく通常の実装細部だが、「共通の進め方」手順 3 の要求に従い記録する。

## 根拠（自分の判断で埋めた箇所）

- **ランディングページ（`GET /`）の中身とレイアウト**: `docs/screens.md` は「ログイン誘導」としか
  書いておらず、使用レイアウトの指定が無い。`layouts/app.blade.php`（`x-app-layout`）を
  未ログイン状態でも使う設計にした（nav 側は `@auth`/`@guest` で分岐済み）。
  `resources/views/home.blade.php` に "BookKeeper" の文言を含めたのは、
  `tests/Browser/ExampleTest.php` の書き換え（手順書 39 行目以降で必須と指定）で
  参照する固定文言として選んだため。
- **蔵書検索（`app/Livewire/BookList.php`）のUI項目**: `docs/db-schema.md` の Spatie Query Builder
  対応表は Book の `allowedFilters` を title/author/publisher/isbn/description/published(admin
  only)/category_id/tags.id と定めるが、メンバー画面にどれを検索欄として出すかの指定は無い。
  title・author・category・tag の 4 つを UI に出し、publisher/isbn/description は
  `allowedFilters` には含めず UI からも省略した。
- **管理者の蔵書一覧検索項目**: 同様に `docs/screens.md` に検索項目の指定が無いため、
  title・author・published の 3 つのみを UI に出した（allowedFilters 自体はカテゴリ・タグの
  exact フィルタも登録済み）。
- **書籍編集フォームの `available_copies` の扱い**: `docs/db-schema.md` は
  「`available_copies` は 0 以上の整数」としか定めず、新規登録時にどう初期化するか、
  更新時に直接編集可能にするかの指定が無い。**新規登録時は `total_copies` と同値で自動設定**
  （フォームに入力欄を出さない）、**編集時のみ `available_copies` を直接編集可能**にし、
  `UpdateBookRequest` に `lte:total_copies` のバリデーションを追加した。
- **カテゴリ・タグ管理画面の編集 UI**: `docs/screens.md` は「作成・編集フォームは一覧画面内に
  置く」とだけ指定し、具体的な UI パターン（インライン編集か別行か）は指定が無い。
  各行に Alpine (`x-data="{ editing: false }"`) で表示・編集を切り替えるトグルを実装した。
- **`ProfilePolicy` の呼び出し**: `docs/architecture.md` の Policy セクションは
  `app(ProfilePolicy::class)->update($request->user(), $targetUser)` という呼び出しパターンを
  示すが、本仕様のルーティングには `/profile` に `{user}` パラメータが無く、`$targetUser` は
  常に `$request->user()` 自身になる（同一 ID 比較は常に true）。ドキュメントに明記された
  パターンをそのまま踏襲したが、実質的なチェックにはならない点は解釈の余地があった。
- **監査ログ一覧の操作者列**: `docs/db-schema.md` は `audit_logs.user_id` が nullable で
  「操作者が削除されてもログは残す」とあるが、画面上の表示方法は未指定。
  `$log->user?->name ?? '-'` で null 安全に表示する形にした。

## なぜ自動で直さなかったか

手順書・docs に誤りは無く（「共通の進め方」手順 4 の「その場で直す」対象ではない）、
かつ実装の初期値・UI 構成という**方針の選択**に当たるため、`--model sonnet` 実行時は
判断を伴うものをすべて `patches/` へ回す規則（「実行モデル」節）に従った。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

上記の実装判断（特にランディングページの内容、検索対象フィールドの絞り込み、
`available_copies` の編集可否）を `docs/screens.md` や `docs/db-schema.md` に明文化するか、
このまま実装依存の詳細として残すか。

## 暫定対応

上記の判断はすべて `my-laravel-app/` 側の実装（コミット対象外の使い捨て成果物）にのみ
反映されている。テンプレート本体（`docs/*.md` / `.claude/commands/*.md`）への変更は無い。
