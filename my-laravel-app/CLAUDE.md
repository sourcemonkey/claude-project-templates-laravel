# Project: 蔵書管理システム (BookKeeper)

社内向けの書籍蔵書管理 + 貸出記録システム。
一般ユーザーは書籍検索と借用申請、管理者は蔵書・貸出・ユーザーを管理する。

## 仕様ドキュメント

@docs/stack.md  
@docs/architecture.md  
@docs/db-schema.md  
@docs/screens.md  
@docs/api-spec.md  
@docs/seeds.md  

Laravel エコシステムの一般的な規約は Laravel Boost が生成する次のファイルにある（Phase 1 で
生成されるため、それ以前は存在しない）。**上記 `docs/*.md` と `team-rules/` が優先し、Boost の
ガイドラインはそれらが触れていない領域を補完する位置づけ**とする。

@docs/boost-guidelines.md  

## このプロジェクトでの作業方針

- **仕様優先**: docs/ の記述と実装が食い違ったら docs/ が正。違和感があれば実装前に質問する。
- **動く状態を維持**: 各フェーズの終わりに必ず `php artisan test` と `composer run dev` で起動確認をする。
- **段階的に作る**: 後述のフェーズ順序を守る。先回りで他フェーズの作業をしない。
- **Seeder 必須**: ローカルですぐ触れるよう、各モデルに最低 3 件のサンプルデータを Seeder に入れる。

## 開発フェーズ（順序厳守）

このプロジェクトは 4 フェーズで構築する。各フェーズは `.claude/commands/` のスラッシュコマンドで実行する。

1. `/scaffold-phase1-skeleton` — Laravel 雛形 + 依存・認証（Breeze）導入 + Docker DB 起動
2. `/scaffold-phase2-models` — DB スキーマ + Model + マイグレーション
3. `/scaffold-phase3-ui` — Controller + Livewire/Blade + 認可
4. `/scaffold-phase4-finalize` — Seeder + テスト + 起動確認

各フェーズ完了時、`/verify` で完了基準を満たしているかセルフチェックする。

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
