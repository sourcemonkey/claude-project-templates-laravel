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

## このプロジェクトでの作業方針

- **仕様優先**: docs/ の記述と実装が食い違ったら docs/ が正。違和感があれば実装前に質問する。
- **動く状態を維持**: 各フェーズの終わりに必ず `php artisan test` と `php artisan serve` / `npm run dev` で起動確認をする。
- **段階的に作る**: 後述のフェーズ順序を守る。先回りで他フェーズの作業をしない。
- **Seeder 必須**: ローカルですぐ触れるよう、各モデルに最低 3 件のサンプルデータを Seeder に入れる。

## 開発フェーズ（順序厳守）

このプロジェクトは 4 フェーズで構築する。各フェーズは `.claude/commands/` のスラッシュコマンドで実行する。

1. `/scaffold-phase1-skeleton` — Laravel 雛形 + 依存導入 + Docker DB 起動
2. `/scaffold-phase2-models` — DB スキーマ + Model + マイグレーション
3. `/scaffold-phase3-ui` — 認証 + Controller + Livewire/Blade + 認可
4. `/scaffold-phase4-finalize` — Seeder + テスト + 起動確認

各フェーズ完了時、`/verify` で完了基準を満たしているかセルフチェックする。

## 完了の定義（プロジェクト全体）

- [ ] `composer install && npm install` + `php artisan migrate --seed` 一発でセットアップ完了
- [ ] `php artisan serve` + `npm run dev` で起動し、ログインから主要画面遷移まで動作
- [ ] `db:seed` 相当（`php artisan migrate --seed` / `php artisan db:seed`）で各画面に表示すべきサンプルデータが入る
- [ ] `php artisan test` が all green
- [ ] Laravel Dusk のシステムテストが all green
- [ ] カバレッジ 80% 以上（`coverage/index.html` で確認）
- [ ] `vendor/bin/pint --test` が違反 0
- [ ] `vendor/bin/phpstan analyse` でエラーなし（larastan/larastan による静的解析）
- [ ] README に「起動方法」「テストアカウント」が記載されている

## 重要な制約

- **API モードにしない**。フルスタック Laravel（Blade + Livewire）。
- **JS フレームワーク（React/Vue）を導入しない**。Livewire + Alpine.js で完結させる。
- **Laravel Breeze（Blade スタック）を使う**。自前認証を書かない。
- **Laravel Policy（標準機能）を使う**。CanCanCan 相当のサードパーティ認可ライブラリや自前認可ロジックは導入しない。
- **非同期ジョブを使わない**。Laravel 標準の Queue（database ドライバ）は
  `laravel new` の生成物として設定を残すが、ワーカー（`php artisan queue:work`）は起動しない。
  Redis / Horizon などの追加導入もしない。詳細は `docs/stack.md` の
  「ジョブ・キャッシュ・ブロードキャスト」セクション参照。
