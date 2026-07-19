# `composer require livewire/livewire` は v3 ではなく v4 に解決される（volt は v4 も許容している）

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

`scaffold-phase1-skeleton.md` Step 6 で、Breeze 導入後に
`composer require livewire/livewire` を実行したところ、手順書が想定する v3 系ではなく
**v4.3.3 が入り、`breeze:install livewire` が入れた v3.8.2 を上書きした**。

手順書・`docs/stack.md` はどちらも「`livewire/volt` が v3 に制約しているので
バージョン指定は不要」と書いているが、この前提が事実と異なる。

## 根拠

`composer require livewire/livewire` の出力:

```
Lock file operations: 0 installs, 1 update, 0 removals
  - Upgrading livewire/livewire (v3.8.2 => v4.3.3)
```

`vendor/livewire/volt/composer.json`（v1.10.5）の require:

```
        "php": "^8.1",
        "laravel/framework": "^10.38.2|^11.0|^12.0|^13.0",
        "livewire/livewire": "^3.6.1|^4.0"
```

volt は `^3.6.1|^4.0` を許容しており、v3 に制約していない。

該当する手順書・docs の記述:

- `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:146`
  > この時点では `livewire/volt` が既に入っているため、composer はその制約下で解決し v3 系が入る（バージョン指定は不要。Step 5 の注記参照）。
- `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:123-127`
  > バージョン制約を持っているのは Breeze（`livewire/volt` 経由）であり、先に入れるとこの時点の最新（v4 系）で解決されたあと Step 6 の `breeze:install livewire` で v3 系へ入れ直される。
- `my-laravel-app/docs/stack.md`「フレームワーク・主要パッケージ」
  > **Livewire は v3 系を使う。** 上流の最新は v4 系だが、`laravel/breeze`（Livewire スタック）が依存する `livewire/volt` が v3 に制約しているため。

なお、v4.3.3 のままでも Phase 1 の完了基準はすべて通った（`php artisan test` 26 件 green、
`/` `/login` `/register` がいずれも 200、ログインフォームの Volt コンポーネントも描画された）。
**v4 が壊れるという観測はこの時点では得られていない。**

## なぜ自動で直さなかったか

「妥当な解が複数あり、どれを採るかが方針の選択になる（バージョンの下限）」に当たるため。
v3 に固定するか v4 を受け入れるかは、Phase 3 で書く Livewire コンポーネントの記法・
Breeze 生成物との整合をどう扱うかの方針判断であり、ヘッドレスで決めるべきではない。

## 選択肢

1. **v3 に固定する** — 手順書を `composer require "livewire/livewire:^3.6"` に変え、
   `docs/stack.md` の「volt が v3 に制約している」という**誤った理由**を
   「Breeze v2.x の生成物が v3 前提のため意図的に固定する」に書き換える。
   影響: 現状の docs の意図（v3）を維持できる / 懸念: 上流の v4 から取り残される。
   固定の根拠が「Breeze の生成物が v3 前提」だけになるため、Breeze v3 が出たら再判断が要る
2. **v4 を受け入れる** — 手順書は現状（バージョン指定なし）のままとし、
   `docs/stack.md` の「v3 系を使う」節を削除する。
   影響: 上流最新に追随できる / 懸念: Phase 3 で Breeze の Volt 生成物と
   自前の v4 コンポーネントが混在する。v4 の記法差分を Phase 3 手順書へ反映する作業が発生し、
   影響範囲が未検証
3. **`livewire/livewire` を明示的な依存として宣言しない** — volt の推移的依存に任せる。
   影響: バージョン管理が Breeze 側に一本化される / 懸念: 自前で Livewire コンポーネントを
   書くのに直接依存を宣言しない形になり、`docs/stack.md` の「種別: ルート」と矛盾する

## 推奨

案 1（v3 固定）。`docs/stack.md` が明示的に v3 を選んでおり、Breeze v2.4.2 の生成物も
v3 前提であるため、意図した状態を機械的に再現できる形にするのが筋。案 2 は Phase 3 の
検証をやり直す必要があり、今回のトライアルの範囲では影響を確かめられていない。

## 決めてほしいこと

Livewire を `^3.6` に固定してよいか（Yes = 案 1 / No = 案 2 か 3 を選ぶ）。

## 暫定対応

トライアルを Phase 2〜3 へ進めるため、**案 1 相当の暫定処置を入れてある**:

- `my-laravel-app/composer.json` の require を `"livewire/livewire": "^3.6"` にした
  （`composer require "livewire/livewire:^3.6"` を実行。v4.3.3 → v3.8.2 へダウングレード）
- **これは `my-laravel-app` 側の生成物に対する処置であり、テンプレート
  （手順書・docs）には手を入れていない。** 案 2 / 3 を採る場合、テンプレート側に
  取り消すべき差分はない
