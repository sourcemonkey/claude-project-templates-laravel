# Step 5 の `composer require --dev larastan/larastan laravel/dusk laravel-lang/lang laravel/boost` が guzzle 8 系ロックと衝突して失敗する

- フェーズ: Phase 1
- 状態: 未分類
- 初回観測: 2026-08-19
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase1-skeleton.md` Step 5 の

```sh
composer require -q --dev larastan/larastan laravel/dusk laravel-lang/lang laravel/boost
```

を手順書どおりの引数で実行すると `exit code 2` で失敗した。`laravel/boost` のみ・
`larastan/larastan laravel/dusk laravel-lang/lang` の3つのみ、のどちらの組み合わせでも
同様に失敗した。

## 根拠

```
Problem 1
    - Root composer.json requires laravel/boost * -> satisfiable by laravel/boost[v1.0.0, ..., v2.5.4].
    - laravel/boost[v1.0.0, ..., v1.8.13, v2.0.0, ..., v2.5.4] require guzzlehttp/guzzle ^7.9 -> found guzzlehttp/guzzle[7.9.0, ..., 7.15.3] but the package is fixed to 8.0.2 (lock file version) by a partial update and that version does not match. Make sure you list it as an argument for the update command.
```

```
Problem 1
    - Root composer.json requires laravel/dusk * -> satisfiable by laravel/dusk[v1.0.0, ..., v8.6.0].
    - laravel/dusk[v7.8.1, ..., v7.13.0] require guzzlehttp/guzzle ^7.2 -> found guzzlehttp/guzzle[7.2.0, ..., 7.15.3] but the package is fixed to 8.0.2 (lock file version) by a partial update and that version does not match. Make sure you list it as an argument for the update command.
    - laravel/dusk[v8.0.0, ..., v8.6.0] require guzzlehttp/guzzle ^7.5 -> found guzzlehttp/guzzle[7.5.0, ..., 7.15.3] but the package is fixed to 8.0.2 (lock file version) but that version does not match.
```

`composer.lock` を確認すると、Step 3 の `composer create-project laravel/laravel:^13.0` の
時点で `guzzlehttp/guzzle` が `8.0.2` にロックされていた。`laravel/framework` の要求は
`"guzzlehttp/guzzle": "^7.8.2 || ^8.0"`（7系・8系どちらも許容）だが、新規解決時に
composer が 8.0.2 を選んだ。`laravel/dusk`（最新 v8.6.0 含む全バージョン）と
`laravel/boost`（最新 v2.5.4 含む全バージョン）はいずれも guzzle 7.x までしか許容していない。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:180-182`

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「妥当な解が複数あり、どれを採るかが方針の選択になる」に当たる。

## 選択肢

未記入(判定は対話セッションで行う)。

## 推奨

未記入(判定は対話セッションで行う)。

## 決めてほしいこと

未記入(判定は対話セッションで行う)。

## 暫定対応

`composer require --dev -W larastan/larastan laravel/dusk laravel-lang/lang laravel/boost`
（`-W` / `--with-all-dependencies` を付与)で実行したところ、`guzzlehttp/guzzle` が
`8.0.2` → `7.15.3` にダウングレードされ、`guzzlehttp/promises`（3.0.1→2.5.2）・
`guzzlehttp/psr7`（3.0.0→2.13.0）も連動してダウングレードされたうえで全パッケージが
インストールできた。`laravel/framework` は `^13.17` のまま変化なし。このトライアルは
この回避策でフェーズを完走させた。**手順書 Step 5 のコマンド例には `-W` を反映していない**
ため、決着後に手順書へ反映するかどうかの判断が要る。
