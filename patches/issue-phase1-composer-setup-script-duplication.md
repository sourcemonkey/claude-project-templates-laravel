# Laravel 13.20 の `laravel new` が `composer setup` を生成するため、`bin/setup` が二重管理になっている

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

Phase 1 手順書 Step 8「dev スクリプトの調整と bin/setup の作成」は、`bin/setup` を
新規作成する理由を次のように書いている。

> 一方、セットアップには Laravel に相当する標準スクリプトが無いため、`bin/setup` を新規作成する。

しかし `laravel new`（Laravel Framework 13.20.0 / Laravel Installer 5.30.0）が生成する
`composer.json` には、すでに `setup` スクリプトが含まれていた。前提が事実と食い違っている。

同じ Step 8 は `bin/dev` を作らない理由を「`composer.json` 側との二重管理になるため」と
説明しているが、`composer setup` が存在する現在、その理屈はそのまま `bin/setup` にも当てはまる。

## 根拠

`laravel new tmp-skeleton --no-interaction --pest` が生成した `composer.json`:

```json
    "scripts": {
        "setup": [
            "composer install",
            "@php -r \"file_exists('.env') || copy('.env.example', '.env');\"",
            "@php artisan key:generate",
            "@php artisan migrate --force",
            "npm install --ignore-scripts",
            "npm run build"
        ],
```

手順書が作らせる `bin/setup`:

```sh
#!/usr/bin/env bash
set -euo pipefail

docker compose up -d --wait db

composer install
npm install
php artisan migrate --seed
```

両者は包含関係にない。`composer setup` にしかないもの: `.env` のコピー / `key:generate` /
`npm run build`。`bin/setup` にしかないもの: **DB コンテナの起動**（本プロジェクトの前提）と
`--seed`。どちらか一方だけを実行しても初回セットアップは完了しない。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:233`
- 関連ファイル: `my-laravel-app/docs/stack.md`（「起動・開発コマンド」表の `bin/setup` 行、
  および「開発サーバー起動（正規形）」節の二重管理に関する記述）

## なぜ自動で直さなかったか

手順 4 の「妥当な解が複数あり、どれを採るかが方針の選択になる」に当たる。
`bin/setup` を正とするか `composer setup` を正とするかで、docs・手順書・完了基準の
書き換え範囲が変わる。

## 選択肢

1. **`bin/setup` を正とし、`composer.json` の `setup` スクリプトを削除する** —
   影響: Step 8 に「`laravel new` が生成する `setup` スクリプトを削除する」を追記。
   `dev` から `queue:listen` を落とすのと同じ扱いで一貫する / 懸念: `bin/setup` が
   `.env` コピーと `key:generate` を持たないため、そのままでは初回セットアップが
   通らない。`bin/setup` 側にこの 2 つを足す必要がある
2. **`composer setup` を正とし、`bin/setup` を作らない** — 影響: `bin/dev` を作らない
   方針と完全に揃う。`composer setup` の先頭に `docker compose up -d --wait db` を挿し、
   `migrate --force` を `migrate --seed` に変える編集で済む / 懸念: `docs/stack.md` の
   コマンド表と Phase 1 完了基準の `bin/setup` 記述を全面的に書き換える必要がある
3. **併存させ、役割の違いを手順書に明記する** — 影響: 変更が最小 / 懸念: 「どちらを
   叩けばよいか」が利用者に伝わらない。二重管理は解消しない

## 推奨

案 2。`bin/dev` を作らない理由としてすでに「`composer.json` 側との二重管理を避ける」を
テンプレートの方針として掲げており、同じ理由が同じ強さで `bin/setup` にも当てはまる。
方針を 1 つに保つほうが、利用者が読んだときに迷わない。

## 決めてほしいこと

セットアップの正規形を `composer setup`（案 2）に寄せてよいか。それとも `bin/setup`
（案 1）を正としたいか。

## 暫定対応

手順書の記述どおり `bin/setup` を作成し、`composer.json` の `setup` スクリプトは
生成されたまま残した（両方が存在する状態）。`bin/setup` の一気通貫確認は成功している
（Phase 1 時点では `.env` と `APP_KEY` が手順の別ステップで用意済みのため、
`bin/setup` に不足があっても表面化しない）。テンプレート本体への差分はなし。
