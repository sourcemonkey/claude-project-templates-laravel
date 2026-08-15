# `docs/seeds.md` は `LendingSeeder` の mass assignment ガードに触れていない

- フェーズ: Phase 5
- 状態: 未分類
- 初回観測: 2026-08-16
- 実行モデル: claude-sonnet-5

## 何が起きたか

`docs/seeds.md` の `UserSeeder` 節には「`role` は `firstOrCreate()` の第2引数で渡さないこと
（Mass assignment 対象外のため黙って捨てられる）」という明示的な注意書きがある。

`LendingSeeder` を実装する際、`app/Models/Lending.php` の `$fillable` を確認したところ
`['user_id', 'book_id', 'requested_at', 'note']` のみで、**`state` / `approved_at` /
`due_on` / `returned_at` は User の `role` と同じ理由でガードされている**ことが分かった。
`docs/seeds.md` にはこの注意書きが無いため、`firstOrCreate()` の第2引数にこれらを含めて
実装すると（`role` と全く同じパターンで）例外を出さずに黙って無視され、**全 5 件の貸出が
`Requested` のまま作られる**（実際には気付いて回避したため発生していない）。

## 根拠

`my-laravel-app/app/Models/Lending.php`:

```php
protected $fillable = [
    'user_id',
    'book_id',
    'requested_at',
    'note',
];
```

`my-laravel-app/docs/seeds.md:17-27`（`UserSeeder` の `role` の注意書き。同種の注意が
`LendingSeeder` には無い）。

## なぜ自動で直さなかったか

`--model sonnet` での実行のため、判断を伴うものはすべて `patches/` へ回す
（`prompts/trial-phase.md` の「実行モデル」節）。分類も同じ理由で行っていない。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

`docs/seeds.md` の `LendingSeeder` 節（または `冪等キー` 表の直後）に、`role` と同様の
注意書き（`state` / `approved_at` / `due_on` / `returned_at` は `firstOrCreate()` の
第2引数に渡さず、取得後に明示代入すること）を追記すべきか。

## 暫定対応

`LendingSeeder`（`my-laravel-app/database/seeders/LendingSeeder.php`）は
`firstOrCreate()` を `user_id` / `book_id` / `requested_at` のみで呼び、
`state` / `approved_at` / `due_on` / `returned_at` は取得後に明示代入して `save()` する
実装にした。動作は確認済み（`docs/seeds.md` の貸出 5 状態が正しく投入され、
`db:seed` を 2 回実行しても冪等）。テンプレート本体（`docs/seeds.md`）への
反映は行っていない。
