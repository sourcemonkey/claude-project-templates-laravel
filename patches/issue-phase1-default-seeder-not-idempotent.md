# laravel new 既定の DatabaseSeeder が Test User を作り `composer run setup` を非冪等にする

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-24

## 何が起きたか

Phase 1 手順書 Step 9 の Step 6（`composer run setup` の一気通貫確認）を実行した。
初回は成功したが、`composer run setup`（内部で `@php artisan migrate --seed --force`）を
**2 回目に実行すると seed が一意制約違反で失敗する**。

原因は `laravel new` が生成する `database/seeders/DatabaseSeeder.php` が、固定メールアドレスの
Test User を `factory()->create()` で作る内容になっているため。`firstOrCreate` ではないので
2 回目の投入で `users.email` の UNIQUE 制約に衝突する。

手順書 Step 9-6 は「Phase 1 時点では Seeder が空なので `Seeding database.` のみ出る」と
記述しているが、実際には **Seeder は空ではなく Test User を 1 件作る**。出力に per-model の
DONE 行が出ないため「空」に見えるだけで、DB には 1 行挿入される。

## 根拠

`laravel new`（Laravel Framework 13.8）が生成した `database/seeders/DatabaseSeeder.php`:

```php
public function run(): void
{
    // User::factory(10)->create();

    User::factory()->create([
        'name' => 'Test User',
        'email' => 'test@example.com',
    ]);
}
```

初回 seed 後の users テーブル:

```
id	name	email
1	Test User	test@example.com
```

2 回目の `php artisan migrate --seed --force` の出力（抜粋）:

```
17  database/seeders/DatabaseSeeder.php:20
    Illuminate\Database\Eloquent\Factories\Factory::create(["Test User", "test@example.com"])
```
（`UniqueConstraintViolationException` で異常終了）

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:340`
  （Step 9-6「Phase 1 時点では Seeder が空なので `Seeding database.` のみ出る」）
- 関連ファイル: `my-laravel-app/database/seeders/DatabaseSeeder.php:20`（Phase 1 生成物・git 管理外）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「妥当な解が複数あり、どれを採るかが方針の選択になる」に該当する。
Phase 1 の「やらないこと」に「Seeder（Phase 4 で実施）」とあり、Phase 1 でシーダーへ手を
入れること自体が方針判断を含む。

## 選択肢

1. **Phase 1 で既定 DatabaseSeeder を空化する（factory 呼び出しを削除しコメントのみ残す）**
   — 影響: `composer run setup` が何度でも通り、手順書の「Seeder が空」という記述とも一致する。
   Phase 4 で `docs/seeds.md` の本 Seeder に置き換える前提と整合。
   懸念: Phase 1 が生成物のシーダーに手を入れることになり「Seeder は Phase 4」という
   フェーズ境界を少しまたぐ。ただし「空にする」は「作る」ではないので許容範囲とも言える。
2. **既定 DatabaseSeeder を `firstOrCreate` で冪等化する**
   — 影響: Test User を残しつつ再実行に耐える。懸念: Phase 4 でどうせ全面置換するため、
   Phase 1 でだけ生きる暫定コードを書くことになる。
3. **手順書 Step 9-6 の記述だけ直し、Seeder はそのまま**
   （「既定 Seeder が Test User を 1 件作る。`composer run setup` の再実行は Phase 4 で
   本 Seeder（冪等）に置き換わるまで非冪等」と明記する）
   — 影響: 生成物に触れない。懸念: 「クローンして 1 コマンドで動く」を売りにする setup が、
   2 回目に失敗する状態が Phase 4 まで残る。

## 推奨

案 1。Phase 1 の完了基準「`composer run setup` で一気通貫に動く」を再実行でも保てること、
手順書の既存記述（「Seeder が空」）とも一致することから、既定シーダーの factory 呼び出しを
削除（コメント化）するのが最も素直。削除は 1 箇所で修正が一意に定まる。

## 決めてほしいこと

Phase 1 で既定 DatabaseSeeder の Test User 生成を削除（空化）してよいか？（案 1 / 2 / 3）

## 暫定対応

なし（トライアルは初回 setup 成功により Phase 1 完了基準を満たしているため、回避策は
入れていない。テンプレート本体への差分もなし）。
