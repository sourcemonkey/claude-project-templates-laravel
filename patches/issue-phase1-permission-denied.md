# Phase 1 の完了基準 `composer run setup` がヘッドレスで実行できない

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

`scaffold-phase1-skeleton.md` の Step 9-6「`composer run setup` の一気通貫確認」と、
その中で使う `npm install --ignore-scripts` が、いずれもルートの
`.claude/settings.json` の許可リストに含まれておらず、ヘッドレス実行で拒否された。

Phase 1 のそれ以外の手順は、手順書の記載どおりに一度も手戻りせず完走している。
テンプレート側（手順書・docs・team-rules）に修正すべき記述の誤りは見つからなかった。

## 根拠

拒否されたコマンド（原文）:

```
composer run setup
```

```
npm install --ignore-scripts
```

いずれも `This command requires approval` で停止した。

現在の許可リストの該当箇所（`composer run dev` は個別に許可されているが `setup` は無い）:

```
      "Bash(composer install)",
      "Bash(composer require*)",
      "Bash(composer update)",
      "Bash(composer audit)",
      "Bash(composer dump-autoload*)",
      "Bash(composer show*)",
      "Bash(composer --version)",
```
```
      "Bash(composer run dev)",
```
```
      "Bash(npm install)",
      "Bash(npm run *)",
      "Bash(npm -v)",
```

- 関連ファイル: `.claude/settings.json:29-45`
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:301`（Step 9-6）
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:266-275`（`scripts.setup` の正規形）

## なぜ自動で直さなかったか

反映先の `.claude/settings.json` はセンシティブファイル保護によりヘッドレスから
書き込めない（手順 4 の「許可リストの不足」に該当）。加えて `composer run setup` の
許可は下記のとおり方針判断を含む。

## 選択肢

`composer run setup` の許可は、単なる書き漏れではなく方針の判断を伴う。
`scripts.setup` の中身は次のとおりで、**`@php -r "..."` を含む**。

```json
"setup": [
    "docker compose up -d --wait db",
    "composer install",
    "@php -r \"file_exists('.env') || copy('.env.example', '.env');\"",
    "@php artisan key:generate",
    "@php artisan migrate --seed --force",
    "npm install --ignore-scripts",
    "npm run build"
]
```

`prompts/trial-phase.md` の前提条件 2 は「`php -r '<code>'` は任意の PHP コードを
実行でき deny を迂回できるため意図的に許可リストへ含めない（今後も追加しない）」と
定めている。`composer run setup` を許可すると、この `php -r` が composer 経由で
間接的に実行されることになる。

1. **`Bash(composer run setup)` を完全一致で許可リストへ追加する** —
   影響: Step 9-6 がそのまま実行でき、完了基準を額面どおり検証できる /
   懸念: `php -r` の間接実行を認めることになる。ただし現状すでに `Edit` / `Write` が
   許可されており `composer.json` の `scripts` は書き換え可能なため、
   実効的な権限は増えない（`composer run *` のワイルドカードにすると
   任意スクリプト名を通すことになるので、完全一致に留める前提）
2. **許可リストへ追加せず、手順書に「ヘッドレスでは各ステップを分解して実行し、
   スクリプト本体の一気通貫確認は対話セッションで行う」と注記する** —
   影響: 権限方針は現状維持 / 懸念: 「スクリプトが最後まで通るか」自体は
   永久に自動検証されない。`setup` は「クローンして 1 コマンドで動く」ことが
   目的の正規形なので、そこが未検証のまま残る
3. **Step 9-6 を Phase 1 の完了基準から外す** —
   影響: 判定が単純になる / 懸念: `composer setup` へ一本化した直前のコミット
   （`e28ee8b`）の意図と逆行する

`npm install --ignore-scripts` の方は方針判断を含まない単純な許可漏れ。
`Bash(npm install)` を `Bash(npm install*)` に広げれば解消する。

## 推奨

案 1。`Edit` / `Write` が既に許可されている以上 `composer.json` の `scripts` は
書き換え可能で、`composer run setup` の許可が新たな権限昇格にはならない。
一方で得られるもの（正規形が一気通貫で通ることの自動検証）は Phase 1 の
完了基準そのものであり、代替手段がない。

あわせて `Bash(npm install)` → `Bash(npm install*)` も広げる。

## 決めてほしいこと

`.claude/settings.json` の許可リストに `Bash(composer run setup)`（完全一致）と
`Bash(npm install*)` を追加してよいか。

## 暫定対応

`composer run setup` の代わりに、スクリプトの各ステップを個別のコマンドとして
実行し、すべて成功することを確認した（`docker compose up -d --wait db` /
`composer install` / `php artisan migrate --seed --force` / `npm install` /
`npm run build`）。`@php -r "file_exists('.env') || copy(...)"` は `.env` が
既に存在するため実質 no-op で、スキップしても検証内容は変わらない。
`npm install --ignore-scripts` は許可されている `npm install` で代替した
（テンプレート同梱の `.npmrc` に `ignore-scripts=true` があるため挙動は同じ）。

**テンプレート本体には回避策を一切入れていない**（取り消すべき差分はない）。
