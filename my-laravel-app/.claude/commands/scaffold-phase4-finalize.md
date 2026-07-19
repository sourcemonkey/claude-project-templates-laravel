---
description: フェーズ4 - Seeder、テスト、README、起動確認で完成させる
---

# Phase 4: 仕上げ（Seeder + テスト + 起動確認）

最終フェーズ。「最初から動くもの」を完成させる。投入データ・テストアカウント等の具体値は `docs/seeds.md` が一次情報。

## 実行手順

### 1. Seeder の実装

`docs/seeds.md` に記載されたデータ（アカウント、カテゴリ、タグ、書籍、貸出、通知、監査ログ）を、リソースごとの Seeder クラス（`UserSeeder`, `CategorySeeder`, `TagSeeder`, `BookSeeder`, `LendingSeeder`, `NotificationSeeder`, `AuditLogSeeder`）として実装し、`DatabaseSeeder` から FK 依存の順に `call()` する。

実装上の注意:

- すべて `firstOrCreate()` で冪等にする（複数回実行しても重複しない）
- 貸出（Lending）を作成する際、書籍の `available_copies` を整合的に更新する
- 「延滞」状態は Seeder で state を直接 `Overdue` に設定して良い
- `php artisan db:seed` で投入。エラー時は `migrate:fresh` する前に原因を報告
- Seeder 投入後、admin ダッシュボードで申請待ち件数・延滞件数が表示されることを確認する

### 2. 主要動線のシステムテスト

#### 2-0. カバレッジ計測の確認（テストを書く前に必ず実施）

**まず `php -m | grep pcov` でカバレッジ計測ドライバを確認する。出力が空の場合はここで中断し、`docs/stack.md` の「テストカバレッジ設定（正規形）」の導入手順を提示してユーザーに導入を依頼する**（PHP ランタイム全体に影響する変更のため、Claude Code の単独判断で `pecl install` や php.ini の編集を行わない）。カバレッジ 80% 以上は Phase 4 の完了基準であり、ドライバ無しでは達成を確認できないため、先にテストを書き進めても手戻りになる。

ドライバを確認できたら、`docs/stack.md` の「テストカバレッジ設定（正規形）」の通りに `phpunit.xml` を設定する。設定後、`php artisan test --coverage-html coverage` を一度実行して `coverage/index.html` が生成され、かつカバレッジが 0% でないことを確認してから次のステップへ進む。

#### 2-1. テストシナリオの実装

テストを書く前に、ボタン名・フィールド label の実際の文字列を対象の Blade / Livewire ファイルを Read して確認すること（`docs/screens.md` の「ボタン・ラベルの標準」とその注記参照）。

テスト実装上の注意:
- **Dusk の `select()` には `<option>` の `value` 属性を渡す**（表示テキストではない）。表示テキストで選択したい場合は `$browser->script(...)` を使わず、`selectByText()`（Dusk 3 系以降で利用可能な場合）の有無を確認して使う
- **承認済み貸出を使う返却テストでは、`Lending::factory()->approved()->create(...)` の前に `$book->update(['available_copies' => 1])` で在庫を確保すること**。Factory のトレイトは state のみ設定し `available_copies` は操作しないため、返却後に `available_copies > total_copies` になるケースでエラーになる。

`docs/screens.md` の主要動線を Dusk で網羅。網羅すべきシナリオ:

- メンバー: ログイン → 蔵書検索 → 詳細 → 借用申請 → 自分の貸出一覧で確認
- メンバー: 自分の貸出を返却
- 管理者: ログイン → 申請一覧 → 承認 → 通知が作られ在庫が減ること
- 管理者: 書籍 CRUD（作成 → 編集 → 削除）
- 認可: 非 admin が `/admin` にアクセスすると `home` へリダイレクトされる
- 認可: 他人の貸出詳細にアクセスすると `home` へリダイレクトされる（Policy）

### 3. bin/setup の確認

Phase 1 で作成済みの `bin/setup` が以下を一発で実行できることを確認する:

1. DB コンテナの起動と待機
2. `composer install` / `npm install`
3. `php artisan migrate --seed`

### 4. README.md の作成

`my-laravel-app/README.md` を新規作成。含めるべき項目:

- プロジェクト概要（1-2 段落）
- 必要なランタイム（`docs/stack.md` の「ランタイム」表からコピー）
- セットアップ手順（`bin/setup`）
- 起動手順（`composer run dev`）
- テストアカウント表（`docs/seeds.md` の「アカウント」表をコピー）
- 主要 URL（`/`, `/admin`）
- テスト実行コマンド
- 関連ドキュメントへのリンク（`docs/` 配下）

### 5. Pint 自動修正

```sh
vendor/bin/pint database/seeders tests
```

### 6. 最終チェック

順番に実行:

1. `php artisan migrate:fresh --seed` ですべて再構築できることを確認
2. `php artisan test` が all green
3. `coverage/index.html` を確認し、行カバレッジが 80% 以上
4. `php artisan dusk` が all green
5. `vendor/bin/pint --test` が違反 0
6. `vendor/bin/phpstan analyse` でエラー 0
7. `composer audit` で既知の脆弱性 0
8. `composer run dev` で起動し、以下を curl で確認:
   - `GET /` → 200 または 302（ログインへ）
   - `GET /login` → 200
9. ブラウザでアクセスして以下を目視確認（コマンドだけでは見えない部分の最終確認をユーザーに依頼）:
   - 管理者でログインしてダッシュボード
   - メンバーでログインして借用申請

## このフェーズの完了基準（= プロジェクト全体の完成）

- [ ] `bin/setup` 一発でセットアップ完了
- [ ] `composer run dev` で起動して全機能が動作
- [ ] Seeder で各画面に表示すべきデータが入る
- [ ] `php artisan test` および `php artisan dusk` が all green
- [ ] カバレッジが 80% 以上（`coverage/index.html` で確認）
- [ ] `vendor/bin/pint --test` 違反 0、`vendor/bin/phpstan analyse` エラー 0
- [ ] README にテストアカウント・起動方法が記載

## 完了後

ユーザーに以下を報告:

- できあがった機能の一覧
- テストアカウントと URL
- 既知の制限・未実装事項（あれば）
- 次のステップ提案（CI 設定、Docker 化、本番デプロイ等）
