# カバレッジドライバ（PCOV / Xdebug）がホストに無く、Phase 1 の事前確認でも検出されない

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-19

## 何が起きたか

Phase 1 は全完了基準をクリアして完走した。しかし Phase 1 手順書の Step 1「事前確認」は
PHP / Node / Laravel Installer / Docker / ポート 3306 しか確認しておらず、**カバレッジ
計測ドライバの有無を確認していない**。

このホストには PCOV も Xdebug も入っていないため、`docs/stack.md` の
「テストカバレッジ設定（正規形）」および `my-laravel-app/CLAUDE.md` の
「完了の定義」が要求するカバレッジ 80% の計測が実行できない。Phase 1〜3 は
カバレッジを取らないため成功し続け、**Phase 4 の仕上げまで問題が顕在化しない**。

## 根拠

```
$ php -m | grep -i -E 'pcov|xdebug'
（出力なし）

$ php artisan test --coverage
 ERROR Code coverage driver not available. Did you install Xdebug or PCOV?
```

`docs/stack.md` は PCOV を前提として明記している:

> | `pcov/clobber` または php.ini の `pcov` 拡張 | テストカバレッジ計測ドライバ | ✅（拡張として） | ローカル環境 |

> PCOV 拡張がローカル環境にインストールされている前提。`php -m | grep pcov` で確認できる。

一方、Phase 1 手順書 Step 1 の事前確認項目には PCOV の確認が無い。

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:26-39`（Step 1 事前確認）
- 関連ファイル: `my-laravel-app/docs/stack.md`（テストカバレッジ設定（正規形））
- 関連ファイル: `my-laravel-app/CLAUDE.md`（完了の定義 / カバレッジ 80% 以上）

## なぜ自動で直さなかったか

「テンプレートのスコープを超える（ホスト環境）」に当たる。PCOV はホストの PHP 全体に
影響する拡張であり、`pecl install pcov` + php.ini 編集をヘッドレスの単独判断で実行すべき
でない（Step 1 の `ext-zip` の項が「ホスト全体に適用される変更のため事前にユーザーへ確認
する」としているのと同じ理由）。加えて、どこで検出するか（Phase 1 で止めるか Phase 4 まで
遅らせるか）は方針の選択になる。

## 選択肢

1. **Phase 1 の Step 1 に PCOV の確認を追加し、無ければ導入を促して中断する** —
   影響: 環境の不備が最も早い時点で分かる / 懸念: カバレッジは Phase 4 まで使わないため、
   Phase 1〜3 を試したいだけの利用者にとっては過剰な足止めになる。
2. **Phase 1 の Step 1 では警告のみ（`php -m | grep pcov` の結果を報告し継続）、
   Phase 4 の手順書冒頭で必須チェックとする** — 影響: 早期に気づけて足止めもしない /
   懸念: 警告を読み飛ばされると結局 Phase 4 で止まる。
3. **カバレッジ 80% の要件自体を見直す** — 影響: 環境依存を減らせる /
   懸念: `team-rules/review-policy.md` のチェックリスト項目であり、ルールの中身の変更に
   当たるためヘッドレスでは判断できない。

## 推奨

案 2。Phase 1 の事前確認は「フェーズを進められるか」の判定であり、カバレッジは Phase 1 の
完了基準に含まれない。一方 Phase 4 では必須になるため、そこを必須チェック点に置くのが
実際の依存関係と一致する。

## 決めてほしいこと

カバレッジドライバの確認を「Phase 1 で警告 + Phase 4 で必須」（案 2）としてよいか。
それとも Phase 1 で必須チェックとして中断させるか（案 1）。

## 暫定対応

なし。Phase 1 の完了基準にカバレッジは含まれないため、トライアルはそのまま完走している。
テンプレート本体への回避策の投入も行っていない。
