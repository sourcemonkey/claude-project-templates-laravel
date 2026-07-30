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

> **`UserSeeder` の `role` は `firstOrCreate()` に渡さず、取得後に明示代入すること。**
> `role` は Mass assignment 対象外（`team-rules/security.md` / Phase 2 手順書）のため、
> `firstOrCreate([...], ['role' => ...])` の第 2 引数に入れても**黙って捨てられ、
> 全員が `Member` のまま作られる**（例外は出ないので気付きにくい）。
> ```php
> $user = User::firstOrCreate(['email' => $attributes['email']], [...]);
> $user->role = $attributes['role'];
> $user->save();
> ```
> 管理者アカウントが Member で作られると、後続の Dusk（管理者動線）が
> 「`/admin` からリダイレクトされる」形で落ちる。

> **`available_copies` の出どころを 1 箇所に決めること。** `docs/seeds.md` の「注意」節は
> 承認済み・延滞中の貸出が消費した**後**の値を書籍ごとに明示している。この値をそのまま
> `BookSeeder` に書くなら、`LendingSeeder` では在庫を触らないこと（両方で調整すると
> 二重に引かれる）。逆に `LendingSeeder` 側で減らす方式を採るなら、`firstOrCreate` が
> 既存行を返したときは減算しないようにする（2 回目の `db:seed` で在庫だけ減り、
> 冪等でなくなるため）。

### 2. 主要動線のシステムテスト

#### 2-0. カバレッジ計測の確認（テストを書く前に必ず実施）

**まず `php -m | grep pcov` でカバレッジ計測ドライバを確認する。出力が空の場合はここで中断し、`docs/stack.md` の「テストカバレッジ設定（正規形）」の導入手順を提示してユーザーに導入を依頼する**（PHP ランタイム全体に影響する変更のため、Claude Code の単独判断で `pecl install` や php.ini の編集を行わない）。カバレッジ 80% 以上は Phase 4 の完了基準であり、ドライバ無しでは達成を確認できないため、先にテストを書き進めても手戻りになる。

ドライバを確認できたら、`docs/stack.md` の「テストカバレッジ設定（正規形）」の通りに `phpunit.xml` を設定する。設定後、`php artisan test --coverage-html coverage` を一度実行して `coverage/index.html` が生成され、かつカバレッジが 0% でないことを確認してから次のステップへ進む。

> `laravel new` が生成する `phpunit.xml` には `<source><include>` が既にある（`<directory>app</directory>`）。
> `<coverage>` ブロックを新規に足し、`<directory>` には `suffix=".php"` を付ける。

#### 2-1. テストシナリオの実装

テストを書く前に、ボタン名・フィールド label の実際の文字列を対象の Blade / Livewire ファイルを Read して確認すること（`docs/screens.md` の「ボタン・ラベルの標準」とその注記参照）。

テスト実装上の注意:
- **Dusk の `select()` には `<option>` の `value` 属性を渡す**（表示テキストではない）。表示テキストで選択したい場合は `$browser->script(...)` を使わず、`selectByText()`（Dusk 3 系以降で利用可能な場合）の有無を確認して使う
- **承認済み貸出を使う返却テストでは、`Lending::factory()->approved()->create(...)` の前に `$book->update(['available_copies' => 1])` で在庫を確保すること**。Factory のトレイトは state のみ設定し `available_copies` は操作しないため、返却後に `available_copies > total_copies` になるケースでエラーになる。
- **Feature テストのクエリ文字列に日本語を直接埋めないこと。** `$this->get('/admin/users?filter[name]=検索対象')` はマルチバイトがそのまま URL に入って壊れ、絞り込みが一致しない。`urlencode('検索対象')` を通す。失敗時の症状は「該当 0 件」なので**原因が絞り込みロジック側にあるように見え**、切り分けに時間がかかる（Phase 4 のトライアルで踏んだ）。

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

> **カバレッジ 80% に届かせるには Feature テストの拡充が別途必要になる。**
> **Dusk は `php artisan test` のカバレッジに寄与しない**（ブラウザが別プロセスで動くため
> PCOV が実行行を拾わない）。上の Dusk 3 件を足しても数値は動かず、Phase 3 までの
> テストのままだと 80% に届かない（トライアルでは **71.64%**）。
>
> 不足分は `coverage/` のディレクトリ別インデックスで低い箇所を特定して埋める。
> ```sh
> grep -oE '[0-9]+\.[0-9]+%' coverage/Http/Controllers/Admin/index.html | head -40
> grep -oE '[0-9]+\.[0-9]+%' coverage/Policies/index.html | head -30
> ```
> トライアルで効いたのは次の 4 領域（追加後 **93.27%**）。いずれも Dusk では
> カバーされないが Feature テストなら安く書ける:
> - 管理画面の CRUD（カテゴリ・タグ・書籍の `store` / `update` / `destroy` と
>   Form Request のバリデーション。異常系も含める）
> - Livewire コンポーネント（`Livewire::test(BookSearch::class)->set('title', ...)` の形で
>   絞り込みの挙動を検証する。ブラウザ不要で速い）
> - Enum の `label()`（`->with([...])` のデータセットで全ケースを 1 テストに収められる）
> - 通知の未読/既読フィルタ・監査ログの絞り込み（Controller の分岐）

### 3. composer run setup の確認

Phase 1 で調整済みの `composer.json` の `setup` スクリプト（`composer run setup`）が以下を一発で実行できることを確認する:

1. DB コンテナの起動と待機
2. `composer install`
3. `.env` の用意（無ければ `.env.example` からコピー）と `key:generate`
4. `php artisan migrate --seed --force`
5. `npm install --ignore-scripts` / `npm run build`

Phase 4 では Seeder が実装済みのため、`docs/seeds.md` のサンプルデータが実際に投入されることまで確認する（Phase 1 の確認では Seeder が空だった）。

### 4. README.md の作成

`my-laravel-app/README.md` を書く。**`laravel new` が生成した Laravel 既定の README
（フレームワークの紹介・スポンサー一覧）が既に存在するので、新規作成ではなく
全文の置き換えになる。** Write ツールを使う場合は先に Read が必要。

含めるべき項目:

- プロジェクト概要（1-2 段落）
- 必要なランタイム（`docs/stack.md` の「ランタイム」表からコピー。**PCOV の行も落とさずに含める** — `composer install` で導入されないマシン側の前提条件であり、README が唯一の周知手段になるため）
- セットアップ手順（`composer run setup`）
- **別マシン・別ディレクトリへの持ち込み手順**: `node_modules/` と `vendor/` は**コピーせず、持ち込み先で `composer run setup`（`composer install` + `npm install` を含む）により生成する**こと。`cp -r`（macOS）でこれらを含めて丸ごとコピーすると、`node_modules/.bin/` 配下のシンボリックリンクが実ファイルに化けて `npm run build` が `ERR_MODULE_NOT_FOUND`（例: `Cannot find module '.../node_modules/dist/node/cli.js'`）で失敗する。git 管理外（`.gitignore` 済み）なので `git clone` すればそもそも含まれない。どうしてもコピーするなら `rsync -a --exclude=node_modules --exclude=vendor` で生成物を除外する
- 起動手順（`composer run dev`）
- テストアカウント表（`docs/seeds.md` の「アカウント」表をコピー）
- 主要 URL（`/`, `/admin`）
- テスト実行コマンド。**`php artisan dusk` は別ターミナルで
  `php artisan serve --env=dusk.local` を先に起動する必要がある**旨も書く
  （Dusk は自前でサーバーを起動しない。Phase 3 手順書の「Dusk 実行時の前提」参照）
- **AI エージェント向けの設定**: `composer run setup` が `php artisan boost:install --mcp --guidelines` を実行し、`.mcp.json`（Laravel Boost の MCP サーバー登録）と `docs/boost-guidelines.md`（AI ガイドライン）を生成すること。**どちらも `.gitignore` 済みでリポジトリには含まれない**ため、クローン後に `composer run setup` を実行して初めて有効になる旨を明記する
- 関連ドキュメントへのリンク（`docs/` 配下）

### 5. Pint 自動修正

```sh
vendor/bin/pint database/seeders tests
```

> **Pint を掛けたあとに `php artisan test` と `php artisan dusk` を回し直すこと。**
> `lambda_not_used_import`（クロージャの `use` から未使用変数を削る）などテストの
> 挙動に触れる fixer があるため、Pint 前に green だったことは Pint 後の保証にならない。

### 6. 最終チェック

順番に実行:

1. **クリーン再構築の確認（非破壊）**: 次の 2 つで担保する。**開発用 DB のデータは消さない**。
   - `php artisan test` が all green であること（手順 2 で実施）。Feature テストの
     `RefreshDatabase` はテスト DB の全テーブルを毎回削除して全マイグレーションを
     適用し直すため、**マイグレーションがゼロから通ることはこれで検証済み**になる
   - `php artisan db:seed` を 2 回連続で実行し、冪等（レコード数が増えない）かつ
     `docs/seeds.md` の全件が投入されることを確認する

   > 件数の確認は SQL で一括して取れる:
   > ```sh
   > docker compose exec -T db mysql -uapp -papp_password bookkeeper -e "SELECT 'users' t, COUNT(*) n FROM users UNION ALL SELECT 'categories', COUNT(*) FROM categories UNION ALL SELECT 'tags', COUNT(*) FROM tags UNION ALL SELECT 'books', COUNT(*) FROM books UNION ALL SELECT 'lendings', COUNT(*) FROM lendings UNION ALL SELECT 'notifications', COUNT(*) FROM notifications UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;"
   > ```
   > 期待値は users 3 / categories 4 / tags 7 / books 8 / lendings 5 / notifications 3 /
   > audit_logs 3（`docs/seeds.md`）。**日本語のカラム値は端末の文字コードによって
   > `???` と表示されることがあるが、DB の中身は壊れていない**（アプリ側の表示・テストで確認できる）。

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
2. `php artisan test` が all green（`laravel/pao` v1.1.3 以降は終了コードで判定してよい。
   1 が返った場合は版を確認する。Phase 1 手順書 Step 9-4 の既知事象を参照）
3. **カバレッジが 80% 以上**であることを `coverage/index.html` の数値で確認する。
   `php artisan test --coverage-html coverage` で HTML を生成したうえで、次で数値を読む:
   ```sh
   grep -oE '[0-9]+\.[0-9]+%' coverage/index.html | head -1
   ```
   PHPUnit の HTML レポートは先頭に「Total」行（プロジェクト全体の集計）を出力し、
   **ファイル内で最初に現れる `NN.NN%` がその Total 行の行カバレッジ**にあたる。
   これが 80% 以上であることを確認する。

   > **`grep -o 'Total[^%]*%'` のように 1 行で `Total` から `%` までを拾う書き方は使えない。**
   > レポートでは `<td class="success">Total</td>` のセルと百分率（`<td ...>93.41%</td>` や
   > `aria-valuenow="93.41"`）が**別々の行**に出力されるため、行単位で動く `grep` は
   > `Total` と `%` を 1 行内で連結できず、**何もマッチせず空を返す**（80% 判定が
   > できないまま「達成」と誤認しかねない）。上記のとおり百分率だけを拾って先頭を取る。

   > **`--min=80` の結果を信用しないこと。** `laravel/pao`（`laravel new` の既定に含まれる。
   > `docs/stack.md` 参照）がテストツールの出力を JSON 1 行へ整形する際、**カバレッジの数値も
   > `--min` の失敗も握りつぶす**。実際には 78.87%（未達）でも
   > `{"tool":"pest","result":"passed",...}` と返るため、**コマンドの成否では 80% 判定が
   > できない**。数値は必ず上記の HTML から取ること。
   >
   > `vendor/bin/pest --coverage --min=80` なら pao を経由せず数値と判定を直接得られるが、
   > ルートの `.claude/settings.json` の許可リストに無くヘッドレスでは実行できない
   > （許可を足すかは方針判断。現状は HTML を一次情報とする）。
4. `php artisan dusk` が all green。**別ターミナルで
   `php artisan serve --env=dusk.local` を起動してから実行する**（Phase 3 手順書参照）
5. `vendor/bin/pint --test` が違反 0
6. `vendor/bin/phpstan analyse` でエラー 0
7. `composer audit` で既知の脆弱性 0
8. `composer run dev` で起動し、以下を curl で確認:
   - `GET /` → 200 または 302（ログインへ）
   - `GET /login` → 200
9. ブラウザでアクセスして以下を目視確認（コマンドだけでは見えない部分の最終確認をユーザーに依頼）:
   - 管理者でログインしてダッシュボード
   - メンバーでログインして借用申請

   > ヘッドレス実行ではこの目視確認ができない。**確認できていない旨を報告に明記し、
   > 「完了」と断定しないこと**（Dusk が主要動線を押さえているので機能面の担保はあるが、
   > レイアウト崩れ・配色などは Dusk では検出できない）。

## このフェーズの完了基準（= プロジェクト全体の完成）

- [ ] `composer run setup` 一発でセットアップ完了
- [ ] `composer run dev` で起動して全機能が動作
- [ ] Seeder で各画面に表示すべきデータが入る（`db:seed` 2 回でも件数が増えない）
- [ ] `php artisan test` および `php artisan dusk` が all green
- [ ] 「2-1. テストシナリオの実装」に列挙した Dusk シナリオが**すべてテストとして存在する**
      （本フェーズで追加する 3 件を含め 7 件以上。green であることと網羅していることは別）
- [ ] カバレッジが 80% 以上（`coverage/index.html` で確認）。**Dusk は寄与しない**ため、
      届かない場合は Feature テストを足す（手順 2-1 の注記参照）
- [ ] `vendor/bin/pint --test` 違反 0、`vendor/bin/phpstan analyse` エラー 0
- [ ] README にテストアカウント・起動方法が記載
- [ ] `git status --short` に `.gitignore` 漏れの生成物が出ていない
      （`coverage/`・`.env.dusk.local` は Phase 4 で新たに生成される。どちらも除外済みのはず）

## 完了後

ユーザーに以下を報告:

- できあがった機能の一覧
- テストアカウントと URL
- 既知の制限・未実装事項（あれば）
- 次のステップ提案（CI 設定、Docker 化、本番デプロイ等）
