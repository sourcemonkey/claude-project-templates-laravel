# 「レイアウトのスタイル」の配色指定が Breeze 生成物のボタンコンポーネントにも及ぶか不明

- フェーズ: Phase 3
- 状態: 未分類
- 初回観測: 2026-08-16
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase3-ui.md` の「レイアウトのスタイル（実装ブレ防止のため明示）」節は
プライマリボタンを `bg-indigo-600 ... hover:bg-indigo-700`、危険ボタンを
`bg-red-600 ... hover:bg-red-700` と固定している。

一方、Phase 1 の Breeze（Livewire スタック）が生成する
`resources/views/components/primary-button.blade.php` は既定で `bg-gray-800` を、
`danger-button.blade.php` は `hover:bg-red-500` を使っており、上記の指定と一致しない。
この 2 つのコンポーネントは新規実装する画面（蔵書・貸出・カテゴリ等）でも
`x-primary-button` / `x-danger-button` としてそのまま再利用する前提になっている
（`docs/architecture.md` は Livewire コンポーネントの記法についてのみ Breeze 生成物と
新規実装の混在を戒めており、Blade コンポーネントの配色については触れていない）。

今回はコンポーネント自体の class を手順書の配色に書き換え、認証画面（ログイン等）を
含め全画面で統一する実装にした。

## 根拠

`my-laravel-app/.claude/commands/scaffold-phase3-ui.md`（「レイアウトのスタイル
（実装ブレ防止のため明示）」節）:

> - プライマリボタン: `bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700`
> - 危険ボタン（削除等）: `bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700`

変更前の `resources/views/components/primary-button.blade.php`（Breeze 生成のまま）:

```
bg-gray-800 ... hover:bg-gray-700 focus:bg-gray-700 active:bg-gray-900
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md`（レイアウトのスタイル節）
- 関連ファイル: `my-laravel-app/resources/views/components/primary-button.blade.php`
- 関連ファイル: `my-laravel-app/resources/views/components/danger-button.blade.php`

## なぜ自動で直さなかったか

`--model sonnet` での実行のため、判断を伴うものはすべて `patches/` へ回す
（`prompts/trial-phase.md` の「実行モデル」節）。分類も同じ理由で行っていない。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

「レイアウトのスタイル」節の配色指定は、Breeze 生成物のボタンコンポーネント
（`x-primary-button` / `x-danger-button`）にも適用してよいか。適用してよい場合、
その旨を手順書に明記すべきか（Breeze 生成物への変更は Phase 3 の「Breeze 生成物の
追従」節に列挙されたもの以外は想定されていないように読めるため）。

## 暫定対応

`resources/views/components/primary-button.blade.php` の配色を
`bg-indigo-600 hover:bg-indigo-700 focus:bg-indigo-700 active:bg-indigo-800` に、
`danger-button.blade.php` の `hover:bg-red-500` を `hover:bg-red-700` に、
`active:bg-red-700` を `active:bg-red-800` に変更した（`my-laravel-app` の該当ファイル）。
認証画面を含む全画面のボタン配色が統一されている。
