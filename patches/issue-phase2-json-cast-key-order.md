# MySQL JSON カラムはキー挿入順序を保持しない場合があり、`toBe()` での配列比較が落ちる

- フェーズ: Phase 2
- 状態: 未分類
- 初回観測: 2026-08-13
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase2-models.md` の指示に従い `AuditLog` の `changes_json`（`'changes_json' => 'array'` キャスト）のモデルテストを書いた際、以下のように連想配列のキー順を保持したまま `toBe()` で厳密比較した。

```php
$log = AuditLog::factory()->create(['changes_json' => ['before' => 'a', 'after' => 'b']]);

expect($log->fresh()->changes_json)->toBe(['before' => 'a', 'after' => 'b']);
```

`->fresh()` で DB から再取得した値のキー順が `['after' => 'b', 'before' => 'a']` になり、`toBe()`（thoroughly ===）が失敗した。

## 根拠

```
{"tool":"pest","result":"failed","tests":44,"passed":43,"assertions":52,"duration_ms":1240,"failed":1,"failures":[{"test":"P\\Tests\\Unit\\Models\\AuditLogTest::__pest_evaluable_changes__json_is_cast_to_an_array","file":".../tests/Unit/Models/AuditLogTest.php","line":17,"message":"Failed asserting that two arrays are identical.\n--- Expected\n+++ Actual\n@@ @@\n Array &0 [\n- 'before' => 'a',\n 'after' => 'b',\n+ 'before' => 'a',\n ]"}]}
```

`->toMatchArray([...])`（部分一致・キー順に依存しない）へ変更したところ green になった。

- 関連ファイル: `my-laravel-app/tests/Unit/Models/AuditLogTest.php:15`（このセッションで作成したテスト自身）

## なぜ自動で直さなかったか

このセッションは `--model sonnet` で実行しており、「実行モデル」節の制限により `docs/*.md` への新規の注意書き追加は「明白な誤字脱字」に該当せず、その場で編集しない方針とした。テスト自体は自分で回復済み（`toMatchArray` に変更）だが、**他の Phase 2 実行でも同じ罠を踏みうる**ため、`docs/db-schema.md` の「MySQL 固有の注意（実装時）」または `scaffold-phase2-models.md` のモデルテスト節に一般的な注意として残すかどうかは判断が要ると考えた。

## 選択肢

1. **`docs/db-schema.md` の「MySQL 固有の注意（実装時）」に一文追加する** — 影響: 他のフェーズ・他モデルの JSON キャストテストにも当てはまる一般的な注意として一箇所に集約できる。懸念: 既に長い注意書きリストがさらに伸びる
2. **`scaffold-phase2-models.md` のモデルテスト節に追記する** — 影響: Phase 2 のテスト実装時に確実に目に入る。懸念: `docs/` と手順書のどちらが一次情報かの二重管理になりうる
3. **何もしない** — 影響: なし。懸念: 次回以降の Phase 2 実行でも同じ失敗を踏み、同じ回復（`toMatchArray` への変更）を繰り返すことになる（今回は 1 回の往復で済んだため実害は小さい）

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

この罠を `docs/` または手順書に注意書きとして残すか、それとも 1 回の往復で回復可能な軽微な事象として記録のみに留め、テンプレートは変更しないか。

## 暫定対応

このセッションが書いた `my-laravel-app/tests/Unit/Models/AuditLogTest.php` 内の該当アサーションは `toMatchArray()` に変更済み（テンプレート本体への差分ではなく、コミット対象外の `my-laravel-app/` 内の変更）。
