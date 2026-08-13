# Project: 蔵書管理システム (BookKeeper)

社内向けの書籍蔵書管理 + 貸出記録システム。
一般ユーザーは書籍検索と借用申請、管理者は蔵書・貸出・ユーザーを管理する。

## 仕様ドキュメント

@docs/stack.md  
@docs/db-schema.md  
@docs/screens.md  
@docs/api-spec.md  

**次のものは意図的に `@` 参照していない。** 読む場面が限られる一方、`@` を付けると
全セッションの文脈に常時載り、以降のすべての API 呼び出しで再送されるため。
**下表の場面に当たったら、その時点で Read すること。**

| ファイル | 読むべき場面 |
|---|---|
| `docs/architecture.md` | **Controller / Action / Policy / Livewire を追加・変更するとき**（レイヤの責務・トランザクション境界・認可エラーの挙動が一次情報） |
| `docs/seeds.md` | Seeder の実装と、投入済みサンプルデータの件数・値を前提にする作業 |
| `docs/boost-guidelines.md` | Laravel エコシステムの一般規約を確かめたいとき。**上記 `docs/*.md` と `team-rules/` が優先し、Boost のガイドラインはそれらが触れていない領域を補完する位置づけ**（Laravel Boost が Phase 1 で生成するため、それ以前は存在しない） |
| `docs/decisions.md` | 技術選定の理由を確かめるとき、採用しなかった選択肢へ変更を検討するとき |

## このプロジェクトでの作業方針

- **仕様優先**: docs/ の記述と実装が食い違ったら docs/ が正。違和感があれば実装前に質問する。
- **動く状態を維持**: 各フェーズの終わりに必ず `php artisan test` と `composer run dev` で起動確認をする。
- **段階的に作る**: 後述のフェーズ順序を守る。先回りで他フェーズの作業をしない。
- **Seeder 必須**: ローカルですぐ触れるよう、各モデルに最低 3 件のサンプルデータを Seeder に入れる。

## 開発フェーズ（順序厳守）

このプロジェクトは 5 フェーズで構築する。各フェーズは `.claude/commands/` のスラッシュコマンドで実行する。

1. `/scaffold-phase1-skeleton` — Laravel 雛形 + 依存・認証（Breeze）導入 + Docker DB 起動
2. `/scaffold-phase2-models` — DB スキーマ + Model + マイグレーション
3. `/scaffold-phase3-ui` — Controller + Livewire/Blade + 認可
4. `/scaffold-phase4-ui-tests` — Phase 3 の UI を Feature / Dusk テストで検証
5. `/scaffold-phase5-finalize` — Seeder + テスト + 起動確認

各フェーズ完了時、`/verify` で完了基準を満たしているかセルフチェックする。

> **フェーズの完了は「プロジェクトの実装完了」ではない。** `team-rules/review-policy.md`
> の自己レビューは「PR を出す前（あるいは『実装完了』と報告する前）」の
> チェックリストだが、**各フェーズの終わりはそこに当たらない**。フェーズごとの
> 判定は、そのフェーズの手順書（`.claude/commands/scaffold-phase*.md`）の
> 完了基準に書かれた項目だけで行う。
>
> 特に**カバレッジ 80% は Phase 5 で初めて測る**。Phase 1〜4 の時点では対象コードが
> 揃っておらず、達していなくても正常である。前倒しで測ってもよいが、
> **未達を理由にフェーズを `aborted` にしないこと**（過去のトライアルで、当該フェーズの
> 完了基準に無いカバレッジ計測が行われた）。

## 完了の定義（プロジェクト全体）

- [ ] `composer install && npm install` + `php artisan migrate --seed` 一発でセットアップが完了し、各画面に表示すべきサンプルデータが入る
- [ ] `composer run dev` で起動し、ログインから主要画面遷移まで動作
- [ ] `php artisan test` が all green
- [ ] Laravel Dusk のシステムテストが all green
- [ ] カバレッジ 80% 以上（`vendor/bin/pest --coverage --min=80` の**終了コード**で判定。`laravel/pao` の JSON の `result` は未達でも `passed` を返すため使わない）
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse` でエラーなし（larastan/larastan による静的解析）
- [ ] README に「起動方法」「テストアカウント」が記載されている

## 重要な制約

- **API モードにしない**。フルスタック Laravel（Blade + Livewire）。
- **JS フレームワーク（React/Vue）を導入しない**。Livewire + Alpine.js で完結させる。
- **Laravel Breeze（Livewire スタック）を使う**。自前認証を書かない。
- **Laravel Policy（標準機能）を使う**。CanCanCan 相当のサードパーティ認可ライブラリや自前認可ロジックは導入しない。
- **非同期ジョブを使わない**。Queue の生成物は残すがワーカーは起動しない。
  詳細は `docs/stack.md` の「ジョブ・キャッシュ・ブロードキャスト」セクション参照。
