# Laravel プロジェクト生成テンプレートキット

Claude Code に Laravel 中規模プロジェクトを 4 フェーズで生成させるための
`CLAUDE.md` / 仕様ドキュメント / スラッシュコマンド一式です。

[claude-project-templates](../claude-project-templates)（Rails 版）を
PHP 8.4.23 / Laravel 13 向けに移植したものです。フェーズ分割の考え方
（雛形 → モデル → UI → 仕上げ）や CLAUDE.md 階層構造は Rails 版と共通です。

題材として「蔵書管理 + 貸出記録システム（BookKeeper）」を同梱していますが、
これはあくまで例で、`my-laravel-app/docs/` を差し替えれば他の業務系プロジェクトの
雛形としても使えます。

## 構成

```
.
├── .claude/
│   └── settings.json            ← Claude Code 共通設定（コマンドの許可リスト）
├── .gitignore                   ← テンプレートリポジトリ用の除外設定
├── .tool-versions               ← リポジトリ全体での PHP / Node.js バージョン（asdf）
├── bin/
│   ├── init-project.sh          ← 新規リポジトリの初期化スクリプト
│   ├── reset-phase.sh           ← my-laravel-app/ をテンプレート状態に戻す
│   └── watch-trial.sh           ← 実行中のヘッドレストライアルを別ターミナルで追う
├── CLAUDE.md                    ← チーム共通ルール（このリポジトリ配下全体に適用）
├── env.example                  ← 環境変数のサンプル（リポジトリルート用）
├── patches/                     ← ヘッドレス実行の申し送り置き場（通常は .gitkeep のみ）
│   ├── <ファイル名>.md          ← .claude/ 配下へ適用待ちの修正済み完全版
│   └── issue-*.md               ← 判断が必要で自動修正しなかった事項
├── prompts/                     ← ヘッドレス実行用プロンプト（.claude/ 外に置き修正可能にする）
│   └── trial-phase.md           ← フェーズファイルのヘッドレス・トライアル用プロンプト
├── README.md                    ← このファイル
├── team-rules/                  ← チーム共通ルールの本体
│   ├── coding-standards.md
│   ├── git-workflow.md
│   ├── review-policy.md
│   └── security.md
└── my-laravel-app/              ← 個別プロジェクトのルート（ここで claude を起動）
    ├── .gitignore               ← Laravel アプリ用の除外設定（.env / coverage/ 等を含む）
    ├── .npmrc                   ← npm の方針（ignore-scripts / audit）。生成物ではなくテンプレート同梱
    ├── .tool-versions           ← my-laravel-app 配下での PHP / Node.js バージョン
    ├── CLAUDE.md                ← プロジェクト固有のエントリポイント
    ├── compose.yaml              ← 開発用 MySQL コンテナ定義
    ├── docker/                  ← Docker 関連の追加設定
    │   └── mysql/
    │       ├── conf.d/
    │       └── initdb/          ← 初回起動時に bookkeeper / bookkeeper_test を作成
    ├── config/
    │   └── boost.php            ← Laravel Boost の出力先設定（生成物は Phase 1 で作られる）
    ├── .ai/
    │   └── guidelines/          ← Boost の AI ガイドラインの上書き（本プロジェクトの方針を優先）
    ├── docs/                    ← 仕様ドキュメント
    │   ├── stack.md             ← 技術スタック
    │   ├── architecture.md      ← レイヤ設計
    │   ├── db-schema.md         ← DB スキーマ
    │   ├── screens.md           ← 画面構成
    │   ├── api-spec.md          ← ルーティング・認可
    │   └── seeds.md             ← 初期データ
    └── .claude/
        ├── settings.json        ← Claude Code の権限設定（共有用）
        └── commands/             ← フェーズ別スラッシュコマンド
            ├── scaffold-phase1-skeleton.md
            ├── scaffold-phase2-models.md
            ├── scaffold-phase3-ui.md
            ├── scaffold-phase4-finalize.md
            └── verify.md
```

## ローカル環境の前提

`my-laravel-app/docs/stack.md` の前提に従い、ローカル PC に以下が必要です。

| ツール | バージョン | 用途 |
|---|---|---|
| PHP | 8.4.23 | `.tool-versions`（asdf）で固定 |
| Composer | 2.x | PHP パッケージ管理 |
| Laravel Installer | 5.x | `laravel new` コマンド用（後述の「Laravel のバージョン方針」参照） |
| Node.js | 24.x (Active LTS) | Vite ビルド用 |
| Docker | 24.x 以上 | 開発用 MySQL の起動 |
| Docker Compose | v2 (`docker compose`) | 同上 |
| Claude Code | 最新版 | フェーズ実行 |

DBMS は MySQL 8.x を **Docker コンテナ** で起動する設計です。
ホスト OS への MySQL インストールは不要です。

### Laravel のバージョン方針

**本テンプレートは Laravel 13 系を前提に書かれています。** `my-laravel-app/docs/` の
仕様（`stack.md` の `laravel/framework (^13.0)`、`.env` / `phpunit.xml` / `config/app.php`
の既定値に関する記述）も、`.claude/commands/` の手順書も、すべて 13 系の生成物に
合わせています。

一方 `laravel new` には**バージョン指定オプションがありません**。内部で
`composer create-project laravel/laravel ...` を実行するため、取得されるのは
**その時点の最新安定版**です。つまり「Installer が最新版であること」と
「Laravel 13 が入ること」は本質的に別の話で、両者が一致しているのは
Laravel 13 が最新である期間だけです。

Laravel はメジャーリリースを**毎年 ~Q1** に出します（公式の
[Release Notes](https://laravel.com/docs/13.x/releases) に明記）。

| バージョン | リリース日 | バグ修正終了 | セキュリティ修正終了 |
|---|---|---|---|
| 12 | 2025-02-24 | 2026-08-13 | 2027-02-24 |
| **13**（本テンプレートの前提） | **2026-03-17** | Q3 2027 | 2028-03-17 |
| 14 | **2027 Q1 見込み** | — | — |

このため Phase 1（`/scaffold-phase1-skeleton`）は、`laravel new` の直後に
`composer.json` の `laravel/framework` が `^13.` であることを検証し、
異なる場合はその場で手順を中断します。**Laravel 14 のリリース後にこのテンプレートを
実行すると、Phase 1 の Step 3 で停止します**。その時点で、13 にピン留めして
使い続けるか（`composer create-project laravel/laravel:^13.0` へ切り替え）、
テンプレート側を 14 対応へ更新するかを判断してください。手順は
`my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md` の Step 3 に記載しています。

### PHP バージョンを 2 箇所で固定している理由

リポジトリ直下と `my-laravel-app/` 配下の両方に `.tool-versions` を置いています。
Claude Code が `laravel new` や `composer require` などのコマンドを実行する際、
カレントディレクトリが `my-laravel-app/` の外側になるケースがあるためです。両方に
同じバージョンを書いておけば、どちらのディレクトリで `asdf` が動いても
同じ PHP / Node.js が選ばれます。

PHP バージョンを上げる場合は **両方を同時に更新**してください。

## 使い方

### 1. 配置

このリポジトリを、新規プロジェクトを作りたい場所にコピーします。

```sh
cp -r <このリポジトリ> ~/work/your-new-project
cd ~/work/your-new-project
```

（または git clone してリネームしても構いません。）

### 2. プロジェクト名・仕様の調整

別プロジェクトに転用する場合は、以下を実際に作りたい題材に合わせて編集します。
BookKeeper をそのまま題材として進める場合はスキップで OK です。

- `my-laravel-app/CLAUDE.md` のプロジェクト名と概要
- `my-laravel-app/docs/` の各ドキュメント
  - 特に `db-schema.md`, `screens.md`, `seeds.md` は題材に応じて差し替え
- `my-laravel-app/compose.yaml` のコンテナ名・DB 名（必要なら）

### 3. Claude Code を起動

```sh
cd my-laravel-app
claude
```

起動すると、Claude Code は親ディレクトリ方向に `CLAUDE.md` を辿り、
チーム共通ルール（ルートの `CLAUDE.md` + `team-rules/`）も自動的に
読み込みます。

### 4. フェーズ実行

Claude Code のセッションで順番にスラッシュコマンドを実行します。

```
/scaffold-phase1-skeleton
```

完了したら検証:

```
/verify
```

問題なければ次へ:

```
/scaffold-phase2-models
/verify
/scaffold-phase3-ui
/verify
/scaffold-phase4-finalize
/verify
```

各フェーズの間で、Claude Code からの確認や質問に答えながら進めます。

### 5. 完成後

`my-laravel-app/` 配下に Laravel アプリ一式が生成されます。

```sh
cd my-laravel-app
composer run setup  # MySQL コンテナ起動 + composer/npm install + migrate --seed
composer run dev    # 開発サーバ起動
```

具体的な起動 URL・テストアカウントは Phase 4 で生成される
`my-laravel-app/README.md` 参照。

### 6. 独立リポジトリへの移行（任意）

Phase 1〜4 が完了したら、`bin/init-project.sh` を使ってテンプレートの
git 履歴を切り離し、独立した開発用リポジトリとして初期化できます。

```sh
bash bin/init-project.sh
```

スクリプトはモードを選べます。

- **モード 1**: このリポジトリ自体を開発用リポジトリとして使う（テンプレートの `.git` を作り直す）
- **モード 2**: 別のディレクトリにコピーしてから、そこを新規リポジトリ化する

どちらのモードでも初回コミットを対話形式で行います。（`.gitignore` はテンプレートに同梱済みのため生成不要）

## 主な技術選定（Rails 版からの対応）

| Rails 版 | Laravel 版 | 備考 |
|---|---|---|
| ERB + Hotwire (Turbo + Stimulus) | Blade + Livewire + Alpine.js | Livewire がサーバー駆動 UI 更新（Turbo 相当）、Alpine が軽量インタラクション（Stimulus 相当） |
| Devise | Laravel Breeze（Livewire スタック） | 認証一式のスキャフォールディング |
| Pundit | Laravel Policy（標準機能） | 追加パッケージ不要 |
| Ransack | Spatie Laravel Query Builder | クエリパラメータでの宣言的フィルタ・ソート |
| Kaminari | Laravel 標準 `paginate()` | 追加パッケージ不要 |
| RuboCop | Laravel Pint | `laravel new` の既定に含まれる |
| Brakeman | larastan/larastan | 静的解析（PHPStan の Laravel 版。Enlightn は Laravel 13.x 未対応のため不採用） |
| Minitest + Capybara/Selenium | Pest + Laravel Dusk | システムテスト |
| SimpleCov | PHPUnit/Pest の `--coverage-html`（PCOV ドライバ） | |
| Service オブジェクト | Action クラス（`app/Actions/`） | 命名規則は「操作 + リソース + Action」 |

詳細な理由・設計判断は `my-laravel-app/docs/stack.md` および `my-laravel-app/docs/architecture.md` 参照。

## カスタマイズのコツ

- **別の業務系プロジェクトに転用するとき**: `my-laravel-app/docs/` の中身だけ
  差し替えれば、コマンドや方針はそのまま使えます
- **DB を PostgreSQL にしたいとき**: `docs/stack.md` の MySQL 関連記述、
  `my-laravel-app/compose.yaml` のイメージ、Phase 1 のコマンドファイルの 3 箇所を
  書き換えれば対応できます
- **チーム共通ルールの強化**: `team-rules/` 配下にファイルを追加し、
  ルート `CLAUDE.md` で `@team-rules/xxx.md` でインクルードします
- **個人設定**: 個人だけのルール（好みのエディタ設定等）は
  `~/.claude/CLAUDE.md` または各リポジトリの `CLAUDE.local.md`
  （gitignore 推奨）に置きます

## コマンドファイルの書き方

`my-laravel-app/.claude/commands/*.md` を新規追加・編集するときの方針です。
新しいフェーズや補助コマンドを追加する場合、既存のコマンドファイル
（`scaffold-phase1-skeleton.md` など）を雛形にしてください。

### 1. 一次情報は docs/ に集約する

仕様（DB スキーマ、画面構成、ルーティング、認可、Seeder 内容など）は
`my-laravel-app/docs/` 配下のドキュメントが一次情報です。コマンドファイル側に
同じ内容を書かず、`docs/xxx.md` を参照する形にします。

理由:

- 仕様変更時に 2 箇所メンテになるのを避ける
- コマンドファイルが長くなるとトークン消費が増える
- 役割分担を明確にする（コマンドは「何をするか」、docs は「どう書くか」）

### 2. 同梱ファイルは「確認」しない

リポジトリに既に存在するファイル（`compose.yaml`, `.tool-versions`,
`env.example` など）は、コマンドファイル内で内容を再掲しないでください。
テンプレートに同梱した時点で「正」とみなし、存在を前提に使うだけです。

確認手順を書くと、Claude Code が律儀に `cat` や目視確認を実行して
トークンと承認プロンプトを消費します。冗長確認はテンプレートの
存在意義を否定することにもなります。

### 3. コード例を書くのは「実装ブレ防止」のときだけ

具体的なコード例（PHP / Blade / Tailwind クラス指定など）は、それが
無いと Claude Code が毎回違う実装を選んでしまう場合のみ残します。例:

- CHECK 制約の `DB::statement()` の書き方（マイグレーションの標準機能にない MySQL 固有の書き方）
- Policy の最小骨格（API として明示すべき形）
- Tailwind のデザイントークン（クラス名のブレ防止）

逆に、仕様として docs/ に書かれているものは例示しません。

### 4. ファイルの構成

各コマンドファイルは以下の構成を取ります。`## 前提` と `## やらないこと` は
内容がある場合のみ設ける任意セクション。`## 実行手順` はフェーズの性質に応じて
`## 手順` / `## 実行順序` などの名称に変えてよい。

```markdown
---
description: （コマンド一覧で表示される 1 行説明）
---

# Phase N: タイトル

（このフェーズで何をするかの 1-2 段落）

## 前提                 ← 任意。テンプレ同梱ファイル等の前提条件がある場合
## 実行手順             ← 必須。番号付きで順序を明示
## このフェーズの完了基準   ← 必須。チェックリスト形式（- [ ]）
## やらないこと         　　　　　← 任意。他フェーズとの責務分担が不明瞭になりやすい場合
## 完了後               ← 必須。/verify 実行を促す
```

各セクションの役割:

| セクション | 必須/任意 | 役割 |
|---|---|---|
| `## 前提` | 任意 | テンプレ同梱ファイル等の前提条件 |
| `## 実行手順` | 必須 | 番号付きで順序を明示 |
| `## このフェーズの完了基準` | 必須 | チェックリスト形式（`- [ ]`） |
| `## やらないこと` | 任意 | 他フェーズの責務との切り分けが必要な場合 |
| `## 完了後` | 必須 | `/verify` 実行を促す |

### 5. 文体・形式

- 命令形（「〜する」「〜を実行」）。「〜しましょう」「〜してください」は避ける
- 番号付きリストは順序が意味を持つときのみ。それ以外は箇条書き
- 詳細な対応関係は Markdown テーブルで表現
- 冗長な前置きや結論の繰り返しは省く

## フェーズファイルのトライアル・改善（ヘッドレス実行）

コマンドファイル（`.claude/commands/scaffold-phaseN-xxx.md`）は、実際にフェーズを
実行してみないと気づけない不備（ライブラリの非対応バージョン、環境依存のコマンドの
失敗、手順の抜け漏れ等）を含みがちです。これを繰り返し検証・修正するための仕組みを
用意しています。

### bin/reset-phase.sh

`my-laravel-app/` をテンプレート状態（Laravel 未生成）に戻すスクリプトです。

```sh
bin/reset-phase.sh <フェーズ番号>
```

フェーズ番号は 1〜4 を指定できます。いずれを指定しても巻き戻し先は同じで、
開発サーバー停止・Docker コンテナ/ボリューム破棄・未追跡ファイル削除・
テンプレートファイルの復元を行い、白紙の状態まで戻します。

Phase 2 以降で「直前のフェーズ完了時点」まで戻さないのは、各フェーズの生成物
（`vendor/` / `.env` / 生成されたコード・マイグレーション）がいずれも git 管理外で、
中間状態を git だけで決定論的に再現できないためです。代わりに、リセット後は
Phase 1 から順に再実行する手順が実行結果として案内されます。

### ヘッドレスでのトライアル自動化

`prompts/trial-phase.md` に、対象フェーズの実行 → 問題点の洗い出し →
コマンドファイル/docs の修正 → `bin/reset-phase.sh` の更新 → コミットまでを自動で
行うためのプロンプトを用意しています。

```sh
claude -p "$(cat prompts/trial-phase.md)"
```

> このプロンプトを `.claude/` の外に置いているのは、Claude Code の
> センシティブファイル保護により `.claude/` 配下がヘッドレスセッションから
> 書き換えられないためです。トライアル中に判明した修正をその場で反映できるよう、
> 配置に制約のないファイルはリポジトリルート直下に置いています。

ファイル冒頭の「実行対象フェーズ」の1行を書き換えることで対象範囲を段階的に
広げられます（例: `Phase 1 のみ` → `Phase 1〜2`）。各フェーズの指示は最初から
全て書いてあるため、この1行以外の編集は不要です。

### patches/ — ヘッドレスからの申し送り

ヘッドレス実行が**その場で処理しきれなかったもの**を、次の対話セッションへ
渡すための置き場です。トライアルが 1 周して全て解決した状態では、
`.gitkeep` だけが残ります。中身は 2 種類あります。

| ファイル | 中身 | 対話セッションでの扱い |
|---|---|---|
| `patches/<ファイル名>.md` | `.claude/` 配下のファイルの**修正済み完全版** | 内容を確認して元の位置へ上書き適用し、適用後に削除 |
| `patches/issue-*.md` | **判断が必要で自動修正しなかった事項**の申し送り | 内容を読んで方針を決め、テンプレートへ反映してから削除 |

前者が必要なのは、Claude Code のセンシティブファイル保護により、ヘッドレス
セッションが `.claude/` 配下へ書き込めないためです（許可リストより優先されます）。
コピー元に指定する形も拒否されるため、ヘッドレス側は元ファイルを読んで修正を
織り込んだ全文を `patches/` に書き起こします。

後者は、**実行してみて分かったが、直し方をヘッドレスの単独判断で決めるべきでは
ないもの**です。妥当な解が複数ある方針の選択、`team-rules/` のルール自体の変更
（利用者の本番プロジェクトへ配布されるため）、再現条件が不確かなもの、権限や
ツールの制約で検証しきれなかったもの、テンプレートのスコープ外の事象が該当します。

加えて、**フェーズが成功していても申し送る**ものが 4 つあります。実行が止まらない
ぶん記録に残らず消えやすい一方、いずれも実際に走らせた人にしか観測できません。

- **許可リストの不足** — 権限で拒否されたコマンド。反映先の
  `.claude/settings.json` はヘッドレスから書き込めないため、ここを通さないと
  次回も同じところで止まります
- **手順書は正しいが誤読した箇所** — 記述は誤っていないが解釈を誤ったところ。
  放置すると他の利用者の Claude Code も同じ誤読をします
- **バージョン・環境の陳腐化** — 生成されたバージョンが手順書の想定と違う、
  非推奨警告が出た等。動くので失敗にはなりませんが、時間経過で必ず効いてきます
- **フェーズ境界のズレ** — 別フェーズでやるべき作業の混在、1 フェーズの肥大化

各ファイルには事象・エラー原文・選択肢・推奨案・「決めてほしいこと」が
書かれており、対話でそのまま議論を始められます。

判断基準と書式の詳細は `prompts/trial-phase.md` の「判断が必要な事項の申し送り」節、
対話セッション側の扱いはルート `CLAUDE.md` の「`patches/` の扱い」節にあります。

```sh
ls patches/          # トライアル後、未処理の申し送りが残っていないか確認する
```

## CLAUDE.md の文法メモ

- `@パス` で他の Markdown を再帰的に読み込めます（深くしすぎると
  コンテキストを食うので 1〜2 階層が目安）
- 階層: グローバル (`~/.claude/CLAUDE.md`) < 親ディレクトリの CLAUDE.md
  < 起動ディレクトリの CLAUDE.md < CLAUDE.local.md の順に重ね合わせ
- `.claude/commands/*.md` は `/コマンド名` でスラッシュコマンドとして
  呼べます（YAML frontmatter で `description` を付けると一覧表示される）

## Claude Code の権限設定について

このテンプレートには `my-laravel-app/.claude/settings.json`（共有用）が
同梱されており、Phase 1〜4 でよく使うコマンドパターンを許可リストに
入れてあります。これにより毎回の承認プロンプトが減ります。

セッション中に「Yes, and don't ask again」を選んだ項目は、個人ローカル用の
`my-laravel-app/.claude/settings.local.json`（gitignore 対象）に自動で蓄積されます。
そこから共有してよいパターンを選別して `settings.json` にマージしていくと、
次プロジェクトでさらに承認回数が減らせます。

## トラブルシューティング

### 想定外の挙動になった

その時点で `/verify` をかけて原因を切り分けるのが早道です。
破壊的操作の確認が出た際は、落ち着いて承認・拒否してください。

## 注意

- 生成中に Claude Code が破壊的操作（`rm -rf`, `migrate:fresh` 等）を行おうと
  した際は確認が入ります。`settings.json` の `deny` リストにも
  ガードを置いてあります
- `.env` はテンプレート同梱の `my-laravel-app/.gitignore` で
  除外済みです。`init-project.sh` 実行時に秘密情報がコミット候補に入っていないことを
  確認してください（スクリプト側でも検出ガードを設けています）
