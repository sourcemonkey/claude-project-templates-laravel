---
description: 現在のフェーズの完了基準を満たしているかセルフチェックする
---

# Verify: セルフチェック

直前に完了したフェーズの完了基準を満たしているか確認する。

## 共通チェック

すべてのフェーズで以下を確認:

1. `php artisan migrate:status` — 全マイグレーションが `Ran`
2. `php artisan test` — 失敗なし（Phase 1 ではテストファイルが少なくても OK）
3. `vendor/bin/pint --test` — 違反 0（自動修正可能なものは `vendor/bin/pint`）
4. Git status — 意図しない変更がないか

## フェーズ別チェック

### Phase 1 完了時

- [ ] `composer.json` に `docs/stack.md` の「手動追加 ✅」パッケージがすべて記載
- [ ] Laravel Breeze（Livewire スタック）/ laravel-lang / larastan / Dusk の初期化済み
- [ ] `php artisan migrate` 成功済み（`bookkeeper` データベースに対して）
- [ ] `bookkeeper_test` データベースが作成済み
- [ ] `bin/dev` で 200 が返る
- [ ] `my-app/.env` が存在し、`.gitignore` で除外されている
- [ ] `my-app/.env.example` が存在し、コミット対象に含まれている
- [ ] `bin/dev` に Queue ワーカー（`php artisan queue:work` / `queue:listen`）の行が含まれていない

### Phase 2 完了時

- [ ] `database/migrations/` の各テーブル定義が `docs/db-schema.md` と一致
- [ ] 各モデルに Enum キャスト / リレーションが定義済み
- [ ] CHECK 制約が存在（books の available_copies）
- [ ] `php artisan test tests/Unit/Models` all green

### Phase 3 完了時

- [ ] `php artisan route:list` の出力が `docs/api-spec.md` の全エンドポイントを含む
- [ ] 各リソースに Policy が存在
- [ ] レイアウト `layouts/app.blade.php` と `layouts/admin.blade.php` が存在
- [ ] `docs/architecture.md` の「Action 一覧」の 4 クラスが `app/Actions/` に存在
- [ ] 主要画面が（空でも）500 にならない

### Phase 4 完了時

- [ ] `coverage/index.html` が生成され、行カバレッジが 80% 以上
- [ ] `migrate:fresh` 後に `db:seed` が成功
- [ ] Seeder 投入後にログインして主要画面が見える
- [ ] `php artisan dusk` all green
- [ ] `vendor/bin/phpstan analyse` エラー 0
- [ ] README.md に「起動方法」「テストアカウント」が記載されている

## 報告フォーマット

チェック結果を以下の形式で報告:

```
✅ クリア: <項目>
❌ 未達: <項目> — 原因: <推測>、対処案: <提案>
⚠️  確認要: <項目> — ユーザー判断が必要な理由
```

未達がある場合、次のフェーズに進まずに対処する。
