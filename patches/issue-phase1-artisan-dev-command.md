# composer.json の dev スクリプトが `concurrently` 直書きから `php artisan dev` 委譲に変わっている

- フェーズ: Phase 1
- 状態: 未分類
- 初回観測: 2026-08-12
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase1-skeleton.md` の Step 8 は、`laravel new` 既定の `composer.json` の
`scripts.dev` が `npx concurrently -c "..." "php artisan serve" "php artisan pail --timeout=0"
"php artisan queue:listen ..." "npm run dev" --names=...` という 4 プロセス直書きの配列である
前提で、そこから `queue` に対応する要素（コマンド・`--names`・色指定）を手で削除するよう指示している。

しかし今回 `laravel new tmp-skeleton --no-interaction --pest` で生成された `composer.json`
（`laravel/framework: ^13.17`）の `scripts.dev` は次の形だった。

```json
"dev": [
    "Composer\\Config::disableProcessTimeout",
    "@php artisan dev"
]
```

`concurrently` を直接呼ぶ配列ではなく、Laravel 本体に新規追加された `php artisan dev`
（`Illuminate\Foundation\Console\DevCommand`）に委譲する形になっている。起動するプロセスの
一覧はコード側（`Illuminate\Foundation\DevCommands::registerDefaults()`）が
`server` / `queue` / `logs` / `vite` の 4 つを登録しており、`composer.json` の文字列を
編集しても queue プロセスは消えない（`dev` スクリプト自体に `queue:listen` という
文字列が最初から存在しないため、Step 8 の「削除する」という操作自体が対象を持たない）。

## 根拠

生成直後の `composer.json`（抜粋）:

```json
"dev": [
    "Composer\\Config::disableProcessTimeout",
    "@php artisan dev"
]
```

`php artisan dev:list` の出力（除外前）:

```
 server php artisan serve Illuminate\Foundation\Providers\ArtisanServicePro…
 queue php artisan queue:listen --tries=1 --timeout=0 Illuminate\Foundatio…
 logs php artisan pail --timeout=0 Illuminate\Foundation\Providers\Artisa…
 vite npm run dev Illuminate\Foundation\Providers\ArtisanServiceProvider@…

 Showing [4] dev commands
```

`vendor/laravel/framework/src/Illuminate/Foundation/DevCommands.php` に
`DevCommands::except(...$names)` という、除外する dev コマンド名を静的に設定する API がある
（`only()` の対も存在）。呼び出し元のサービスプロバイダの `boot()` で呼べば
`php artisan dev` / `composer run dev` の対象から除外できることを確認した。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:327-336`
  （Step 8 の `scripts.dev` 変更手順）

## なぜ自動で直さなかったか

「実行モデル」節の規則により、Sonnet 系セッションは判断を伴う手順書修正を行わない
（`--model sonnet` 相当として制限側に倒す）。加えてこれは「共通の進め方」手順 4 の
「バージョン・環境の陳腐化」に該当し、そもそも Opus 系であっても即断で手順書を
書き換えてよい性質のものではなく、方針判断（下記選択肢参照）が要ると考えた。

## 選択肢

1. **`app/Providers/AppServiceProvider.php::boot()` に `DevCommands::except('queue');` を追記する
   手順へ Step 8 を書き換える** — 影響: `composer.json` の `dev` 配列自体は `laravel new` の
   既定のまま触らずに済む（`@php artisan dev` のまま）。懸念: `laravel/framework` の
   マイナーバージョンが上がった際、`DevCommands` の API（`except`/`only` の名前・シグネチャ）が
   変わる可能性があり、今回ほど手厚く追従できるかは未知数。将来 Laravel が `dev` コマンド自体を
   さらに変える可能性もある
2. **`composer.json` の `dev` スクリプトを手順書の想定どおり `concurrently` 直書きに戻す**
   （`"dev": ["Composer\\Config::disableProcessTimeout", "npx concurrently -c \"...\" \"php
   artisan serve\" \"php artisan pail --timeout=0\" \"npm run dev\" --names=server,logs,vite
   --kill-others"]` に上書き） — 影響: 手順書を変更せずに済む。懸念: `laravel new` の最新の
   既定から意図的に逸脱することになり、Laravel 側の `dev` コマンドが持つ再起動・カラー・
   TUI などの機能を手放すことになる。将来のマイナーアップデートで `laravel new` の既定が
   さらに変わったとき、この巻き戻しが再び陳腐化する

## 推奨

案 1。`php artisan dev` は Laravel 本体の新機能であり、「同梱の正規機能を使う」という
本プロジェクトの他の方針（`composer run dev` / `composer run setup` を自前スクリプトで
置き換えない、等）と整合する。案 2 は独自パッチを維持するコストが増える。

## 決めてほしいこと

Step 8 の「`scripts.dev` から queue 要素を削除する」手順を、
「`AppServiceProvider::boot()` に `DevCommands::except('queue');` を追記する」手順へ
書き換えてよいか（案 1 で進めてよいか、それとも案 2 か）。

## 暫定対応

このトライアルでは Phase 1 を完走させるため、案 1 の内容を `my-laravel-app/app/Providers/AppServiceProvider.php`
に実装した（`use Illuminate\Foundation\DevCommands;` を追加し、`boot()` に
`DevCommands::except('queue');` を追記）。`php artisan dev:list` で `queue` が除外されることを
確認済み。**ただしこの変更は `my-laravel-app/` のフェーズ成果物であり、`bin/reset-phase.sh`
でリセットされる**（テンプレート本体には入っていない）。次回このフェーズを実行するセッションは
同じ問題に再度遭遇する。
