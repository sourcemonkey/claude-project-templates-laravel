# enum（貸出 state / 通知 kind / ロール）の画面表示ラベルが docs で決まっていない

- フェーズ: Phase 3
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

Phase 3 で貸出一覧・貸出詳細・ユーザー詳細を実装する際、`LendingState` /
`NotificationKind` / `UserRole` を画面に日本語で表示する必要があったが、
**表示ラベルの定義が docs のどこにもない**。

`docs/screens.md` は「ボタン・ラベルの標準（テスト記述時の参照用）」という表を持ち、
`保存` / `削除` / `変更する` / `既読` などを**実装ブレ防止のため固定**している。
にもかかわらず、一覧・詳細画面に必ず出る enum の表示名は表に含まれていない。

## 根拠

`docs/db-schema.md` は enum の**値**だけを定義している:

```
| state | tinyInteger | NOT NULL, default: 0（enum: `Requested: 0`, `Approved: 1`, `Returned: 2`, `Rejected: 3`, `Overdue: 4`） |
```

`docs/screens.md` のラベル表（該当箇所）:

```
| 場面 | ラベル |
|---|---|
| 作成・編集フォームの submit（全リソース共通） | `保存` |
| 削除ボタン | `削除` |
| ユーザーのロール変更 submit | `変更する` |
| ユーザーのロール変更 select の label | `ロール変更` |
| 通知の既読化ボタン | `既読` |
| カテゴリフォームの name フィールド label | `カテゴリ名` |
| タグフォームの name フィールド label | `タグ名` |
```

state の表示名はこの表にない。`docs/seeds.md` の貸出表には「申請中 / 借用中 / 延滞中 /
完了 / 却下サンプル」という**補足欄の日本語**があるが、これは Seeder の説明であって
UI ラベルの定義ではなく、「完了」と「返却済み」のどちらが正かも読み取れない。

- 関連ファイル: `my-laravel-app/docs/screens.md`（ボタン・ラベルの標準）
- 関連ファイル: `my-laravel-app/docs/db-schema.md`（lendings / notifications / users の enum 定義）

## なぜ自動で直さなかったか

`docs/screens.md` の**仕様そのものを追加する**話であり、文言の選択に複数の妥当解がある
（「返却済み」/「完了」、「借用中」/「貸出中」など）。「共通の進め方」手順 4 の
「妥当な解が複数あり、どれを採るかが方針の選択になる」に当たる。

## 選択肢

1. **`docs/screens.md` のラベル表に enum の表示名を追記する** — 影響: Dusk / Feature
   テストが `assertSee('申請中')` のように文言を直接書けるようになり、実装とテストの
   ブレが消える / 懸念: 表が長くなる（3 enum で 10 行）
2. **`docs/db-schema.md` の enum 定義側に表示名を併記する** — 影響: 値と表示名が
   1 箇所にまとまる / 懸念: `docs/screens.md` の「ラベルは screens.md が一次情報」という
   現在の構成と食い違い、実装者がどちらを見ればよいか迷う
3. **決めない（実装者に委ねる）** — 影響: 追加作業なし / 懸念: フェーズを回すたびに
   別の文言が生成され、`docs/screens.md` が「実装ブレ防止のため」ラベルを固定している
   方針と矛盾する

## 推奨

案 1。`docs/screens.md` が既にラベルの一次情報だと宣言しており、そこに寄せるのが
構成上いちばん自然。今回の実装で使った文言をそのまま採用すれば追加の判断も要らない。

## 決めてほしいこと

`docs/screens.md` のラベル表に、下記の enum 表示名を追記してよいか。

| enum | 値 | 表示名 |
|---|---|---|
| `LendingState` | Requested / Approved / Returned / Rejected / Overdue | 申請中 / 借用中 / 返却済み / 却下 / 延滞中 |
| `NotificationKind` | LendingApproved / LendingRejected / ReturnReminder | 承認通知 / 却下通知 / 返却リマインド |
| `UserRole` | Member / Admin | メンバー / 管理者 |

## 暫定対応

トライアルを進めるため、上表の文言を各 Enum クラスの `label(): string` メソッドとして
実装した（`my-laravel-app/app/Enums/{LendingState,NotificationKind,UserRole}.php`）。
ビューからは `{{ $lending->state->label() }}` で参照している。

**テンプレート（手順書・docs）には差分を入れていない**ため、案 3 を選ぶ場合に
取り消すべきものはない。案 1 を採る場合は `docs/screens.md` に上表を追記し、
あわせて Phase 3 手順書へ「enum の表示は `label()` メソッドに置く」旨を書くと、
次回以降のフェーズで同じ実装に収束する。
