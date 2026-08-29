# 技術選定の経緯（採用しなかった選択肢）

**このファイルは `docs/stack.md` / `docs/setup.md` の補足で、`CLAUDE.md` からは `@` 参照していない。**
実装中に常時読む必要はなく、次のいずれかに当たったときだけ Read すれば足りる。

- 「なぜこの構成なのか」「なぜ公式のやり方に従っていないのか」を確かめたいとき
- 採用しなかった選択肢（公式スターターキット / Herd / Sail / Valet）への変更を検討するとき

**規範は `docs/stack.md` と `docs/setup.md` にある。** 本ファイルは決定の理由と、決定を覆すときに
再確認すべき論点だけを持つ。

## 公式スターターキットを採用しない理由

Laravel 12 以降、`laravel new` は公式スターターキット（Livewire / React / Vue）を選択できる。**本プロジェクトではこれを採用せず、素の Laravel に Breeze を後入れする**（`composer create-project laravel/laravel` はキットを含まない素の構成を生成する）。

公式 Livewire スターターキット（`laravel/livewire-starter-kit`、2026-07-19 時点）の構成と、本プロジェクトの方針との差:

| パッケージ | 差分 |
|---|---|
| `laravel/fortify` | 認証ロジックが vendor 側にあり、Controller / Form Request / ビューが publish されない |
| `livewire/flux` | UI コンポーネントライブラリ。`team-rules/coding-standards.md` の「Tailwind のユーティリティを基本とし、共通化は Blade コンポーネント」と競合する。Pro 版は有料 |
| `livewire/livewire ^4.1` | 本プロジェクトは v3 系（前掲の理由による） |
| `phpunit/phpunit` | 本プロジェクトは Pest |

採用しない理由は次の 2 点。

1. **本プロジェクトは Laravel の学習を兼ねる。** Breeze は認証の Controller・Form Request・ビューを `app/` と `resources/` へ publish するため、コードを読んで変更できる。Fortify はそれを vendor に隠し、設定で振る舞いを変える形になるため、認証の流れを追う教材にならない。
2. **Flux を入れると Blade コンポーネントと Tailwind を自分で組む機会が失われる。** `docs/screens.md` のレイアウト定義も `team-rules/coding-standards.md` の CSS 方針も、素の Blade + Tailwind を前提にしている。

> **`laravel/breeze` は非推奨でもアーカイブでもない。** 2026-07-19 時点の最新 v2.4.2（2026-05-14 リリース）が `illuminate/* ^11.0|^12.0|^13.0` として Laravel 13 を明示サポートしており、`breeze:install livewire` も現行の 2.x に存在する。`composer.json` に Breeze があるのを「メンテナンスが止まったパッケージ」と判断して公式スターターキットへ差し替えないこと。

## 公式のエージェント向けプレイブックとの差分

Laravel 公式は AI コーディングエージェント向けの手順書を
[laravel.com/for/agents](https://laravel.com/for/agents) で配布しており、インストールガイドは
「このページを取得して source of truth として扱え」というプロンプトをエージェントに
貼ることを勧めている。

**本プロジェクトではこのプロンプトを使わない。** 前提が複数の点で食い違っており、
そのまま従うと下表の決定がすべて上書きされる。2026-08-05 時点の記述との対比。

| 項目 | 公式プレイブック | 本プロジェクト | 理由 |
| --- | --- | --- | --- |
| 生成コマンド | `laravel new example-app --database=sqlite --react --npm --boost --no-interaction` | `composer create-project laravel/laravel:^13.0 tmp-skeleton --remove-vcs --prefer-dist --no-scripts` | 差分の内訳は以下の各行 |
| スターターキット | **React が既定**（Vue / Livewire / Svelte は要求時） | 採用しない。素の Laravel + Breeze を後入れ | 前節参照。`CLAUDE.md` の「JS フレームワークを導入しない」とも衝突する |
| データベース | `--database=sqlite` | MySQL（Docker） | MySQL 固有の DDL（`docs/db-schema.md` の CHECK 制約）を使う。`phpunit.xml` の SQLite 既定も書き換える |
| PHP の導入 | `php.new` で 8.5 を入れる | `.tool-versions` で 8.4.23 を固定 | 開発者間でバージョンを揃えるため |
| Laravel Boost | `laravel new --boost` | `composer require --dev` → `boost:install --mcp --guidelines` | ガイドラインの出力先を `config/boost.php` で `docs/boost-guidelines.md` へ退避する必要がある（`CLAUDE.md` を Boost に再生成させない） |
| デプロイ | `composer global require laravel/cloud-cli` + `cloud skills:install` | 行わない | グローバル環境を変更する。デプロイ先を定めていない |
| テスト | 言及なし | Pest（`--pest`） | — |

一方、次の考え方は妥当なので手順に反映してよい。

- 作業前に `php` / `composer` / `laravel` / `npm` のバージョンを確認する
- 既に Laravel アプリがあるならインストールを飛ばす
- ガイドラインはセッション内で読み込み、再起動を求めない
  （`CLAUDE.md` の `@docs/boost-guidelines.md` で達成済み）

> **このページはいつでも更新されうる。** 上表は取得時点のもので、追随の義務は負わない。
> 公式の記述が変わったからといって本プロジェクトの決定を自動的に変えないこと。
> 変更が必要と判断した場合は、この表を更新したうえでユーザーに提示する。

## 採用しなかった開発環境ツール（Herd / Sail / Valet）

ローカル開発環境として以下の公式・準公式ツールを検討した上で、「ホスト側 PHP（asdf / mise）+ DB のみ Docker」の構成を採っている。知らずに外したのではなく、選ばなかった理由は次のとおり。

- **Laravel Herd**: GUI アプリのためバージョンや設定をリポジトリ内で固定・共有できず、CI やヘッドレスの自動検証に組み込めない。MySQL 等の DB サービスは有料の Pro 機能であり、チーム標準の前提に置けない。
- **Laravel Sail**: PHP ごとコンテナ化するため全コマンドが `sail` ラッパー経由になり、IDE 統合や実行速度（macOS のバインドマウント）で不利。`php` / `composer` をホストで直接実行できる現構成を優先する。
- **Laravel Valet**: macOS 専用で、位置づけとして Herd に後継されている。新規採用する理由がない。

なお、開発者個人が Herd を併用すること自体は本構成と衝突しない（Herd がアプリを配信し、DB は本リポジトリの `compose.yaml` を使う形で共存できる）。ただしチーム共通の手順・CI・自動検証は本構成（`composer run dev` ベース）を正とする。

## 固定したバージョンを見直すタイミング

上流が動いていることに気づいても、**その場では追従しない**（`prompts/trial-phase.md` の
とおり `patches/issue-*.md` へ申し送る）。見直しは次のいずれかに当たったときだけ、
独立した作業として行う。それ以外の「新しい版が出ている」は理由にならない。

| 対象 | 上げるきっかけ | 一次情報 |
|---|---|---|
| PHP | セキュリティサポートが切れる / Laravel が要求下限を上げた。**パッチ版だけの更新は追わない** | `.tool-versions` |
| Node.js | Active LTS から外れた（Maintenance LTS 入りが合図） | `.tool-versions` |
| MySQL | イメージのタグ系列が EOL を迎えた | `compose.yaml` |
| Laravel | メジャー更新（13 → 14）。マイナー・パッチは `^13.0` の範囲で自動追従させる | 手順書 Step 3 の `create-project` の制約 |
| Composer パッケージ | 手順が失敗する / 上流が本プロジェクトの回避策を不要にした | `composer.json` |

数値を変えたら `bin/check-repo.sh` を走らせる。`docs/` 側の表記が追従していなければ
NG で落ちる。

**個別のパッケージへバージョンを固定しない。** このテンプレートは利用者の本番
プロジェクトへ配布され、書いた制約はそのまま利用者の `composer.json` に残る。
特定の版に釘付けにしてよいのは、**回避策としてその版が必要な場合だけ**で、
そのときは不要になる条件を注記に書く。
