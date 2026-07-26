# Livewire Volt

**本プロジェクトでは Volt を新規コンポーネントに使わない。** Boost の組み込みガイドラインを
本ファイルで上書きしている（`docs/architecture.md` の「View / Livewire」節が一次情報）。

- Volt 記法を維持するのは、Breeze が生成した認証・プロフィール画面
  （`resources/views/livewire/pages/auth/*.blade.php`、`resources/views/livewire/profile/*.blade.php`）**だけ**。
  生成物はそのまま使い、Volt を他の画面へ広げない。
- **新規の Livewire コンポーネントはクラスベース**（`app/Livewire/`）で書く。記法が混在すると
  読み手がコンポーネントの所在を推測できなくなるため。
- 既存の Volt コンポーネントを編集する場合に限り、functional / class-based のどちらかを
  既存の書き方に合わせる。
