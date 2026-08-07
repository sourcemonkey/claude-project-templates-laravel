# Phase 2 で自力回復した失敗の記録

- フェーズ: Phase 2
- 状態: 未分類
- 初回観測: 2026-08-07
- 実行モデル: claude-sonnet-5

## 何が起きたか

Phase 2（`/scaffold-phase2-models` 相当の手順を直接実行）の中で、以下の失敗が発生し、
いずれも自力で回復した。手順書の記述に誤りは無く、実行側（自分）のミスによるもの。

### 1. カレントディレクトリの取り違え（`make:model` 実行時）

直前の `php artisan make:migration ... --table=users` 呼び出しで `cd my-laravel-app &&` を
付けて実行し成功していたが、Bash ツールのカレントディレクトリはその後の呼び出しにも持続する。
続けて同じ `cd my-laravel-app && php artisan make:model Category -mf --no-interaction` を
実行したところ、既に `my-laravel-app/` にいたため `cd` が失敗した。

```
(eval):cd:1: no such file or directory: my-laravel-app
```

`pwd` で確認して回復し、以降は `cd` を付けずに実行した。

### 2. `bin/check-repo.sh` のパス取り違え

完了基準の確認で `cd ..`（`my-laravel-app/` → リポジトリルートのつもり）の後に
`bin/check-repo.sh` を実行したが、この呼び出し時点では既にリポジトリルートにいたため
問題は起きなかった一方、直後に**リポジトリルートから** `bin/check-repo.sh` を実行して
失敗した。

```
(eval):1: no such file or directory: bin/check-repo.sh
```

`ls bin/` でルート直下の `bin/` を確認したが対象スクリプトが無く、`ls my-laravel-app/bin/` で
`check-repo.sh` がそちらにあることが分かり、`cd my-laravel-app` してから再実行して回復した。

### 3. `git status` の pathspec 誤り

リポジトリルートにいる状態で `git status --short -- . ../prompts` を実行し、
`../prompts` がリポジトリの外を指すとしてエラーになった。

```
fatal: ../prompts: '../prompts' is outside repository at '/Users/fumiaki.sato/works/.../claude-project-templates-laravel'
```

`pwd` で確認するとリポジトリルートにいたため、`../prompts` ではなく `prompts` と
書くべきだった。相対パスをその場で修正して回復した。

### 4. モデルテストの初回失敗（`role` が null）

`tests/Unit/Models/UserTest.php` を先に書いてから `UserFactory` に `role` の明示値を
追加する順序にしたため、初回の `php artisan test tests/Unit/Models` で 2 件失敗した。

```
Failed asserting that null is an instance of class App\Enums\UserRole.
Failed asserting that null is identical to an object of class "App\Enums\UserRole".
```

`docs/db-schema.md` 側ではなく `.claude/commands/scaffold-phase2-models.md` の
ファクトリ節に「`definition()` にも `'role' => UserRole::Member` を明示すること」と
明記されており、これを最初の `UserFactory` 編集時点で反映していなかったことが原因。
`UserFactory::definition()` に `role` を追加して回復した。

### 5. モデルテストの 2 回目の失敗（`fresh()` の付け忘れ）

上記 4 を修正した直後、`role is not mass assignable` テストが 1 件失敗した。

```
Failed asserting that null is identical to an object of class "App\Enums\UserRole".
```

`User::create()` 直後のインスタンスは DB 側の `default(0)` を反映しないため、
`$user->role` ではなく `$user->fresh()->role` を読む必要があった。これも
手順書の「`created_at` は生成直後のインスタンスに載らない」と同じ理屈の別事例として
既に文書化されている挙動だが、テストコード側で `fresh()` を付け忘れていた。
`->fresh()` を挟んで回復した。

## なぜ自動で直さなかったか

いずれも手順書・docs の記述誤りではなく、実行側（自分）の作業順序・パス指定の
ミスであり、直す対象が手順書側に無い。「共通の進め方」手順 3 の「自力で回復した
失敗も記録する」に従い、記録のみ行う。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

上記 1〜3（パス取り違え系）は `prompts/trial-phase.md` に既に類例が記載されている
既知の失敗パターン（Bash ツールのカレントディレクトリ持続・`patches/` と `bin/` が
ルートと `my-laravel-app/` の両方に存在する）の再発であり、追加の対策が要るか、
既存の注意書きで許容範囲とするかの判断を仰ぎたい。上記 4〜5 はテストコードを書く
際の自己確認不足であり、手順書側の対応は不要と考えられるが、念のため申し送る。

## 暫定対応

すべてその場で自力回復済み。テンプレート本体への回避策の混入は無い。
