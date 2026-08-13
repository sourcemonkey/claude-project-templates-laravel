# `vendor/bin/pest --drift` が `laravel/pao` との組み合わせで必ず失敗する

- フェーズ: Phase 1
- 状態: 未分類
- 初回観測: 2026-08-13
- 実行モデル: claude-sonnet-5

## 何が起きたか

`scaffold-phase1-skeleton.md` Step 3 の手順どおり、PHPUnit テストを Pest 記法へ変換するため

```sh
composer require pestphp/pest-plugin-drift --dev
vendor/bin/pest --drift
```

を実行したところ、ディレクトリ引数を付けても付けなくても常に失敗した。

```sh
vendor/bin/pest --drift
vendor/bin/pest --drift tests
vendor/bin/pest --drift=tests
```

いずれも同一のエラー:

```
{"tool":"pest","raw":["Pest\\Exceptions\\InvalidOption","The [--drift] argument only accepts the directory to convert as argument."]}
```

## 根拠

`vendor/pestphp/pest-plugin-drift/src/Plugin.php` の `handleArguments()` を一時的に
デバッグ出力させたところ、`--drift` 以降の引数配列に想定外の要素が入っていた:

```
DEBUG arguments: array (
  0 => '--no-output',
  1 => '--no-progress',
)
```

原因は `vendor/laravel/pao/src/Drivers/Pest/Plugin.php`:

```php
public function handleArguments(array $arguments): array
{
    if (! Execution::running()) {
        return $arguments;
    }

    if (! in_array('--no-output', $arguments, true)) {
        $arguments[] = '--no-output';
    }

    if (! in_array('--no-progress', $arguments, true)) {
        $arguments[] = '--no-progress';
    }

    return $arguments;
}
```

`laravel/pao`（AI エージェント向けの JSON 出力ラッパー。`laravel/laravel` 既定の
`require-dev` に含まれ、`docs/stack.md` にも記載済み）は `Execution::running()` が
true の間（`vendor/laravel/pao/src/Autoload.php` の `AgentDetector::detect()` が
エージェント実行と判定した場合、または `PAO_FORCE=1`）、**すべての Pest 実行で**
`--no-output` / `--no-progress` を無条件に末尾へ追記する。

`pest-plugin-drift` は `--drift` の後続引数が 0 個または 1 個であることを要求するため
（`vendor/pestphp/pest-plugin-drift/src/Plugin.php:53`）、`pao` が追記する 2 個の
フラグと衝突し、`--drift` に何を渡しても常に「引数が多すぎる」エラーになる。

`in_array` チェックがあるため、`--no-output` / `--no-progress` を**先に明示すれば**
`pao` 側は追記せず、`--drift` の後続引数は 0 個のまま処理が通ることを確認した:

```sh
vendor/bin/pest --no-output --no-progress --drift
# => {"tool":"pest","raw":["INFO The [tests] directory has been migrated to PEST with 2 files changed."]}
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md:130`（`vendor/bin/pest --drift` の記述）

## なぜ自動で直さなかったか

このセッションは `claude-sonnet-5` で実行しており、「実行モデル」節の規則により
Sonnet 系はその場修正を「明白な誤字脱字」に限定される。今回の原因特定は
3 パッケージ（`pest`, `pest-plugin-drift`, `laravel/pao`）にまたがる調査を要しており、
誤字脱字の範囲を超えるため、その場では直さず本ファイルへ申し送る。

## 選択肢

未記入（判定は対話セッションで行う）。

## 推奨

未記入（判定は対話セッションで行う）。

## 決めてほしいこと

`scaffold-phase1-skeleton.md` の該当コマンドを

```sh
vendor/bin/pest --drift
```

から

```sh
vendor/bin/pest --no-output --no-progress --drift
```

へ変更してよいか。暫定対応で確認した限りでは、これで `pao` の追記を無害化でき、
`--drift` は引数なし（既定の `tests` ディレクトリ）で正常に動作する。

なお `pestphp/pest-plugin-drift` は変換後に `composer remove` で取り除く一時的な
依存のため（`docs/stack.md` 記載どおり）、この衝突は Phase 1 の当該ステップ限りで
以後は再発しない。

## 暫定対応

`vendor/bin/pest --no-output --no-progress --drift` を実行し、変換を完了させた
（`tests/Unit/ExampleTest.php` と `tests/Feature/ExampleTest.php` の 2 ファイルが
Pest 記法へ変換されたことを確認済み）。テンプレート本体（手順書）への変更は
加えていない。
