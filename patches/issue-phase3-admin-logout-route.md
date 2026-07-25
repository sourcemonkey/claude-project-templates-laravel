# 管理画面レイアウトのログアウト機構が docs / 手順書で未規定

- フェーズ: Phase 3
- 状態: 未解決
- 初回観測: 2026-07-25

## 何が起きたか

Phase 3 で `layouts/admin.blade.php`（管理者向けレイアウト）を作成する際、
`docs/screens.md` の管理者レイアウト図はヘッダに「▾」（ユーザーメニュー相当）を
持つが、**ログアウトの実現方法がどこにも規定されていない**。

- メンバー向けの `layouts/app.blade.php` は Breeze 生成の
  `<livewire:layout.navigation />` を使い、ログアウトは Volt コンポーネント内の
  `wire:click="logout"`（`App\Livewire\Actions\Logout` を呼ぶ）で行う。
- 一方 `layouts/admin.blade.php` は素の Blade で、Livewire ナビを持たない。
  ここからログアウトする手段が `docs/api-spec.md` の `routes/web.php` にも
  手順書にも無い（そもそも `logout` という名前付きルートが存在しない）。

`docs/api-spec.md` の `routes/web.php`（一次情報）には login / register 等の
Breeze 認証ルート（`require __DIR__.'/auth.php'`）はあるが、**`logout` ルートは
含まれない**。Breeze の Livewire スタックはログアウトを名前付きルートではなく
Volt コンポーネントのアクションとして提供するため、`route('logout')` は未定義になる。

## 根拠

管理レイアウトからログアウトフォームを出すと、`route('logout')` が未定義で 500 になる:

```
Symfony\Component\Routing\Exception\RouteNotFoundException: Route [logout] not defined.
```

`docs/api-spec.md` の `routes/web.php`（抜粋）には logout が無い:

```php
require __DIR__.'/auth.php'; // Breeze が生成する認証ルート群（login / register / forgot-password 等）
Route::get('/', [HomeController::class, 'index'])->name('home');
Route::middleware('auth')->group(function () {
    // ... logout は無い ...
```

- 関連ファイル: `my-laravel-app/docs/api-spec.md`（全体構造の `routes/web.php`）
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md:14`（レイアウト作成の指示）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「妥当な解が複数あり、どれを採るかが方針の選択になる」に
該当する。`docs/api-spec.md` の routes は一次情報であり、そこに無いルートを
ヘッドレスの単独判断で恒久追加すると、他の実装者と齟齬が出る。

## 選択肢

1. **`POST /logout` 名前付きルートを追加する** — `docs/api-spec.md` の `routes/web.php`
   に `Route::post('/logout', ...)->name('logout')`（`App\Livewire\Actions\Logout` を
   呼んで `home` へリダイレクト）を明記し、両レイアウトから `route('logout')` で
   参照する。影響: api-spec に 1 ルート追加 / 懸念: Breeze の Livewire ログアウト
   （Volt の `wire:click`）と経路が 2 系統になる
2. **管理レイアウトからも Livewire のログアウトを使う** — admin ヘッダに
   `<livewire:layout.navigation />` 相当か、ログアウト専用の小さな Livewire /
   Volt コンポーネントを埋め込み、名前付きルートを増やさない。影響: ルート追加なし /
   懸念: 管理レイアウトに Livewire コンポーネント依存が増える（`@livewireScripts`
   は既に必須なので追加コストは小さい）

## 推奨

案 1。ログアウトはリソース操作ではなく単純な POST で、名前付きルートがある方が
Blade レイアウト・テスト（`assertRedirect(route('logout'))` 等）から扱いやすい。
`docs/api-spec.md` に 1 行追記し、手順書の「Breeze 生成物の追従」節に
「管理レイアウト用に `logout` ルートを足す」を明記するのが最小の修正。

## 決めてほしいこと

管理画面のログアウトを、案 1（`POST /logout` 名前付きルートを api-spec に追加）で
統一してよいか？（No の場合は案 2 でルート追加なしにする）

## 暫定対応

トライアルを先に進めるため、案 1 の暫定実装を入れてある（成果物のため commit は
しないが、決着まで手順書・docs には反映していない）:

- `my-laravel-app/routes/web.php` の auth グループ内に
  `Route::post('/logout', fn (Logout $logout) => ...)->name('logout')` を追加
- `my-laravel-app/resources/views/layouts/admin.blade.php` のヘッダに
  `route('logout')` への POST フォームを設置

決着後、選んだ案に合わせて `docs/api-spec.md` と
`.claude/commands/scaffold-phase3-ui.md` に反映が必要。
