# Phase 2 の AuditLog に created_at の datetime キャスト指示が無く、監査ログ画面が 500 になる

- フェーズ: Phase 2（Phase 3 の監査ログ画面で顕在化）
- 状態: 未解決
- 初回観測: 2026-07-23

## 何が起きたか

Phase 2 手順書の AuditLog の指示は「`$timestamps = false`」「`changes_json => 'array'`」
「`created_at` は生成直後のインスタンスに載らないので `->fresh()` を挟む」の 3 点で、
**`created_at` を datetime にキャストする指示が無い**。

`$timestamps = false` のモデルは `created_at` を自動で datetime キャストしないため、
DB から読んだ `created_at` は**文字列**になる。Phase 3 の監査ログ画面
（`docs/screens.md` の `GET /admin/audit-logs`）で日時を
`{{ $log->created_at?->format('Y-m-d H:i') }}` と表示しようとすると、
`Error: Call to a member function format() on string` で **500** になる
（`?->` は文字列に対しては効かない）。

## 根拠

```
Error: Call to a member function format() on string in
.../storage/framework/views/....php:26
```

Feature テスト `ScreenSmokeTest`（管理画面が 200 を返す）で最初に検出。
`AuditLog` モデルに次を足すと解消した:

```php
protected function casts(): array
{
    return [
        'changes_json' => 'array',
        'created_at' => 'datetime', // ← 追加
    ];
}
```

あわせて larastan 用に `@property \Illuminate\Support\Carbon|null $created_at` も付けた
（enum / 日時キャストに `@property` を要求する Phase 2 手順書の方針と揃える）。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase2-models.md`（audit_logs の
  `$timestamps` を説明している注記）

## なぜ自動で直さなかったか

修正先が `.claude/commands/scaffold-phase2-models.md`（ヘッドレスでは書き込めない）である
ため。修正自体は一意（datetime キャストと `@property` を足すだけ）。

## 選択肢

1. **Phase 2 手順書の audit_logs 注記に「表示のため `created_at` を datetime にキャストし、
   `@property Carbon $created_at` を付ける」を追記する**。影響: 監査ログ画面が素直に書ける /
   懸念: なし。
2. Phase 3 手順書側で「監査ログ画面で created_at を format する前にキャストを確認」と補足する。
   影響: 発生箇所に近い / 懸念: 原因（モデル定義）から遠い。

## 推奨

案 1。原因はモデル定義なので Phase 2 手順書で塞ぐのが素直。

## 決めてほしいこと

案 1 で Phase 2 手順書に `created_at` の datetime キャスト（+ `@property`）を追記してよいか。

## 暫定対応

`my-laravel-app/app/Models/AuditLog.php`（生成物）に上記キャストと `@property` を入れて
監査ログ画面を 200 にした。手順書へ反映すればリセットで消えるため恒久対応は手順書側。
