# セキュリティ

## 秘密情報

- 秘密情報は `.env` で管理する。
- `.env` は `.gitignore` に含め、`.env.example` をリポジトリに含める。
- `APP_KEY` は絶対にコミットしない（`.env` のみに存在させる）。
- 秘密情報をログ・コンソール出力に含めない。

## 入力と出力

- ユーザー入力はすべて Form Request（`app/Http/Requests/`）でバリデーション・ホワイトリスト化する。
- SQL は Eloquent / Query Builder 経由で書く。生の SQL を書く場合はプレースホルダを使う（文字列結合禁止）。
- Blade 出力は `{{ }}` のエスケープに任せる。`{!! !!}` を使う場合は理由をコメントする。
- ファイルアップロードは MIME / 拡張子 / サイズを必ず検証する（Form Request のバリデーションルールで行う）。

## 認証・認可

- パスワードは Laravel Breeze 標準の bcrypt に任せる。自前で書かない。
- セッション固定化対策（ログイン時のセッション再生成）は Laravel の認証スキャフォールドが処理する。
- 管理画面の全アクションは Laravel Policy（`app/Policies/`）で認可チェックする。Controller で `$this->authorize()` を徹底する。
- Mass assignment 防止のため、Model の `$fillable` を明示し `$guarded = []` にしない。`id` や `role` 等の権限に関わるカラムを `$fillable` に含めない。

## その他

- `composer.lock` をコミットする。
- `composer audit`（依存パッケージの脆弱性チェック）/ `vendor/bin/phpstan analyse`（larastan/larastan による静的解析）を CI に組み込む。
- Enlightn が提供していた Laravel 特化のセキュリティ・パフォーマンス項目（本番での `APP_DEBUG` 有効化、Mass Assignment の設定漏れ等）は自動チェックツールが存在しないため、本ファイルのチェックリストに沿った手動レビューでカバーする。
- 本番ログに個人情報を出さない（`config/logging.php` のチャンネル設定で機密情報をマスクする）。
