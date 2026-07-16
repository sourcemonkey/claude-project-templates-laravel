# コーディング規約

## 共通

- インデントは半角スペース 4 つ。タブ禁止。
- ファイル末尾に改行を入れる。
- 行末の余分な空白を残さない。
- マジックナンバーは定数化する。
- コメントは「なぜ」を書く。「何を」しているかはコード自身に語らせる。

## PHP / Laravel

- Lint は Laravel Pint（標準の `laravel` プリセット）に従う。
- メソッド名・変数名は `camelCase`、クラス名は `PascalCase`、DB カラム名は `snake_case`。
- 真偽値を返すメソッドは `is`, `has`, `can` 等の接頭辞を付ける（例: `isPublished()`）。
- 早期 return を使ってネストを浅く保つ。
- N+1 を避ける。一覧画面では `with()` / `load()` による Eager Loading を必ず検討する。
- Fat Controller を避け、ビジネスロジックは Model か Action / Service クラスに置く。
- Blade テンプレートに複雑な `@if` の連鎖を書かない。View Composer か Blade コンポーネントで吸収する。
- `first()` / `firstWhere()` で null を返す可能性のあるものは null チェックを必ず行う。null 前提の取得には `firstOrFail()` / `findOrFail()` を使う。
- マイグレーションは可逆にする（`up()` で行った変更は必ず `down()` で戻せるようにする）。
- 型宣言（引数・戻り値の型ヒント）を省略しない。`declare(strict_types=1)` はプロジェクト方針としては必須としない（Laravel の規約に合わせる）。

## Livewire / Alpine.js

- Livewire コンポーネントは 1 ファイル 1 責務。複数の画面機能を 1 コンポーネントに詰め込まない。
- サーバー往復を伴う動的処理（検索、インライン編集、フォームのリアルタイムバリデーション）は Livewire。
- クライアント側だけで完結する見た目の切り替え（ドロップダウン、モーダル、タブ）は Alpine.js。
- Livewire コンポーネントの public プロパティに機密情報を持たせない（クライアントにシリアライズされるため）。

## CSS / フロント

- Tailwind のユーティリティを基本とし、独自 CSS は最小限。
- 共通化が必要になったら Blade コンポーネント（`resources/views/components/`）に切り出す。

## 命名

- リソース名（テーブル名）は複数形の `snake_case`（`products`, `users`）。
- boolean カラムは `is_` を付けず、形容詞・過去分詞で（`published`, `archived`）。
- 日時カラムは `_at` 接尾辞、日付は `_on` 接尾辞（Laravel の慣例である `_date` ではなくチーム規約として `_on` に統一する）。
