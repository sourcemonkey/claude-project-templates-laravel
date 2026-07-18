# patches

ヘッドレス実行（`prompts/trial-phase.md`）中に判明した手順書の誤り・不足を反映した
**修正済みの完全版**を置くディレクトリ。

Claude Code のセンシティブファイル保護により、ヘッドレスセッションでは
`my-laravel-app/.claude/` 配下のファイルを書き換えられない（読み取りも `cp` 経由では
拒否される）。そのためここに完全版を置き、ユーザーが手動で適用する。

## 適用方法

```sh
cp patches/scaffold-phase1-skeleton.md my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md
cp patches/scaffold-phase3-ui.md       my-laravel-app/.claude/commands/scaffold-phase3-ui.md
rm -r patches
```

適用後は `patches/` を削除する。

## このパッチに含まれる修正

### `scaffold-phase1-skeleton.md`

- **Dusk の ChromeDriver をホストの Chrome に合わせる手順を追加**。
  `php artisan dusk:install` は「最新版」の ChromeDriver を入れるため、ホストの
  Google Chrome が 1 世代古いと Phase 3 の `php artisan dusk` が
  `session not created: This version of ChromeDriver only supports Chrome version NNN`
  で全滅する。`php artisan dusk:chrome-driver --detect` を続けて実行する。

### `scaffold-phase3-ui.md`

- **Breeze 生成物の `dashboard` / `profile` ルート依存への追従手順**を追加
  （`docs/api-spec.md` の全体構造にこの 2 ルートが無いため、そのまま置き換えると
  `route('dashboard')` が `RouteNotFoundException` になり Breeze の Feature テストが壊れる）
- **基底 Controller への `AuthorizesRequests` 取り込み**を明記
  （Laravel 11 以降は既定で外れており `$this->authorize()` が使えない）
- **認可エラーの `render()` は `AccessDeniedHttpException` を型に取る**ことを明記
  （`AuthorizationException` 指定ではコールバックが発火しない）
- **Spatie Query Builder v7 の可変長引数**と **Eager Load を `for()` 側に置く**注意を追加
- **`x-admin-layout` にはクラスコンポーネントが必要**であることを明記
- **Dusk の `signInAs` に `logout()` が必須**であること、**`.env.dusk.local` の作成**を追加
