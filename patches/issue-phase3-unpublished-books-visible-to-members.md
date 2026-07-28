# メンバー向け蔵書一覧が `published = false` の書籍を隠すのかが仕様に無い

- フェーズ: Phase 3
- 状態: 未解決
- 初回観測: 2026-07-28

## 何が起きたか

Phase 3 で `GET /books`（メンバー向け蔵書一覧）を実装する際、`books.published` が
false の書籍を一覧・詳細から除外すべきかどうかが `docs/` から決まらなかった。

`docs/db-schema.md` は `published` カラム（boolean, default false）を定義し、
`docs/seeds.md` は「未公開書籍サンプル」を `published = false` で 1 件投入すると
定めている。一方 `docs/screens.md` のメンバー領域の記述にも `docs/api-spec.md` の
認可マトリクスにも、`published` による絞り込みの指定が無い。

現状は**仕様どおり全件表示**で実装してある（スコープを掛けていない）。このため
Phase 4 で Seeder を投入すると、メンバーの蔵書一覧に「未公開書籍サンプル」が並び、
借用申請もできる状態になる。

## 根拠

`my-laravel-app/docs/screens.md` のメンバー領域:

```
| `GET /books` | 蔵書一覧 | 検索 / ページネーション / タグ・カテゴリで絞り込み（Livewire コンポーネント） |
| `GET /books/{book}` | 蔵書詳細 | 在庫数表示、借用申請ボタン |
```

`my-laravel-app/docs/db-schema.md` の Spatie Query Builder 対応表:

```
| Book | title, author, publisher, isbn, description, published, `AllowedFilter::exact('category_id')`, `AllowedFilter::exact('tags.id')` | created_at, title |
```

`published` は「利用者が指定できるフィルタ」として並んでおり、**強制スコープとしては
書かれていない**。この表はメンバー画面と管理画面のどちらを指すのかも書き分けが無い。

`my-laravel-app/docs/seeds.md` の書籍表（最終行）:

```
| (なし) | 未公開書籍サンプル | （著者B） | 技術書 | JavaScript | 1 | false |
```

`my-laravel-app/docs/api-spec.md` の認可マトリクス:

```
| 蔵書 read | ✓ | ✓ |
```

member / admin ともに `✓` で、`published` による差は表現されていない。

- 関連ファイル: `my-laravel-app/docs/screens.md:13`,
  `my-laravel-app/docs/db-schema.md`（Spatie Query Builder 対応表の Book 行）,
  `my-laravel-app/docs/seeds.md`（書籍 8 件の表の最終行）
- 実装箇所: `my-laravel-app/app/Livewire/BookSearch.php`（`render()` のクエリ）,
  `my-laravel-app/app/Http/Controllers/BookController.php`（`show()`）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「妥当な解が複数あり、どれを採るかが方針の選択になる」に当たる。
`published` の意味づけ（下書き / 蔵書登録前 / 非公開資料）が決まっていないため、
隠す・隠さないのどちらも仕様と矛盾しない。

## 選択肢

1. **メンバー画面のみ `published = true` に強制スコープする** — 影響: `BookSearch` の
   クエリと `BookController::show()` に `where('published', true)`（詳細は 404）を足す。
   管理画面は従来どおり全件。`docs/screens.md` に 1 行追記する /
   懸念: `published` を allowedFilters に残す意味がメンバー画面では無くなる（管理画面
   専用のフィルタになる）。Phase 4 の Seeder が投入する 8 件のうち 1 件がメンバーからは
   見えなくなるため、シードデータの見え方の説明も要る
2. **現状維持（全件表示）で、`published` は表示ラベル用のフラグと位置づける** — 影響:
   実装変更なし。`docs/db-schema.md` に「`published` は表示上の区別のみで、閲覧制御には
   使わない」と明記する / 懸念: 蔵書管理システムで `published = false` の書籍が誰でも
   借用申請できるのは直感に反する。利用者が本テンプレートを本番へ持ち込んだとき、
   同じ判断を繰り返すことになる
3. **`published` カラム自体を仕様から落とす** — 影響: `docs/db-schema.md` /
   `docs/seeds.md` / マイグレーション / ファクトリ / 管理画面フォームから削除 /
   懸念: 変更範囲が Phase 2〜4 に跨り、既に通っているフェーズを作り直す必要がある

## 推奨

案 1。`published` という命名が「公開されていない＝一般利用者には見えない」を意味するのが
自然であり、Seeder がわざわざ非公開サンプルを 1 件用意しているのも「メンバー画面での
見え方の違い」を確認させる意図と読むのが素直なため。

## 決めてほしいこと

メンバー向けの蔵書一覧・詳細は `published = false` の書籍を隠す（案 1）で確定してよいか。

## 暫定対応

なし。仕様に明記が無いため、スコープを掛けずに全件表示のまま実装してある
（`BookSearch::render()` / `BookController::show()` にフィルタ条件を入れていない）。
案 1 を採る場合はこの 2 箇所に条件を足すことになる。
