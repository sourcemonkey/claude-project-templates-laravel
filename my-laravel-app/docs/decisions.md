# 技術選定の経緯（採用しなかった選択肢）

**このファイルは `docs/stack.md` の補足で、`CLAUDE.md` からは `@` 参照していない。**
実装中に常時読む必要はなく、次のいずれかに当たったときだけ Read すれば足りる。

- 「なぜこの構成なのか」「なぜ公式のやり方に従っていないのか」を確かめたいとき
- Laravel 14 のリリース後に 13 系を生成する必要が出たとき
- 採用しなかった選択肢（公式スターターキット / Herd / Sail / Valet）への変更を検討するとき

**規範は `docs/stack.md` にある。** 本ファイルは決定の理由と、決定を覆すときに
再確認すべき論点だけを持つ。

## 公式スターターキットを採用しない理由

Laravel 12 以降、`laravel new` は公式スターターキット（Livewire / React / Vue）を選択できる。**本プロジェクトではこれを採用せず、素の Laravel に Breeze を後入れする**（Phase 1 の `--no-interaction` がキット選択をスキップするのは意図した挙動）。

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

## Laravel 14 以降で 13 系を生成する

`laravel new` には**バージョン指定オプションが無い**（`NewCommand::getVersion()` は `--dev` 指定時のみ `dev-master` を返し、通常は空文字＝最新安定版）。内部で実行されるのは `composer create-project laravel/laravel "$dir" --remove-vcs --prefer-dist --no-scripts` であり、取得されるのは**その時点の `laravel/laravel` の最新安定版**である。Laravel 14 のリリース以降は同じコマンドが 14 を生成するため、Phase 1 は生成直後にメジャーバージョンを検証する。

14 以降で本テンプレートを使う必要が生じた場合は、`laravel new` をやめて次に置き換え、Installer が `--pest` で行っている処理を手順に展開する。

```sh
composer create-project laravel/laravel:^13.0 tmp-skeleton --remove-vcs --prefer-dist
```

1. `composer remove phpunit/phpunit --dev --no-update`
2. `composer require pestphp/pest pestphp/pest-plugin-laravel --no-update --dev`
3. `composer update`
4. `./vendor/bin/pest --init`
5. `pest-plugin-drift` による変換

13 系に留まるか 14 へ追随するかは、前節「公式スターターキットを採用しない理由」とあわせてユーザーが判断する。

## 公式のエージェント向けプレイブックとの差分

Laravel 公式は AI コーディングエージェント向けの手順書を
[laravel.com/for/agents](https://laravel.com/for/agents) で配布しており、インストールガイドは
「このページを取得して source of truth として扱え」というプロンプトをエージェントに
貼ることを勧めている。

**本プロジェクトではこのプロンプトを使わない。** 前提が複数の点で食い違っており、
そのまま従うと下表の決定がすべて上書きされる。2026-08-05 時点の記述との対比。

| 項目 | 公式プレイブック | 本プロジェクト | 理由 |
| --- | --- | --- | --- |
| 生成コマンド | `laravel new example-app --database=sqlite --react --npm --boost --no-interaction` | `laravel new tmp-skeleton --no-interaction --pest` | 差分の内訳は以下の各行 |
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
