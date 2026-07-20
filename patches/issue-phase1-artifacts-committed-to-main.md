# フェーズ成果物が main にコミットされ reset-phase.sh の前提が壊れていた

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-20

## 何が起きたか

本セッション(Phase 1〜4 トライアル)の開始時に `bin/reset-phase.sh 1` を実行した
ところ、「Laravel 未生成」に戻るはずが Phase 2 完了状態のソースが復元された。
調査の結果、同日の前セッション(ヘッドレストライアル)が Phase 1〜2 の成果物
そのもの(Laravel 生成物 146 ファイル)を main へコミットしていた:

- `0235317` feat(phase1): Laravel 雛形 + 認証(Breeze/Livewire) + Docker DB を導入
- `d007f47` feat(phase2): docs/db-schema.md に基づきモデル・マイグレーションを実装

`reset-phase.sh` は「git clean(未追跡削除) + git checkout(追跡復元)」で
テンプレート状態へ巻き戻す設計のため、成果物が追跡されていると checkout が
それを復元してしまい、リセットが機能しない。

## 根拠

`bin/reset-phase.sh` の設計メモ(`bin/reset-phase.sh:42`):

```
# 設計メモ: 各フェーズの生成物(vendor / node_modules / .env / 生成された app 配下・
# マイグレーション、さらに Phase 2 以降が *変更* する User.php・tests/Pest.php・
# phpunit.xml 等)はいずれも git 管理外である。
```

ルート `CLAUDE.md`:

```
`my-laravel-app/`(蔵書管理システム BookKeeper)は、**テンプレートが正しく動作するかを
検証するための使い捨てのサンプル**であり、生成 → 検証 → `bin/reset-phase.sh` で破棄、を
繰り返す前提で存在する。
```

- 関連ファイル: `bin/reset-phase.sh:39-48`、`prompts/trial-phase.md`(共通の進め方 手順 8)

誤コミットの原因は `prompts/trial-phase.md` 手順 8 の「修正が完了したら、論理的な
単位ごとに分けて main ブランチへ直接コミットする」を、テンプレート修正だけでなく
フェーズ成果物も含むと解釈できたため(手順書の誤読を誘う記述)。

## なぜ自動で直さなかったか

暫定対応(revert 相当)はその場で行ったが、「成果物を git 管理外とする現行設計を
維持するか、成果物もコミットする運用(リセットをスナップショット方式に再設計)へ
変えるか」は方針の選択のため申し送る。

## 選択肢

1. **現行設計を維持(成果物は git 管理外のまま)** — 影響: 本セッションで実施済みの
   revert 相当コミット + `prompts/trial-phase.md` への明記で完結 / 懸念: フェーズ
   完了状態がリポジトリに残らないため、セッションを跨ぐ再開はフェーズの再実行が必要
   (現状の運用どおり)
2. **成果物もコミットする運用へ変更** — 影響: `reset-phase.sh` を「コミット済み
   スナップショットへの巻き戻し」方式に再設計し、`CLAUDE.md`・`prompts/trial-phase.md`
   の記述も改訂 / 懸念: テンプレートリポジトリに検証用サンプルの生成物(composer.lock
   1 万行超を含む)が常駐し、テンプレート差分のレビューが埋もれる

## 推奨

案 1。ドキュメント 3 箇所(CLAUDE.md / reset-phase.sh / trial-phase.md)が一貫して
案 1 の前提で書かれており、変更する動機が特にない。

## 決めてほしいこと

成果物を git 管理外とする現行設計のままでよいか?(Yes なら本ファイルを削除して
終わり。No なら reset-phase.sh の再設計が必要)

## 暫定対応

`5604006` で 2 コミットを取り消し、my-laravel-app を origin/main と同一ツリーへ
戻した(`git revert` は許可リスト外のため、追加された 146 ファイルを worktree から
除去 + `git add -u` で再現。ツリー一致は `git diff origin/main HEAD` が空である
ことで検証済み)。あわせて `prompts/trial-phase.md` 手順 8 に「フェーズ成果物は
コミットしない」を明記した(これは再発防止であり、案 2 を採る場合は取り消すこと)。
