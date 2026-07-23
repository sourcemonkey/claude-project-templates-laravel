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

`docs/screens.md` の主要動線を Dusk で網羅する。Phase 3 で 4 件（蔵書一覧の表示 /
借用申請 / 申請の承認 / 非 admin の `/admin` リダイレクト）を実装済みなので、
**本フェーズではそれに加えて次の 3 件を新規に追加する**:

- メンバー: 自分の貸出を返却する
- 管理者: 書籍 CRUD（作成 → 編集 → 削除）
- 認可: 他人の貸出詳細にアクセスすると `home` へリダイレクトされる（Policy）

あわせて Phase 3 で書いた既存 2 件を、動線として通しで確認する形へ広げる:

- メンバー: ログイン → 蔵書検索 → 詳細 → 借用申請 → 自分の貸出一覧で確認
- 管理者: ログイン → 申請一覧 → 承認 → 通知が作られ在庫が減ること

> **「Phase 3 で似たテストがあるから網羅済み」と判断しないこと。** 上記 3 件は
> Phase 3 のシナリオに含まれておらず、書かなくても `php artisan dusk` は green に
> なる（＝完了基準をすり抜ける）。**最終的に Dusk のテストは 7 件以上**になる。

### 3. composer run setup の確認

Phase 1 で調整済みの `composer.json` の `setup` スクリプト（`composer run setup`）が以下を一発で実行できることを確認する:

1. DB コンテナの起動と待機
2. `composer install`
3. `.env` の用意（無ければ `.env.example` からコピー）と `key:generate`
4. `php artisan migrate --seed --force`
5. `npm install --ignore-scripts` / `npm run build`

Phase 4 では Seeder が実装済みのため、`docs/seeds.md` のサンプルデータが実際に投入されることまで確認する（Phase 1 の確認では Seeder が空だった）。

### 4. README.md の作成

`my-laravel-app/README.md` を新規作成。含めるべき項目:

- プロジェクト概要（1-2 段落）
- 必要なランタイム（`docs/stack.md` の「ランタイム」表からコピー。**PCOV の行も落とさずに含める** — `composer install` で導入されないマシン側の前提条件であり、README が唯一の周知手段になるため）
- セットアップ手順（`composer run setup`）
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

1. **クリーン再構築の確認（非破壊）**: 次の 2 つで担保する。**開発用 DB のデータは消さない**。
   - `php artisan test` が all green であること（手順 2 で実施）。Feature テストの
     `RefreshDatabase` はテスト DB の全テーブルを毎回削除して全マイグレーションを
     適用し直すため、**マイグレーションがゼロから通ることはこれで検証済み**になる
   - `php artisan db:seed` を 2 回連続で実行し、冪等（レコード数が増えない）かつ
     `docs/seeds.md` の全件が投入されることを確認する

   > **`php artisan migrate:fresh --seed` は使わない。** 破壊的コマンドとして
   > `.claude/settings.json` の deny リスト（ルート CLAUDE.md 厳守事項 #2 に対応）で
   > 拒否される。

   > **`docker compose down -v` → `composer run setup` による完全な再構築確認は任意。**
   > これが固有に検証できるのは「まっさらなボリュームから `composer run setup` 一発で
   > 立ち上がるか」だけで、マイグレーションのクリーン適用は上記でカバーされている。
   > **`down -v` は開発用 DB のデータを消す**ため、実行するのは破棄してよい場合に限ること
   > （Seeder で戻せるのは `docs/seeds.md` のデータのみで、画面から手で入れたデータは戻らない）。
   > なお `bookkeeper_test` は `docker/mysql/initdb/` の init スクリプトが再作成するため、
   > `down -v` してもテスト DB は失われない。
2. `php artisan test` が all green
3. **カバレッジが 80% 以上**であることを `coverage/index.html` の数値で確認する。
   `php artisan test --coverage-html coverage` で HTML を生成したうえで、次で数値を読む:
   ```sh
   grep -o 'Total[^%]*%' coverage/index.html | head -5
   ```

   > **`--min=80` の結果を信用しないこと。** `laravel/pao`（`laravel new` の既定に含まれる。
   > `docs/stack.md` 参照）がテストツールの出力を JSON 1 行へ整形する際、**カバレッジの数値も
   > `--min` の失敗も握りつぶす**。実際には 78.87%（未達）でも
   > `{"tool":"pest","result":"passed",...}` と返るため、**コマンドの成否では 80% 判定が
   > できない**。数値は必ず上記の HTML から取ること。
   >
   > `vendor/bin/pest --coverage --min=80` なら pao を経由せず数値と判定を直接得られるが、
   > ルートの `.claude/settings.json` の許可リストに無くヘッドレスでは実行できない
   > （許可を足すかは方針判断。現状は HTML を一次情報とする）。
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

- [ ] `composer run setup` 一発でセットアップ完了
- [ ] `composer run dev` で起動して全機能が動作
- [ ] Seeder で各画面に表示すべきデータが入る
- [ ] `php artisan test` および `php artisan dusk` が all green
- [ ] 「2-1. テストシナリオの実装」に列挙した Dusk シナリオが**すべてテストとして存在する**
      （本フェーズで追加する 3 件を含め 7 件以上。green であることと網羅していることは別）
- [ ] カバレッジが 80% 以上（`coverage/index.html` で確認）
- [ ] `vendor/bin/pint --test` 違反 0、`vendor/bin/phpstan analyse` エラー 0
- [ ] README にテストアカウント・起動方法が記載

## 完了後

ユーザーに以下を報告:

- できあがった機能の一覧
- テストアカウントと URL
- 既知の制限・未実装事項（あれば）
- 次のステップ提案（CI 設定、Docker 化、本番デプロイ等）
