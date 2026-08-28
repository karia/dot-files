---
name: pr-flow
description: 自己流の GitHub Pull Request 作成手順。作業は元ディレクトリを default branch に保ったまま、`EnterWorktree` が `.claude/worktrees/` 配下に作る git worktree で行う。worktree の用意・テーマ別の commit 分割・pre-commit 確認・PR テンプレートの探索と記入・title/description の言語選択・作成後の URL 確認・（`karia/` 配下では）マージ監視と worktree 削除までを一貫して行う。「PRを作って」「PR化して」「この変更をPRにして」「branch切ってPR」「draft PRを作成して」「未コミットの変更を分けてPRにしたい」のような依頼で使用する。対象テーマや JIRA 課題 ID が引数で渡された場合はそれを対象にする。
---

# 自己流 Pull Request 作成手順

これは個人の作り方であり、会社としての規定ではない。commit と PR に関する規約を、着手から作成後確認までの一連のワークフローとして束ねたもの。実行前に、対象リポジトリの `CLAUDE.md` に固有ルールがあればそれを優先する。

作業は元ディレクトリ（対象リポジトリのトップ）を default branch の最新状態に保ったまま、リポジトリ内の `.claude/worktrees/` 配下に作った git worktree の中で行う。元ディレクトリの branch は切り替えない。これにより、作業中も元ディレクトリを clean な default branch として参照・別作業に使える。

## (1) 着手前の確認と worktree の用意

- `pwd` で CWD が対象リポジトリのトップかを確認する。ここが**元ディレクトリ**であり、作業後も default branch のまま保つ。git コマンドは素で実行し、`cd <絶対パス> && git ...`・`git -C <パス>`・`GIT_DIR=`/`GIT_WORK_TREE=` によるパス指定はしない（承認プロンプトの発生を避けるため）。
- 元ディレクトリが default branch（`main`/`master`/`develop` など）にいることを確認する。default 名は決め打ちせず `git symbolic-ref refs/remotes/origin/HEAD` などで確認する。default 以外にいる場合は、元ディレクトリの branch は切り替えない方針のため、依頼者に状況を知らせてから進める。
- 今回 PR にしたい未コミット変更が元ディレクトリにある場合は `git stash -u -m "pr-flow carry"` で退避する。worktree に未コミット変更は引き継がれないため、後で worktree 側へ持ち込む。
- 元ディレクトリの default branch を最新化する（`git fetch --prune` → `git pull --ff-only`）。
- `EnterWorktree` ツールに `name` を渡し、worktree の作成とセッションの移動を一度に行う。自分で `git worktree add` してから `path` で入る形は使わない（理由は後述）。
  - 作成先は `<元ディレクトリ>/.claude/worktrees/<name>` になる。`name` に含めた `/` は、ディレクトリ名では `+` に置換される。
  - `name` は 64 文字以内で、`/` 区切りの各セグメントは英数字・ドット・アンダースコア・ハイフンのみを使う。
  - `name` は PR ごとに一意にする。既存の worktree と同名を渡すと、その worktree を再開し、前回の commit が残った状態から作業を始めることになる。
  - 基点は `worktree.baseRef` 設定に従い、既定の `fresh` では `origin/<default branch>` から切られる。直前に `git fetch --prune` を済ませていれば、worktree も最新の default branch から始まる。
- Bash ツールの単独 `cd` で代用しない。`cd` が変えるのは Bash の CWD だけで、セッションの作業ディレクトリ・書き込み権限の範囲・読み込まれる `CLAUDE.md` と設定は元ディレクトリのまま残る。`EnterWorktree` はこれらをまとめて worktree へ移す。
- 移動後に `pwd` で worktree にいることを確認する。以降の git/gh は worktree の CWD で素の形で実行する。
- worktree の中で `git branch -m <branch 名>` を実行し、PR 用の branch 名に改名する。`EnterWorktree` が自動で付ける `worktree-<name>` は変更内容を表さないため、そのまま push しない。branch 名は変更内容が分かる名前にする（JIRA 課題があれば ID を含めてよい）。push より前に済ませる。
- worktree の中身が元ディレクトリの未コミット変更として現れないよう、`.claude/worktrees/` を git の追跡対象から外す。自分のリポジトリなら `.gitignore`、他者と共有するリポジトリなら `.git/info/exclude` に書く。`.claude/` ごと無視しているリポジトリでは設定は要らない。
  - `.gitignore` に書く場合、その変更は元ディレクトリではなく worktree 側の作業 branch で commit する。元ディレクトリは default branch のまま保つ。
- 元ディレクトリで退避していれば、worktree 側で `git stash pop` して変更を持ち込む（stash は共通 git dir を共有するため worktree から pop できる）。
- 今回どの変更を PR にするかを確定する。作業ツリーに複数テーマの変更が混在している場合は、今回の PR 対象テーマだけを扱う。

<details>
<summary><code>path</code> ではなく <code>name</code> を渡す理由</summary>

`EnterWorktree` に `path` を渡す形は、対象が `.claude/worktrees/` の外にあると毎回確認プロンプトが出る。worktree への移動は、作業ディレクトリと書き込み権限が移り、移動先の `CLAUDE.md` と設定が読み込まれる操作であり、セッションの権限ルートが移るためである。ユーザーの承認を求めずに進むモードではこの確認を通せず、そこで手順が止まる。`name` を渡す形は作成先が `.claude/worktrees/` に固定されるため、確認が出ない。

</details>

## (2) commit（テーマ単位で細かく）

以降の git/gh は (1) で移動した worktree の CWD で、素の形で実行する。

- `git add -p` で今回のテーマに関係する部分だけをステージングする。無関係な変更を巻き込まない。
- ステージング後に `git diff --cached` で内容を確認する。本来の作業と無関係な変更が混ざっていたら、commit 前に依頼者に確認する。
- commit はなるべく細かい単位に分ける。テーマが複数あれば commit も分ける。
- commit メッセージ:
  - 1 行に収める（1 行目しか表示されないため）。補足や `Co-Authored-By:` は 2 行目以降に置く。
  - 複数行を渡すときは実行中の shell の構文に従う。zsh/bash では `-m` を複数指定する。PowerShell の here-string `@'...'@` は zsh で先頭に `@` が混入するため使わない。
  - 言語は、リポジトリが `karia/` 配下なら英語。それ以外は過去の commit メッセージと同じ言語に合わせる。
- pre-commit:
  - `.pre-commit-config.yaml` があるリポジトリでは、フックがインストール済みか（`.git/hooks/pre-commit` の有無）を確認する。未インストールなら commit 前に `prek install`（無ければ `mise exec -- prek install`）を実行する。
  - pre-commit の警告は原則 skip しない。skip が必要なら理由込みで依頼者に確認する。失敗したら原因を直す。
- linter を手で叩くときは、worktree の CWD で実行する。worktree は無視設定を入れた `.claude/worktrees/` の配下にあるため、元ディレクトリを CWD にして worktree 内のファイルを渡すと、対象から黙って外れる。prek 経由の hook は worktree 側で走るのでこの問題は起きない。

## (3) PR 作成

- 対象 branch を push する。push 前の確認は `secret-scan-before-push` skill に従う。
- PR作成前にテンプレートを探す。通常はリポジトリルートの `pull_request_template.md` だが、`.github/` 配下やサブディレクトリにある場合もある。`.github/PULL_REQUEST_TEMPLATE/` も確認する。
- GitHub CLIを利用してPRを作成する。このとき以下に注意する。
  - title/description の言語は、`karia/` 配下なら英語で統一。それ以外（特に organization 配下）はレビュアーが日本人のため、特別な指示がなければ日本語で記述する。
  - draft を求められた場合は `--draft` を付けて draft PR として作成する。
  - 第三者レビューを回す場合は draft のまま作成し、以降は `third-party-review` に従う。レビュアーの起動・指摘への返信・ready for review 化・マージ監視の開始まで、同 skill が扱う。

### description記述方法

- まず `tech-writing-style` skillを読み込み、規範に従う。日本語と英数字の間にスペースを入れない詰め書きにする。
- 書き上がったら `sanitize-artifacts` skillで確認する。
- テンプレートがある場合はテンプレート通りに記入する。
  - 項目を自己判断で削除しない。記入不要な項目は空欄のまま残す（テンプレートに削除指示がある場合のみ削除する）。
- JIRA 課題に紐づくなら課題 ID・リンクを PR に付与する。
- 記述量はミニマムに保つ。例えば、以下の様なことは書かない。
  - コードを読めば自明なこと
  - 変更したファイル名や関数名（レビュワーはPRのFile Changesを読むので書く必要がない。概要が肥大化する原因であり不要。）
  - cspell辞書への追加（PR変更の本筋ではない）
  - linter・formatterをpassしたことの報告（PRを出す時点で、passしていることは当たり前）

### 実装意図の説明

- 実装意図はソースコメントやdescriptionに書かず、GitHubの行コメントで説明する。ただし、コンテキストを知らない第三者への説明が必要な場合に限定する。
- GitHubの行コメントは、指示があった場合を除き、自らで書いてはならない。「行コメント必要箇所」として依頼者に提示する。その際、「何をコメントすべきか」「なぜコメントが必要か」を明確にする。

## (4) 作成後の確認（検証・後片付け）

- 作成した PR の URL を `open` コマンドで開き、テンプレート記入・description・課題紐付けを目視確認する。
- 今回の対象外のテーマの変更が作業ツリーに残っている場合は、今回の PR に含めず、別 PR・別 commit として扱う。
- `karia/` 配下かつ非 draft の PR の場合は、マージ監視を仕掛ける。`karia/` 配下では PR 作成後すぐにマージされることが多く、都度「default branch に戻って」と指示する手間を省くため。Claude Code のスケジュール済みタスク（`/loop` skill）を使い、独自の shell ループは組まない。
  - 間隔は指数関数的 backoff にする。`/loop` を間隔指定なしで仕掛け（動的間隔モード）、待ち時間の伸ばし方をプロンプト自体に書く。初回 2 分ですぐマージされるケースを拾い、レビュー待ちで長時間かかるケースでは確認回数を抑えるため。上限 60 分は `ScheduleWakeup` の上限に合わせている。マージ/close を検知したら自分でループを止める。PR 番号は作成時の出力から取得する。作業は worktree の中で行うため、後片付けは `merged-branch-cleanup` に委ね、プロンプトに元ディレクトリと worktree の絶対パスを埋め込む。プロンプトは毎回同じものが再投入され、何回目の確認かはプロンプト自体からは分からないため、待ち時間を毎回発言に残させて次回そこから決められる形にする。マージ待ちはイベント待ちに見えるが `Monitor` は使わない。即時 wake すると backoff が効かなくなるため。例:
    ```text
    /loop PR #<PR番号> が `gh pr view <PR番号> --json state -q .state` でマージ済みか確認する。MERGED なら merged-branch-cleanup の手順で後片付けする（元ディレクトリ <元repo絶対パス> へ戻り、worktree <worktree絶対パス> と作業 branch を削除）。済んだらループを終了する。CLOSED（未マージ）ならループを止めて知らせる。OPEN なら次の確認まで待つ。待ち時間は前回宣言した値の 2 倍（初回は 2 分、60 分で頭打ち）とし、毎回「次の確認まで N 分待つ」と明記してから待つ。`Monitor` は使わない
    ```
  - マージ検知時の後片付けは `merged-branch-cleanup` に従う。元ディレクトリへ戻る・default branch の最新化・worktree と作業 branch の削除・破壊的操作の確認ゲートまで、すべて同 skill が扱う。
  - スケジュール済みタスクはセッションスコープ（セッション終了で停止、`--resume`/`--continue` で 7 日以内なら復元）。停止したいときは待機中に `Esc`、または Claude にタスクのキャンセルを依頼する（内部的には `ScheduleWakeup` を `stop: true` で呼ぶ）。
- draft PR や `karia/` 以外のリポジトリでは、この監視は仕掛けない。worktree の作成・削除は監視の有無に関わらず行うため、監視を仕掛けない場合の worktree 削除は、マージ後に依頼者の指示で `merged-branch-cleanup` の手順で行う。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| 元ディレクトリでその場に branch を切る | worktree を作ってその中で作業し、元ディレクトリは default branch に保つ |
| `git worktree add` で作った worktree に `path` で入る | `EnterWorktree` に `name` を渡し、作成と移動を一度に行う |
| 自動で付く `worktree-` 始まりの branch 名のまま push する | push 前に `git branch -m` で PR 用の branch 名に改名する |
| 元ディレクトリの未コミット変更を置き去りにする | `git stash -u` で退避し worktree で pop して持ち込む |
| 単独 `cd` で worktree へ移動したつもりになる | `cd` は Bash の CWD しか変えない。`EnterWorktree` に `name` を渡す |
| worktree に居たまま削除しようとして失敗する | 先に `ExitWorktree`（`action: "keep"`）で元ディレクトリへ戻ってから削除する |
| default branch で直接 commit する | worktree の作業 branch で commit する |
| 元ディレクトリを CWD にして worktree 内のファイルを linter にかける | linter は worktree の CWD で実行する |
| 全変更を一括ステージングする | `git add -p` でテーマ別に分ける |
| テンプレートの不要項目を削除する | 空欄のまま残す |
| テンプレートをルートだけ探す | `.github/` やサブディレクトリも探す |
| description にコードで分かることを詳述する | ミニマムに保つ |
| 作成して終わりにする | `open` で URL を開いて確認する |
| `karia/` の PR をマージ後に手動で default branch に戻る | 作成時に `/loop` でマージ監視を仕掛け、マージ検知で自動復帰する |
| マージ監視に独自 shell ループを組む | Claude Code のスケジュール済みタスク（`/loop`）を使う |
| マージ監視を短い固定間隔で回し続ける | 指数関数的 backoff（2 分から倍々、上限 60 分）で伸ばす |
