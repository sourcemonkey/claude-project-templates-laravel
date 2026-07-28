# `php artisan test` が全件パスでも終了コード 1 を返す（laravel/pao が `--no-output` を二重付与）

- フェーズ: Phase 1
- 状態: 未解決
- 初回観測: 2026-07-29

## 何が起きたか

`.claude/commands/scaffold-phase1-skeleton.md` の Step 9-4「`php artisan test` が green で
あることを確認する」で、テストは 26 件すべてパスしているのに**プロセスの終了コードが 1**に
なる。完了基準の「`php artisan test` が green」を終了コードで判定すると未達になる。

Claude Code のようなエージェントが実行したときだけ再現する。人間がターミナルから実行した
場合は `laravel/pao` が自身を無効化するため終了コード 0 になる（後述）。

## 根拠

実行結果（`my-laravel-app/` で実行。JSON は laravel/pao の出力）:

```
$ php artisan test
Exit code 1
{"tool":"pest","result":"passed","tests":26,"passed":26,"assertions":76,"duration_ms":2262}
```

テスト自体は本当に green である。`--log-junit` で確認したルート testsuite:

```
<testsuite name=".../phpunit.xml" tests="26" assertions="76" errors="0" failures="0" skipped="0" time="2.251931">
```

終了コード 1 の原因は PHPUnit の Warning。`--log-events-text` で取得した唯一の指摘:

```
Test Runner Triggered PHPUnit Warning (Option --no-output cannot be used more than once)
```

PHPUnit は Warning があると `wasSuccessful()` が false になり `FAILURE_EXIT`(1) を返す
（`vendor/phpunit/phpunit/src/TextUI/ShellExitCodeCalculator.php:132-136`）。

`--no-output` が二重に付く経路は次の 2 つ。

1. `php artisan test` の実体である Collision の TestCommand が**無条件に先頭へ付与**する:

   ```php
   // vendor/nunomaduro/collision/src/Adapters/Laravel/Commands/TestCommand.php:215
   $options = array_merge(['--no-output'], $options);
   ```

2. `laravel/pao` の Pest プラグインが**重複チェックなしで再度付与**する:

   ```php
   // vendor/laravel/pao/src/Drivers/Pest/Plugin.php
   public function handleArguments(array $arguments): array
   {
       if (! Execution::running()) {
           return $arguments;
       }

       $arguments[] = '--no-output';
       $arguments[] = '--no-progress';

       return $arguments;
   }
   ```

   Pest 自身の同等プラグインは重複を防いでいる（pao 側にこのガードが無い）:

   ```php
   // vendor/pestphp/pest/src/Plugins/Printer.php:25-29
   if (in_array('--no-output', $arguments, true)) {
       return $arguments;
   }

   return $this->pushArgument('--no-output', $arguments);
   ```

pao はエージェント実行時のみ有効になるため、人間の実行では再現しない:

```php
// vendor/laravel/pao/src/Autoload.php:24
if (! $agent->isAgent && ! filter_var($_SERVER['PAO_FORCE'] ?? false, FILTER_VALIDATE_BOOLEAN)) {
    return;
}
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase1-skeleton.md`（Step 9-4 / 完了基準）
- 該当バージョン: `laravel/pao` v1.1.2（2026-06-22 リリース。**Packagist 上の最新版**であり、
  上げて回避することはできない）/ `nunomaduro/collision` 8.x / `pestphp/pest` v5 / PHPUnit 13.2.4
- `laravel/pao` は `laravel new` の既定生成物であり、本テンプレートが追加したものではない

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「テンプレートのスコープを超える（… Laravel 本体の挙動など、
こちらで直せないもの）」に当たる。原因は上流パッケージのバグで、回避策の選択が
テンプレートの方針判断（エージェント向け JSON 出力を捨てるかどうか）になる。

## 選択肢

1. **何もせず上流の修正を待つ** — 影響: なし / 懸念: それまでの間、エージェントが実行する
   `php artisan test` は常に終了コード 1 を返す。`/verify` や Phase 4 の完了判定を終了コードで
   行うと毎回「未達」になり、そのたびに今回と同じ切り分けを繰り返すことになる
2. **`composer.json` の `scripts.test` で pao を無効化する** — `"test": ["@putenv PAO_DISABLE=1", ...]`
   を足し、判定は `composer run test` で行う形に手順書・完了基準を寄せる。影響: 終了コードが
   正しくなる / 懸念: エージェント向けの JSON 1 行出力が失われ、`laravel/pao` を入れている意味が
   テスト実行に関しては無くなる。`php artisan test` を直接叩けば依然として 1 が返る
3. **`laravel/pao` を `composer remove --dev` する** — 影響: 終了コードが正しくなり、経路が 1 つに
   なる / 懸念: `laravel new` の既定構成から外れる。`docs/stack.md` の「開発・テスト用」表と
   Boost のガイドライン（pao の JSON 出力を前提にした記述）の更新が要る。pint / phpstan の
   JSON 出力も同時に失われる
4. **手順書に「終了コード 1 は既知。JSON の `"result":"passed"` で判定する」と明記する** —
   影響: 変更が手順書のみで済み、pao の利点を保てる / 懸念: 終了コードで判定する CI・
   `composer run setup` などに同じ問題が残る（本テンプレートの CI 方針は
   `team-rules/security.md` が `composer audit` / `phpstan` を挙げるのみで、テストの扱いは未定）

## 推奨

案 4 を採ったうえで、上流（https://github.com/laravel/pao/issues）へ報告する。原因が
`Plugin.php` の 3 行に特定できており、Pest 側に既に同じガードがある以上、上流で直るのが
筋であり、テンプレート側の恒久的な作り込みは負債になるため。案 2・3 は pao の利点を
捨てる割に、上流修正後に取り消す手間が残る。

## 決めてほしいこと

上記 4 案のどれを採るか（推奨は案 4: 手順書に既知事象として明記し、上流へ報告する）。

## 暫定対応

なし。テンプレート本体には手を入れていない。

本トライアルでは Phase 1 の完了基準「`php artisan test` が green」を、終了コードではなく
**`--log-junit` の `errors="0" failures="0"` と pao の `"result":"passed"`** で満たしたものと
判定して先へ進めた。
