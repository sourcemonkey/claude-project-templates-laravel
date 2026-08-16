---
description: フェーズ5 - Seeder、テスト、README、起動確認で完成させる
---

# Phase 5: 仕上げ（Seeder + テスト + 起動確認）

最終フェーズ。「最初から動くもの」を完成させる。投入データ・テストアカウント等の具体値は `docs/seeds.md` が一次情報。

> **着手前に `docs/seeds.md` を Read すること。** このファイルは `CLAUDE.md` から `@` 参照して
> いない（読む場面が本フェーズにほぼ限られるため）ので、自動では文脈に入っていない。

> **実行場所**: 本手順書のコマンドは、断りが無い限りすべて **`my-laravel-app/` をカレント**として
> 書かれている。Bash ツールのカレントは呼び出しをまたいで持続するので、**最初に一度だけ**
> `cd my-laravel-app` し、以降は移動しない（ルートにも別物の `bin/` があり、そこから
> `bin/check-repo.sh` を打つと `exit 127` になる）。

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
> `role` は Mass assignment 対象外なので、第 2 引数に入れても**全員が `Member` のまま
> 作られる**（例外は出ない）。
> ```php
> $user = User::firstOrCreate(['email' => $attributes['email']], [...]);
> $user->role = $attributes['role'];
> $user->save();
> ```
> 管理者が Member で作られると、後続の Dusk が「`/admin` からリダイレクトされる」形で落ちる。

> **`available_copies` の出どころを 1 箇所に決めること。** `docs/seeds.md` の「注意」節は
> 承認済み・延滞中の貸出が消費した**後**の値を書籍ごとに明示している。この値をそのまま
> `BookSeeder` に書くなら、`LendingSeeder` では在庫を触らないこと（両方で調整すると
> 二重に引かれる）。逆に `LendingSeeder` 側で減らす方式を採るなら、`firstOrCreate` が
> 既存行を返したときは減算しないようにする（2 回目の `db:seed` で在庫だけ減り、
> 冪等でなくなるため）。

> **`BookSeeder` のタグ付けは `sync()` ではなく `syncWithoutDetaching()` を使うこと。**
> 素の `attach()` は 2 回目の `db:seed` で
> `Integrity constraint violation: 1062 Duplicate entry` になる。

### 2. 主要動線のシステムテスト

#### 2-0. カバレッジ計測の確認（テストを書く前に必ず実施）

**まず `php -m | grep pcov` でカバレッジ計測ドライバを確認する。出力が空の場合はここで中断し、`docs/stack.md` の「テストカバレッジ設定（正規形）」の導入手順を提示してユーザーに導入を依頼する**（PHP ランタイム全体に影響するため、単独判断で `pecl install` や php.ini の編集を行わない）。

ドライバを確認できたら、`docs/stack.md` の「テストカバレッジ設定（正規形）」の通りに `phpunit.xml` を設定する。設定後、`php artisan test --coverage-html coverage` を一度実行して `coverage/index.html` が生成され、かつカバレッジが 0% でないことを確認してから次のステップへ進む。

> 生成された `phpunit.xml` には `<source><include>` が既にある（`<directory>app</directory>`）。
> `<coverage>` ブロックを新規に足し、`<directory>` には `suffix=".php"` を付ける。

#### 2-1. テストシナリオの実装

テストを書く前に、ボタン名・フィールド label の実際の文字列を対象の Blade / Livewire ファイルを Read して確認すること（`docs/screens.md` の「ボタン・ラベルの標準」とその注記参照）。

テスト実装上の注意:
- **Dusk の `select()` には `<option>` の `value` 属性を渡す**（表示テキストではない）。
  例: `->select('category_id', (string) $category->id)`。**表示テキストで選択できると
  思い込まないこと**（`select('category_id', '技術書')` は一致せず、選択されないまま
  submit されてバリデーションエラーになる）
- **返却テストでは「1 冊消費済み」の書籍を用意すること**（`approved()` は在庫を減らさないため、そのまま返却させると CHECK 制約に違反する。理由と失敗の見え方は Phase 4 手順書「テストシナリオ」節の同名の注意を参照）。
  ```php
  $book = Book::factory()->create(['total_copies' => 2, 'available_copies' => 1]);
  $lending = Lending::factory()->approved()->create(['book_id' => $book->id]);
  ```
- **Feature テストのクエリ文字列に日本語を直接埋めないこと**（`urlencode()` を通す）。症状が「該当 0 件」なので**原因が絞り込みロジック側にあるように見える**。

`docs/screens.md` の主要動線を Dusk で網羅する。Phase 4 で 4 件（蔵書一覧の表示 /
借用申請 / 申請の承認 / 非 admin の `/admin` リダイレクト）を実装済みなので、
**本フェーズではそれに加えて次の 4 件を新規に追加する**:

- メンバー: 自分の貸出を返却する
- 管理者: 書籍 CRUD（作成 → 編集 → 削除）
- 認可: 他人の貸出詳細にアクセスすると `home` へリダイレクトされる（Policy）
- メンバー: 蔵書一覧で**2 ページ目へページ送り**できる（下記）

> **Phase 4 で既に書いてあるものは重複させず、不足分だけを埋めること**
> （最終的に Dusk が下記の完了基準の件数に達していればよい）。

> **ページネーションは Seeder のデータで検証できる。** `docs/seeds.md` は書籍を 30 件
> 投入し、うち 1 件が未公開なのでメンバーには 29 件見える。一覧は 25 件/ページなので
> **1 ページ目 25 件・2 ページ目 4 件**になる。ブラウザで 2 ページ目に遷移し、
> 1 ページ目に無かった書籍が表示されることを確認する。
>
> **ただし Dusk のテスト DB（`bookkeeper_test`）は `DatabaseTruncation` で毎回空にされる**ため、
> Seeder のデータはそのままでは使えない。テスト内でファクトリを使って 30 件（うち 1 件は
> `unpublished()`）を作ること。
>
> **Livewire のページャは `<a>` ではなく `<button wire:click="gotoPage(...)">` なので、
> `clickLink('2')` は掴めず `javascript error: Cannot read properties of undefined
> (reading 'click')` で落ちる**（「リンクが無い」ではなく JS エラーとして出る）。
> **`press('2')` を使うこと。** 押した後は `waitForText()` で描画完了を待つ。
>
> **一覧クエリに既定の並び順を入れておくこと**（`QueryBuilder::for()` に渡すクエリへ
> `->orderBy('id')`）。付けないと「どの書籍が 2 ページ目に来るか」が実行ごとに変わりうる。
> `allowedSorts` は `docs/db-schema.md` の定義のままでよい。
>
> **期待する書籍名をテスト中にハードコードしないこと。** どの書籍が 2 ページ目に来るかは
> ファクトリの生成順に依存するため、テスト内で
> `Book::where('published', true)->orderBy('id')->offset(25)->limit(25)->pluck('title')`
> のように**DB から引いた値で assert する**と、順序の実装を変えても壊れない。

あわせて Phase 4 で書いた既存 2 件を、動線として通しで確認する形へ広げる:

- メンバー: ログイン → 蔵書検索 → 詳細 → 借用申請 → 自分の貸出一覧で確認
- 管理者: ログイン → 申請一覧 → 承認 → 通知が作られ在庫が減ること

> **「Phase 4 で似たテストがあるから網羅済み」と判断しないこと。** 含まれないものは
> 書かなくても `php artisan dusk` は green になる（＝完了基準をすり抜ける）。
> **最終的に Dusk のテストは 8 件以上**になる。

> **Dusk は `php artisan test` のカバレッジに寄与しない**（ブラウザが別プロセスで動くため）。
> 上の Dusk 4 件を足しても数値は動かない。**まず数値を測ってから判断すること**——
> Feature テストを厚めに書いた回は Phase 5 の開始時点で 88〜92% に達しており、追加は
> 不要だった。
>
> 不足する場合は `coverage/` のディレクトリ別インデックスで低い箇所を特定して埋める。
> ```sh
> grep -oE '[0-9]+\.[0-9]+%' coverage/Http/Controllers/Admin/index.html | head -40
> grep -oE '[0-9]+\.[0-9]+%' coverage/Policies/index.html | head -30
> ```
> **`vendor/bin/pest --coverage` の出力（pao の JSON の `raw` 配列）にもファイル単位の
> 百分率と未到達行番号が並ぶ**ので、HTML を開かずに特定してもよい。効いたのは次の 4 領域
> （いずれも Dusk ではカバーされないが Feature テストなら安く書ける）:
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

Phase 5 では Seeder が実装済みのため、`docs/seeds.md` のサンプルデータが実際に投入されることまで確認する。

### 4. README.md の作成

`my-laravel-app/README.md` を書く。**`laravel/laravel` 既定の README
（フレームワークの紹介・スポンサー一覧）が既に存在するので、新規作成ではなく
全文の置き換えになる。** Write ツールを使う場合は先に Read が必要。

> **README は「アプリがリポジトリのルートにある」構成を前提に書くこと。** 読み手は
> `bin/init-project.sh` で作られた開発用リポジトリを clone した人で、そこでは
> `my-laravel-app/` の中身が直下に展開される。コマンドの実行場所は**「リポジトリ直下」で
> 正しく、`my-laravel-app/ で実行する` と書き換えてはならない**（冒頭の「実行場所」の
> 不変条件は、この手順書が指示するコマンドの話であって README とは別物）。
>
> clone した人の手元には `vendor/` も `node_modules/` も `.env` も無い。**セットアップ手順は
> その人にとっての最初の 1 手**である。

含めるべき項目:

- プロジェクト概要（1-2 段落）
- 必要なランタイム（`docs/stack.md` の「ランタイム」表からコピー。**PCOV の行も落とさずに含める** — `composer install` で導入されないマシン側の前提条件であり、README が唯一の周知手段になるため）
- セットアップ手順（`composer run setup`）
- **別マシン・別ディレクトリへの持ち込み手順**: `node_modules/` と `vendor/` は**コピーせず、持ち込み先で `composer run setup` により生成する**こと（`cp -r` すると `npm run build` が `ERR_MODULE_NOT_FOUND` で失敗する）。コピーするなら `rsync -a --exclude=node_modules --exclude=vendor`
- 起動手順（`composer run dev`）
- テストアカウント表（`docs/seeds.md` の「アカウント」表をコピー）
- **DB 接続情報**（DBeaver / TablePlus などの GUI クライアントから繋ぐために必要な項目を網羅する。値は `compose.yaml` と `docs/stack.md` の「MySQL 設定の規約」が一次情報）:

  | 項目 | 値 |
  |---|---|
  | ホスト | `127.0.0.1`（`localhost` でも可） |
  | ポート | `3306` |
  | データベース | `bookkeeper`（開発用） / `bookkeeper_test`（テスト用） |
  | ユーザー名 | `app` |
  | パスワード | `app_password` |
  | JDBC URL（参考） | `jdbc:mysql://127.0.0.1:3306/bookkeeper` |

  あわせて次の 3 点を書くこと。**いずれも書かないと接続できない・データが見えない原因になる**:
  - **`docker compose up -d db` で DB コンテナが起動していること**が前提
  - `bookkeeper_test` は**テスト実行のたびに中身が破棄される**。GUI で見るなら `bookkeeper` を選ぶ
  - root ユーザーも存在するが、**通常は `app` を使う**
  - **LAN 内の別マシンからは繋がらない**（`ports` を `127.0.0.1:3306:3306` に限定しているため。意図した設定）
- 主要 URL（`/`, `/admin`）
- テスト実行コマンド。**`php artisan dusk` は別ターミナルで
  `php artisan serve --env=dusk.local --no-reload` を先に起動する必要がある**旨も書く
  （Dusk は自前でサーバーを起動しない。Phase 4 手順書の「Dusk 実行時の前提」参照）
- **AI エージェント向けの設定**: `composer run setup` が `php artisan boost:install --mcp --guidelines` を実行し、`.mcp.json`（Laravel Boost の MCP サーバー登録）と `docs/boost-guidelines.md`（AI ガイドライン）を生成すること。**どちらも `.gitignore` 済みでリポジトリには含まれない**ため、クローン後に `composer run setup` を実行して初めて有効になる旨を明記する
- 関連ドキュメントへのリンク（`docs/` 配下）

### 5. Pint 自動修正

```sh
vendor/bin/pint
```

> **Pint を掛けたあとに `php artisan test` と `php artisan dusk` を回し直すこと。**
> テストの挙動に触れる fixer があるため、Pint 前に green だったことは Pint 後の保証にならない。

### 6. 最終チェック

順番に実行:

1. **クリーン再構築の確認（非破壊）**: 次の 2 つで担保する。**開発用 DB のデータは消さない**。
   - `php artisan test` が all green であること（手順 2 で実施）。`RefreshDatabase` が
     全マイグレーションを適用し直すため、**ゼロから通ることはこれで検証済み**になる
   - `php artisan db:seed` を 2 回連続で実行し、冪等（レコード数が増えない）かつ
     `docs/seeds.md` の全件が投入されることを確認する。**`&&` で連結して 1 呼び出しにする**
     （2 回目が落ちたら非冪等なので、そこで止まるべき）:

     ```sh
     php artisan db:seed && php artisan db:seed
     ```

   > 件数の確認は SQL で一括して取れる:
   > ```sh
   > docker compose exec -T db mysql -uapp -papp_password bookkeeper -e "SELECT 'users' t, COUNT(*) n FROM users UNION ALL SELECT 'categories', COUNT(*) FROM categories UNION ALL SELECT 'tags', COUNT(*) FROM tags UNION ALL SELECT 'books', COUNT(*) FROM books UNION ALL SELECT 'lendings', COUNT(*) FROM lendings UNION ALL SELECT 'notifications', COUNT(*) FROM notifications UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;"
   > ```
   > 期待値は users 3 / categories 4 / tags 13 / books 30 / lendings 5 / notifications 3 /
   > audit_logs 3（`docs/seeds.md`）。**日本語のカラム値は端末の文字コードによって
   > `???` と表示されることがあるが、DB の中身は壊れていない**（アプリ側の表示・テストで確認できる）。
   > 日本語を含む `WHERE` 句も同じ理由で空振りすることがあるため、書籍の在庫を個別に
   > 確かめるときは `title` ではなく `isbn` で絞ると確実。
   >
   > **貸出の 5 状態が 1 件ずつ揃っていることも確認する**（`docs/seeds.md` の貸出表）。
   > これが崩れていると admin ダッシュボードの「申請待ち」「延滞」が 0 件になる。
   > 上の件数確認とは独立なので、`;` でつないで 1 呼び出しにする:
   > ```sh
   > docker compose exec -T db mysql -uapp -papp_password bookkeeper -e "SELECT state, COUNT(*) n FROM lendings GROUP BY state ORDER BY state;"
   > ```

   > **`php artisan migrate:fresh --seed` は使わない**（deny リストで拒否される）。
   >
   > **`docker compose down -v` → `composer run setup` による完全な再構築確認は任意。**
   > これが固有に検証できるのは「まっさらなボリュームから一発で立ち上がるか」だけで、
   > マイグレーションのクリーン適用は上記でカバーされている。**`down -v` は開発用 DB の
   > データを消す**ため、破棄してよい場合に限ること（`bookkeeper_test` は init スクリプトが
   > 再作成するので失われない）。
2. `php artisan test` が all green（`laravel/pao` v1.1.3 以降は終了コードで判定してよい。
   1 が返った場合は版を確認する。Phase 1 手順書 Step 9-4 の既知事象を参照）
3. **カバレッジが 80% 以上**であることを確認する。**合否は終了コードで判定する**
   （未達なら 1、達していれば 0）。ルートの `.claude/settings.json` に
   `Bash(vendor/bin/pest*)` があるためヘッドレスでも実行できる。

   ```sh
   vendor/bin/pest --coverage --min=80
   ```

   数値と失敗理由は pao の JSON の `raw` 配列末尾に `"Total: NN.N %"` と
   `"FAIL Code coverage below expected 80.0 %, currently NN.N %."` として入る。
   **`result` フィールドは未達でも `"passed"` のままなので、合否の判断に使わないこと**
   （`docs/stack.md` の「80% 判定の規約」参照）。

   内訳を見たい場合や、レビュー用に記録を残したい場合は HTML レポートを併用する。
   ファイル内で最初に現れる `NN.NN%` が Total 行の行カバレッジにあたる。

   ```sh
   php artisan test --coverage-html coverage
   grep -oE '[0-9]+\.[0-9]+%' coverage/index.html | head -1
   ```

   > **`grep -o 'Total[^%]*%'` のように 1 行で `Total` から `%` までを拾う書き方は使えない。**
   > レポートでは `Total` のセルと百分率が**別々の行**に出力されるため、行単位で動く
   > `grep` は**何もマッチせず空を返す**（判定できないまま「達成」と誤認しかねない）。
4. `php artisan dusk` が all green。**別ターミナルで
   `php artisan serve --env=dusk.local --no-reload` を起動してから実行する**（Phase 4 手順書参照）。
   **停止は `pkill -f "artisan serve"` で行う。素の `kill <PID>` は使わない**
   （許可リストは `Bash(pkill -f *)` のみで、`kill` はヘッドレスで承認待ちになる）
5. `vendor/bin/pint --test` が違反 0
6. `vendor/bin/phpstan analyse --memory-limit=512M` でエラー 0（**`--memory-limit` を省略しない**。この環境の PHP の既定は 128M で、省略すると並列ワーカーが `Child process error (exit code 255): while running parallel worker` で落ちる）
7. `composer audit` で既知の脆弱性 0

   > 5〜7 は互いに独立で、いずれも終了コードで判定する。**`&&` で連結して 1 呼び出しにする**:
   >
   > ```sh
   > vendor/bin/pint --test && vendor/bin/phpstan analyse --memory-limit=512M && composer audit
   > ```
8. `composer run dev` で起動し、以下を curl で確認する。2 つは独立なので `;` でつないで
   1 呼び出しにする:
   - `GET /` → 200 または 302（ログインへ）
   - `GET /login` → 200

   ```sh
   curl -sS --retry 15 --retry-all-errors --retry-delay 1 -o /dev/null -w "/: %{http_code}\n" http://localhost:8000; curl -sS -o /dev/null -w "/login: %{http_code}\n" http://localhost:8000/login
   ```

   確認後に停止する（Phase 1 Step 9-5 と同じ。2 個目以降の終了コード 1 は正常）。

   ```sh
   pkill -f "php artisan serve"; pkill -f "artisan pail"; pkill -f vite
   ```
9. **（完了基準ではない・任意）** ブラウザで目視確認する。コマンドでは見えない部分
   （レイアウト崩れ・配色）の確認であり、機能面は Dusk が主要動線を押さえている:
   - 管理者でログインしてダッシュボード
   - メンバーでログインして借用申請

   > **ヘッドレス実行ではこの確認を行わず、未実施を理由に「完了」を保留しない。**
   > 対話セッションでは起動 URL とテストアカウントを添えてユーザーに促すだけでよい。

## このフェーズの完了基準（= プロジェクト全体の完成）

まず `bin/check-repo.sh`（読み取りのみ）を実行し、終了コード 0 を確認してから以下を確認する。

- [ ] `composer run setup` 一発でセットアップ完了
- [ ] `composer run dev` で起動して全機能が動作
- [ ] Seeder で各画面に表示すべきデータが入る（`db:seed` 2 回でも件数が増えない）
- [ ] 貸出の 5 状態が 1 件ずつ揃っている（admin ダッシュボードの申請待ち・延滞が 0 にならない）
- [ ] `php artisan test` および `php artisan dusk` が all green
- [ ] **`docs/` が定める観測可能な振る舞い（ステータスコード・フラッシュ文言・ラベル）に、対応する
      assert が存在する**（Phase 4 手順書の「観測可能な振る舞いは assert で固定する」参照。本フェーズで
      足す Feature テストにも同じ基準を適用する）
- [ ] 「2-1. テストシナリオの実装」に列挙した Dusk シナリオが**すべてテストとして存在する**
      （本フェーズで追加する 4 件を含め 8 件以上。green であることと網羅していることは別）
- [ ] カバレッジが 80% 以上（手順 6-3 の `vendor/bin/pest --coverage --min=80` の終了コードで判定）。
      **Dusk は寄与しない**ため、届かない場合は Feature テストを足す（手順 2-1 の注記参照）
- [ ] `vendor/bin/pint --test` 違反 0、`vendor/bin/phpstan analyse --memory-limit=512M` エラー 0
- [ ] README にテストアカウント・起動方法が記載

## 完了後

ユーザーに以下を報告:

- できあがった機能の一覧
- テストアカウントと URL
- 既知の制限・未実装事項（あれば）
- 次のステップ提案（CI 設定、Docker 化、本番デプロイ等）
