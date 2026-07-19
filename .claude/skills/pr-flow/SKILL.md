---
name: pr-flow
description: 自己流の GitHub Pull Request 作成手順。作業は元ディレクトリを default branch に保ったまま横並びの git worktree で行う。worktree の用意・テーマ別の commit 分割・pre-commit 確認・PR テンプレートの探索と記入・title/description の言語選択・作成後の URL 確認・（`karia/` 配下では）マージ監視と worktree 削除までを一貫して行う。「PRを作って」「PR化して」「この変更をPRにして」「branch切ってPR」「draft PRを作成して」「未コミットの変更を分けてPRにしたい」のような依頼で使用する。対象テーマや JIRA 課題 ID が引数で渡された場合はそれを対象にする。
---

# 自己流 Pull Request 作成手順

これは個人の作り方であり、会社としての規定ではない。commit と PR に関する規約を、着手から作成後確認までの一連のワークフローとして束ねたもの。実行前に、対象リポジトリの `CLAUDE.md` に固有ルールがあればそれを優先する。

作業は元ディレクトリ（対象リポジトリのトップ）を default branch の最新状態に保ったまま、横並びに作った git worktree の中で行う。元ディレクトリの branch は切り替えない。これにより、作業中も元ディレクトリを clean な default branch として参照・別作業に使える。

## (1) 着手前の確認と worktree の用意

- `pwd` で CWD が対象リポジトリのトップかを確認する。ここが**元ディレクトリ**であり、作業後も default branch のまま保つ。git コマンドは素で実行し、`cd <絶対パス> && git ...`・`git -C <パス>`・`GIT_DIR=`/`GIT_WORK_TREE=` によるパス指定はしない（承認プロンプトの発生を避けるため）。
- 元ディレクトリが default branch（`main`/`master`/`develop` など）にいることを確認する。default 名は決め打ちせず `git symbolic-ref refs/remotes/origin/HEAD` などで確認する。default 以外にいる場合は、元ディレクトリの branch は切り替えない方針のため、依頼者に状況を知らせてから進める。
- 今回 PR にしたい未コミット変更が元ディレクトリにある場合は `git stash -u -m "pr-flow carry"` で退避する。worktree は HEAD から作られ、未コミット変更は自動では引き継がれないため、後で worktree 側へ持ち込む。
- 元ディレクトリの default branch を最新化する（`git fetch --prune` → `git pull --ff-only`）。
- 横並びに worktree を作る。branch 名は変更内容が分かる名前にする（JIRA 課題があれば ID を含めてよい）。ディレクトリは元リポジトリの中ではなく、専用フォルダ `<repo親>/<repo>.worktrees/<branch-slug>` に置く（例: `~/ghq/github.com/karia/dot-claude.worktrees/add-flow`）。leaf 名は branch 名の `/` を `-` に置換した slug にする:
  ```bash
  top=$(git rev-parse --show-toplevel)     # 元ディレクトリ（cd 前に取得）
  parent=$(dirname "$top"); repo=$(basename "$top")
  slug=${BRANCH//\//-}
  wt="$parent/$repo.worktrees/$slug"
  git worktree add "$wt" -b "$BRANCH"      # パス引数は可（git -C ではない）。中間フォルダも作られる
  ```
  専用フォルダ形式なら、`ghq list`（`.git` の有無でリポジトリ判定し worktree の `.git` ファイルも拾う）の一覧で worktree だと判別でき、本物リポジトリに紛れない。
- worktree へ移動する: 単独の `cd "$wt"`（`cd <絶対パス> && git ...` の複合形ではない単独 cd なので、上の禁止事項には当たらない）。Bash ツールは呼び出し間で CWD を維持するため、以降の git/gh は worktree の CWD で素の形で実行する。移動後に `pwd` で worktree にいることを確認する。
- 元ディレクトリで退避していれば、worktree 側で `git stash pop` して変更を持ち込む（stash は共通 git dir を共有するため worktree から pop できる）。
- 今回どの変更を PR にするかを確定する。作業ツリーに複数テーマの変更が混在している場合は、今回の PR 対象テーマだけを扱う。

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

## (3) PR 作成

- 対象 branch を push する。push 前の確認は `secret-scan-before-push` skill に従う。
- テンプレートを探す。通常はリポジトリルートの `pull_request_template.md` だが、`.github/` 配下やサブディレクトリにある場合もある。`.github/PULL_REQUEST_TEMPLATE/` も確認する。
- テンプレートがある場合はテンプレート通りに記入する。
  - 項目を自己判断で削除しない。記入不要な項目は空欄のまま残す（テンプレートに削除指示がある場合のみ削除する）。
- description:
  - 記述量はミニマムに保つ。コードを読めば分かることは書かない。
  - JIRA 課題に紐づくなら課題 ID・リンクを PR に付与する。
- title/description の言語は、`karia/` 配下なら英語で統一。それ以外（特に organization 配下）はレビュアーが日本人のため、特別な指示がなければ日本語で記述する。
- 日本語で書く箇所は `japanese-tech-writing` の規範に従い、日本語と英数字の間にスペースを入れない詰め書きにする。
- draft を求められた場合は `--draft` を付けて draft PR として作成する。

## (4) 作成後の確認（検証・後片付け）

- 作成した PR の URL を `open` コマンドで開き、テンプレート記入・description・課題紐付けを目視確認する。
- 今回の対象外のテーマの変更が作業ツリーに残っている場合は、今回の PR に含めず、別 PR・別 commit として扱う。
- `karia/` 配下かつ非 draft の PR の場合は、マージ監視を仕掛ける。`karia/` 配下では PR 作成後すぐにマージされることが多く、都度「default branch に戻って」と指示する手間を省くため。Claude Code のスケジュール済みタスク（`/loop` skill）を使い、独自の shell ループは組まない。
  - 間隔は 2 分固定（`/loop 2m ...`）で仕掛ける。`karia/` 配下はすぐマージされるため、短い固定間隔で素早く検知する。固定間隔ではマージ/close を検知したら自分でループを止める。PR 番号は作成時の出力から取得する。作業は worktree の中で行うため、後片付けは `merged-branch-cleanup` に委ね、プロンプトに元ディレクトリと worktree の絶対パスを埋め込む。例:
    ```text
    /loop 2m PR #<PR番号> が `gh pr view <PR番号> --json state -q .state` でマージ済みか確認する。MERGED なら merged-branch-cleanup の手順で後片付けする（元ディレクトリ <元repo絶対パス> へ戻り、worktree <worktree絶対パス> と作業 branch を削除）。済んだらループを終了する。CLOSED（未マージ）ならループを止めて知らせる。OPEN なら次の確認まで待つ
    ```
  - マージ検知時の後片付けは `merged-branch-cleanup` に従う。元ディレクトリへ戻る・default branch の最新化・worktree と作業 branch の削除・空の専用フォルダの掃除・破壊的操作の確認ゲートまで、すべて同 skill が扱う。
  - スケジュール済みタスクはセッションスコープ（セッション終了で停止、`--resume`/`--continue` で 7 日以内なら復元）。停止したいときは待機中に `Esc`、または Claude にタスクのキャンセルを依頼する（内部的には `CronList`/`CronDelete`）。
- draft PR や `karia/` 以外のリポジトリでは、この監視は仕掛けない。worktree の作成・削除は監視の有無に関わらず行うため、監視を仕掛けない場合の worktree 削除は、マージ後に依頼者の指示で `merged-branch-cleanup` の手順で行う。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| 元ディレクトリでその場に branch を切る | 横並びの worktree を作り、元ディレクトリは default branch に保つ |
| worktree をリポジトリの中に作る | 専用フォルダ `<repo>.worktrees/`（横並び）に作る |
| 元ディレクトリの未コミット変更を置き去りにする | `git stash -u` で退避し worktree で pop して持ち込む |
| worktree に居たまま削除しようとして失敗する | 先に単独 cd で元ディレクトリへ戻ってから削除する |
| default branch で直接 commit する | worktree の作業 branch で commit する |
| 全変更を一括ステージングする | `git add -p` でテーマ別に分ける |
| テンプレートの不要項目を削除する | 空欄のまま残す |
| テンプレートをルートだけ探す | `.github/` やサブディレクトリも探す |
| description にコードで分かることを詳述する | ミニマムに保つ |
| 作成して終わりにする | `open` で URL を開いて確認する |
| `karia/` の PR をマージ後に手動で default branch に戻る | 作成時に `/loop` でマージ監視を仕掛け、マージ検知で自動復帰する |
| マージ監視に独自 shell ループを組む | Claude Code のスケジュール済みタスク（`/loop`）を使う |
