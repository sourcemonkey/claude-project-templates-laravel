# Phase 3 手順書が `update-profile-information-form.blade.php` を「修正せよ」と「使うな」の両方で指示していて、削除するかどうかが決まらない

- フェーズ: Phase 3
- 状態: 未解決
- 初回観測: 2026-07-20

## 何が起きたか

`/scaffold-phase3-ui` の「Breeze 生成物の追従」で、Breeze が生成する Volt コンポーネント
`resources/views/livewire/profile/update-profile-information-form.blade.php` の扱いが
手順 1・3・4 で食い違っており、**残すのか消すのか**が手順書から一意に決まらなかった。

- 手順 1 は、このファイルを `route('dashboard')` → `route('home')` の**置換対象に挙げている**
  （＝ファイルが残る前提の指示）
- 手順 3 は、name / email の更新を「Breeze の Volt ではなく仕様の `PATCH /profile` で行う」とし、
  `tests/Feature/ProfileTest.php` から `assertSeeVolt('profile.update-profile-information-form')`
  を**削除せよ**と指示している（＝画面から外れて未使用になる）
- 手順 4 の削除リストには `dashboard.blade.php` / `profile.blade.php` / `welcome.blade.php` /
  `livewire/welcome/` の 4 つが挙がっているが、**このファイルは含まれていない**

今回のトライアルでは「未使用の Volt コンポーネントを残すのは死んだコードになる」と判断して
削除した。テスト（Feature 103 件 / Dusk 5 件）はすべて green で、削除による破綻は起きていない。

## 根拠

手順書の該当箇所を原文のまま引く。

手順 1（置換対象の列挙）:

```
1. `route('dashboard')` の参照を **`route('home')` に置き換える**（ログイン・登録・メール確認後の
   遷移先を `/` にする）。対象:
   ...
   - `resources/views/livewire/profile/update-profile-information-form.blade.php`
```

手順 3（当該 Volt を画面から外す指示）:

```
   - name / email の更新は Breeze の Volt（`profile.update-profile-information-form`）ではなく
     仕様の `PATCH /profile`（`ProfileController@update` + `UpdateProfileRequest`）で行う
   ...
   - `tests/Feature/ProfileTest.php` をこの構成に合わせて書き換える
     （`assertSeeVolt('profile.update-profile-information-form')` の行は、当該 Volt を
     画面から外すため**削除する**。残すと `profile page is displayed` が失敗する）
```

手順 4（削除リスト。当該ファイルは含まれない）:

```
4. 不要になったビューを削除する: `resources/views/dashboard.blade.php`,
   `resources/views/profile.blade.php`, `resources/views/welcome.blade.php`,
   `resources/views/livewire/welcome/`
```

- 関連ファイル: `my-laravel-app/.claude/commands/scaffold-phase3-ui.md:34`（手順 1）、
  `:56`（手順 3）、`:62`（手順 4）

## なぜ自動で直さなかったか

「共通の進め方」手順 4 の「妥当な解が複数あり、どれを採るかが**方針の選択**になる」に当たる。
残す / 消すのどちらでも動作し、判断基準は「Breeze の生成物をどこまで温存するか」という
テンプレートの方針そのもの。

## 選択肢

1. **削除する（手順 4 のリストに追加し、手順 1 の対象から外す）** — 影響: 未使用ファイルが
   消えて `resources/views/livewire/profile/` にはパスワード変更・退会の 2 つだけが残り、
   「画面に載っているものだけがある」状態になる / 懸念: 将来 Breeze 標準のプロフィール更新へ
   戻したくなった場合、`breeze:install` をやり直すか手で書き直す必要がある
2. **残す（手順 4 はそのまま、手順 1 の指示も維持）** — 影響: 手順書の現状の記述と一致し、
   `route('home')` へ直す指示も意味を持つ / 懸念: どの画面からも参照されない Volt
   コンポーネントが残り、読み手が「どこで使われているのか」を探す手間が生じる。
   `team-rules/coding-standards.md` の「1 ファイル 1 責務」の趣旨からも外れる

## 推奨

案 1（削除する）。未使用の生成物を残すと、後から読む人が `profile.edit` と
`update-profile-information-form` のどちらが有効なのかを判断できず、
今回と同じ迷いを繰り返すため。

## 決めてほしいこと

`resources/views/livewire/profile/update-profile-information-form.blade.php` を
Phase 3 で削除する（手順 4 のリストに追加し、手順 1 の置換対象から外す）でよいか。

## 暫定対応

トライアルでは**削除した**。`resources/views/profile/edit.blade.php` は
`profile.update-password-form` と `profile.delete-user-form` の 2 つの Volt のみを載せ、
name / email は `PATCH /profile` のフォームで更新する構成になっている。
テンプレート本体（手順書）には手を入れていないため、案 2 に決まった場合でも
取り消すべき差分はない。
