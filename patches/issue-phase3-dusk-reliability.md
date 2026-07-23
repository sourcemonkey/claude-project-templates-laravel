# Phase 3 の Dusk 手順（signInAs / 確認ダイアログ / serve）が複数テスト実行で不安定

- フェーズ: Phase 3（Phase 4 で Dusk が 7 件以上になった時点で顕在化）
- 状態: 未解決
- 初回観測: 2026-07-23

## 何が起きたか

`scaffold-phase3-ui.md` の Dusk 手順どおりに実装したところ、**Dusk が 5 件のうちは
安定して green だったが、Phase 4 で 8 件に増えた途端、実行ごとに別々のテストが落ちる
フレーキーな状態**になった。落ちるのは常にハイドレーション（Livewire / Alpine の JS
初期化）を待たずに操作した箇所で、根本原因は 3 つある。いずれも手順書の記述どおりに
書くと踏む。

### 1. `signInAs` が Livewire ロード前に press してしまう

手順書の `signInAs`（`tests/Pest.php` の Functions 節）は次の形:

```php
$browser->logout()
    ->visit('/login')
    ->type('email', $user->email)
    ->type('password', 'password123')
    ->press('ログイン')
    ->waitForLocation('/');
```

Breeze のログインフォームは Livewire コンポーネント。`livewire.js` のロード前に
`press('ログイン')` すると **Livewire ハンドラではなくネイティブ submit** になり、
アクション属性の無いフォームが空の値で `/login` にリロードされる。結果
`waitForLocation('/')` が `Waited 5 seconds for location [/].` でタイムアウトする。
失敗時のスクリーンショットは**メール欄が空のログイン画面**（typed 値が消えている）。

### 2. 確認ダイアログ（承認 / 返却 / 削除）が Alpine ロード前に発火しない

手順書の確認ダイアログ手順（`->press('削除')->waitForDialog()->acceptDialog()`）は、
`window.Alpine` のロード前に press すると `x-on:submit` が未束縛のため確認ダイアログが
出ず、`Waited 5 seconds for dialog.` で落ちる。手順書はこの症状の原因として「フォームに
`x-data` が無い」「Alpine が読み込まれていない（@livewireScripts 漏れ）」の 2 つを挙げて
いるが、**どちらも満たしていても、ハイドレーション完了前に press すれば同じ症状になる**。
このケースが 3 番目の原因として抜けている。

### 3. `php artisan serve` がテスト DB を指していない

手順書の Dusk 前提は「`php artisan serve` で APP_URL が応答していること」だが、
**素の `php artisan serve` は `.env`（開発用 `bookkeeper`）を読む**。一方 Dusk の
テストプロセスは `.env.dusk.local`（`bookkeeper_test`）で truncate / seed するため、
ブラウザが叩くサーバーとテストが作るデータの **DB が食い違い**、データが見えずに
落ちる。`php artisan serve --env=dusk.local` で起動すればサーバーも `bookkeeper_test`
を読み、一致する（本トライアルではこれで全 8 件が安定 green になった）。

## 根拠

- 5 件時: green。8 件（Phase 4 で return / 書籍 CRUD / 他人の貸出リダイレクトを追加）で
  1〜2 件が実行ごとに落ちる。エラーは `Waited 5 seconds for location [/].` /
  `Waited 5 seconds for dialog.`。
- 暫定対応（下記）を入れた後は **2 回連続で 8/8 green**。
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md`（signInAs 定義・
  「confirm ダイアログを伴う操作」節・「Dusk 実行時の前提」節）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「権限・ツール制約で検証しきれなかった / `.claude/` 配下は
patches 経由」に該当する。修正先の `scaffold-phase3-ui.md` はヘッドレスでは書き込めず、
かつ「どの待ち方を正とするか（`waitUntil` か `loginAs` 併用か pause か）」に方針判断が
ある。

## 選択肢

1. **手順書の signInAs と確認ダイアログ手順に「ハイドレーション待ち」を足す**（暫定対応で
   採用した形）。影響: 最小の差分で手順書のパターンを維持できる / 懸念: `waitUntil` の
   スクリプト依存（`window.Livewire` / `window.Alpine`）が Livewire・Alpine のバージョンに
   結びつく。
2. **ログインフォームを使うテストを 1 件に絞り、他は Dusk 標準の `loginAs($user)` で
   セッションを張る**。影響: ログインの UI テスト以外からハイドレーション競合を排除でき
   最も安定 / 懸念: 手順書の signInAs 前提から離れ、テストの書き方が変わる。

## 推奨

案 1。手順書のパターン（ログイン動線も Dusk で通す）を保ったまま最小差分で安定する。
`serve --env=dusk.local` は独立した明確な修正なので併せて反映する。

## 決めてほしいこと

案 1（手順書の signInAs・確認ダイアログ手順にハイドレーション待ちを追記し、Dusk 前提の
`serve` を `serve --env=dusk.local` に直す）で反映してよいか。

## 暫定対応

`my-laravel-app` 側（`tests/Pest.php` / 各 Dusk テスト、いずれも git 管理外の生成物）に
次を入れて全 8 件を安定 green にした。**手順書へ反映したら不要（生成物なのでリセットで
消える）**:

- `signInAs`: `->visit('/login')` の直後に
  `->waitUntil('window.Livewire')->waitForInput('email')` を追加
- 承認 / 返却 / 書籍削除の各テスト: 確認ダイアログを出す `press()` の直前に
  `->waitUntil('window.Alpine')` を追加
- Dusk 実行時のサーバー起動を `php artisan serve --env=dusk.local` にした
  （README のテスト節にもこの形で記載済み）
