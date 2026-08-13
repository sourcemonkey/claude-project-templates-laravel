# .env.example の APP_URL が、laravel new の時点で既に .env と一致していた

- フェーズ: Phase 1
- 状態: 未分類
- 初回観測: 2026-08-13
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase1-skeleton.md`（Step 7）は「`laravel new` は `.env` にだけ
`APP_URL=http://localhost:8000` を書き込み、`.env.example` は素の
`APP_URL=http://localhost`（ポートなし＝80 番）のまま残す」と記述している。

このトライアル（Laravel Installer 5.30.0 / `laravel/framework` v13.25.0）では、
`laravel new tmp-skeleton --no-interaction --pest` 直後の時点で `.env` と
`.env.example` の両方に `APP_URL=http://localhost:8000` が入っており、
記述されている不一致は発生しなかった。

## 根拠

`rsync` で配置した直後、`.env.example` を確認:

```
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8000
...
```

`.env` も同じく `APP_URL=http://localhost:8000`。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:302-316`

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「バージョン・環境の陳腐化」に該当する
（Laravel Installer / Framework のマイナーバージョン更新で生成物の挙動が
変わった可能性がある）。実行モデルが Sonnet 系のため、判断を伴う削除・圧縮は行わず
申し送る。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

この注意書き（`.env.example` の APP_URL がポートなしで生成される、という前提）を、
現在の Laravel Installer では再現しないものとして削除・圧縮してよいか。
それとも Installer のバージョンによって挙動が揺れる可能性を残し、
確認手順として維持するか。

## 暫定対応

なし（今回は `.env` / `.env.example` とも既に一致していたため、Step 7 の
「`APP_URL` も `.env.example` 側を揃える」の追加作業は不要だった。手順書は
未変更のまま）。
