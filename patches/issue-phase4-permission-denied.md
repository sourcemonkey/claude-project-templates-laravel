# Phase 4 で権限拒否されたコマンドと、カバレッジ数値が pao で見えない件

- フェーズ: Phase 4
- 状態: 未解決
- 初回観測: 2026-07-23

## 何が起きたか

Phase 4 のカバレッジ確認（完了基準「カバレッジ 80% 以上」）で、カバレッジの**数値**を
得ようとして `vendor/bin/pest` を直接叩いたところ、ルートの `.claude/settings.json` の
許可リストに無く承認待ち（ヘッドレスでは実行不可）になった。

さらに、許可済みの `php artisan test --coverage-html coverage --min=80` は
**laravel/pao の JSON 出力が総行カバレッジの数値と `--min` の失敗を握りつぶす**ため、
`{"tool":"pest","result":"passed",...}` としか返らず、**80% を実際に満たしているかを
コマンド出力から判定できない**（本トライアルでは一時 78.87% だったが `result: passed`
になっていた ＝ `--min=80` が効いていない）。やむなく `coverage/index.html` を grep して
行カバレッジ（最終 97.39%）を確認した。

## 根拠

権限拒否されたコマンド（**原文のまま**）:

```
vendor/bin/pest --coverage --min=80
```

`php artisan test --coverage-html coverage --min=80` の出力（数値・min 失敗が出ない）:

```
{"tool":"pest","result":"passed","tests":92,"passed":92,"assertions":239,"duration_ms":4374}
```

## なぜ自動で直さなかったか

許可リスト（ルート `.claude/settings.json`）はヘッドレスから書き込めず、かつ
「`vendor/bin/pest` を許可リストに足すか」「カバレッジ判定をどのコマンドで担保するか」は
設定・手順の方針判断のため。

## 選択肢

1. **`vendor/bin/pest*` をルート許可リストに追加する**。影響: カバレッジ数値と `--min` を
   直接確認できる / 懸念: `php artisan test` と経路が二重になる。
2. **手順書のカバレッジ確認を「`coverage/index.html` を開いて行カバレッジを目視」に固定し、
   コマンド出力での自動判定に依存しない**と明記する。影響: 追加許可なしで回る / 懸念:
   自動化しづらい。
3. pao を介さないカバレッジ確認手段（例: `php artisan test --coverage`（テキスト）が pao で
   数値を出すか）を検証して手順書に採用する。

## 推奨

案 2 を基本にしつつ（`coverage/index.html` を一次情報にする）、CI で機械判定したい場合に
限り案 1 を検討。トライアルでは HTML の grep で 97.39% を確認できている。

## 決めてほしいこと

カバレッジ 80% 判定の確認手段を、手順書上どれに固定するか（`coverage/index.html` 目視 /
`vendor/bin/pest` 許可 / その他）。

## 暫定対応

`coverage/index.html` を grep して行カバレッジ（362/459 → 最終 459 行中 97.39%）を確認し、
80% 達成を判定した。テンプレート本体への変更は無し。
