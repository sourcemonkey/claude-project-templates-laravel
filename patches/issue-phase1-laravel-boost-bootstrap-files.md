# composer create-project の生成物に CLAUDE.md / AGENTS.md が同梱されるようになった

- フェーズ: Phase 1
- 状態: 未分類
- 初回観測: 2026-08-29
- 実行モデル: claude-sonnet-5

## 何が起きたか

Step 3 の `composer create-project -q laravel/laravel:^13.0 tmp-skeleton --remove-vcs --prefer-dist --no-scripts`
実行後、`rsync -a --exclude=/.gitignore --exclude=/.npmrc tmp-skeleton/ .` で配置したところ、
テンプレート同梱の `my-laravel-app/CLAUDE.md`（プロジェクト仕様への `@` 参照を含む）が
`laravel/laravel` 同梱の Laravel Boost ブートストラップ用 `CLAUDE.md` で上書きされた。
`git status --short -- .gitignore .npmrc .claude compose.yaml docker .tool-versions CLAUDE.md docs`
で検出し、`git checkout -- CLAUDE.md` でテンプレート版へ復旧した。

あわせて、テンプレートに存在しない `AGENTS.md` も生成物として新規に配置された
（`.gitignore` に `CLAUDE.md` 用の除外規則はあるが `AGENTS.md` の除外規則は無い）。

## 根拠

```
$ git status --short -- .gitignore .npmrc .claude compose.yaml docker .tool-versions CLAUDE.md docs
 M CLAUDE.md
```

上書きされた `CLAUDE.md` の内容（先頭）:

```
<laravel-boost-guidelines>
# Laravel Application

This repository contains a Laravel application. Complete the following setup before working on the user's request.
...
Install Laravel Boost from the application root before making application changes:

composer require laravel/boost --dev
php artisan boost:install

Boost replaces these bootstrap instructions with guidelines tailored to the application. After installation, read `AGENTS.md` again and continue with the user's original request using the generated guidelines.
</laravel-boost-guidelines>
```

生成された `composer.json` の関連バージョン:

```
"php": "^8.3",
"laravel/framework": "^13.17",
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:92-106`（rsync による配置手順、`--exclude` は `/.gitignore` と `/.npmrc` の 2 つのみ）
- 関連ファイル: `my-laravel-app/.gitignore:63-65`（`/CLAUDE.local.md` の除外規則はあるが、生成物の `CLAUDE.md` 本体・`AGENTS.md` への言及は無い）

## なぜ自動で直さなかったか

実行モデルが Sonnet 系のため、「実行モデル」節の規則により手順書
（`.claude/commands/scaffold-phase1-skeleton.md`）の修正は明白な誤字脱字に該当せず、
判断を伴うものとして `patches/` へ回した。また `.claude/` 配下はヘッドレスから
直接書き込めない（前提条件 5）。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

`rsync` の `--exclude` に `/CLAUDE.md` を追加すべきか。また新規に生成される
`AGENTS.md` をテンプレートとしてどう扱うか（`--exclude` で持ち込まない/`.gitignore`
へ追加/削除の手順を明記、のいずれか）。

## 暫定対応

`git checkout -- CLAUDE.md` でテンプレート版へ復旧した（本セッションの Phase 1 実行は
この状態で続行する）。`AGENTS.md` は未対応のまま残っており、後続手順で `git status`
チェックに引っかかる可能性がある。テンプレート本体への差分は加えていない。
