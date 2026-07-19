# Enum の `label()` をどのフェーズで実装するか、Phase 2 手順書だけでは判断できない

- フェーズ: Phase 2
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

Phase 2 の「残りのモデル」節に従って `app/Enums/` の 3 つの Enum
（`UserRole` / `LendingState` / `NotificationKind`）を作成する際、
`docs/screens.md` が「**各 Enum クラスの `label(): string` メソッドとして実装し**」と
明示的に要求しているため、Phase 2 の時点で `label()` を実装すべきかどうかで迷った。

Phase 2 手順書の Enum 定義例には `label()` が含まれていない。一方 Phase 2 の
「やらないこと」に挙がっているのは Controller / View / Action / Seeder であって
Enum のメソッドではない。`docs/screens.md` は `my-laravel-app/CLAUDE.md` から
`@docs/screens.md` として常時読み込まれるため、Phase 2 の作業中も視界に入る。

いったん `label()` 付きで `UserRole` を書いたあと、Phase 3 手順書を確認して
そちらに指示があることが分かり、書き直した。手戻りは 1 ファイル分で済んだが、
Phase 2 手順書だけを読んで進めた場合は気づかず混入する。

## 根拠

`docs/screens.md`（原文）:

```
### enum の表示ラベル

一覧・詳細画面に表示する enum の日本語表記。**各 Enum クラスの `label(): string` メソッドとして実装し、ビューからは `{{ $lending->state->label() }}` で参照する**（Blade 側に `@if` の連鎖や配列マッピングを書かない）。
```

`.claude/commands/scaffold-phase3-ui.md:127`（原文）:

```
- **enum の画面表示**: `LendingState` / `NotificationKind` / `UserRole` の日本語表記は `docs/screens.md` の「enum の表示ラベル」表が一次情報。**各 Enum クラスに `label(): string` を実装し**、ビューからは `{{ $lending->state->label() }}` で参照する
```

`.claude/commands/scaffold-phase2-models.md:93`（原文）:

```
Enum クラスは `app/Enums/` に置く。値は `docs/db-schema.md` の各テーブル定義に明示されているものを使い、**推測で採番しない**（`UserRole` / `LendingState` / `NotificationKind` の 3 つ）。
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase2-models.md:93`
- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md:127`

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「**手順書は正しいが誤読した箇所**」に当たる。どちらの
手順書にも誤りはなく、記述の重複を避けるか明示するかは書き方の方針判断。
加えて修正先が `.claude/commands/` 配下のため、ヘッドレスからは直接書き込めない。

## 選択肢

1. **Phase 2 手順書の Enum の節に「`label()` は Phase 3 で実装する」と 1 行足す** —
   影響: Phase 2 だけを読む利用者が迷わない / 懸念: フェーズ境界の注記が増える
2. **Phase 2 の「やらないこと」に「Enum の `label()`（Phase 3 で実施）」を追加する** —
   影響: 既存の「やらないこと」の並びに収まり、書式の統一が保たれる / 懸念: 1 と
   実質同じで、リストが細かくなる
3. **`label()` を Phase 2 で実装する側に寄せる** — 影響: Enum クラスの定義が
   1 フェーズで完結し、`docs/screens.md` の記述とも素直に一致する / 懸念: Phase 3
   手順書側の記述の修正が必要になり、表示ラベルという View 関心が Phase 2 に入る

## 推奨

案 2。既存の「やらないこと」節がまさにこの種のフェーズ境界を示すために置かれて
おり、新しい書式を持ち込まずに済む。

## 決めてほしいこと

Phase 2 手順書の「やらないこと」に「Enum の `label()` メソッド（Phase 3 で実施）」を
追加してよいか。それとも案 3 のように Phase 2 側へ実装を寄せるか。

## 暫定対応

Phase 3 手順書の記述に従い、本トライアルでは Phase 2 で `label()` を**実装しなかった**。
テンプレート本体への変更はしていない。
