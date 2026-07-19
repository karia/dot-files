---
name: merged-branch-cleanup
description: PR マージ後の後片付け手順。default branch への復帰・最新化、マージ済み local branch と worktree の安全な削除、最新 default branch への rebase、前提 PR が取り込まれた後の PR description 更新までを行う。「マージしたのでdefault branchに戻って」「masterに戻って」「マージ済みのbranch/worktreeを削除して」「最新のdefault branchを取得してrebaseして」「マージ済みのworktreeディレクトリを削除して」のような依頼で使用する。
---

# マージ後の後片付け手順

PR がマージされた後に、作業環境を次の作業へ戻すための手順。branch や worktree の削除は元に戻せない破壊的操作なので、削除前に「本当にマージ済みか」「未保存の変更がないか」を必ず検証する。

これは個人の作り方であり、会社としての規定ではない。実行前に、対象リポジトリの `CLAUDE.md` に固有ルールがあればそれを優先する。

## (1) 着手前の確認（安全確認）

- `pwd` で CWD が対象リポジトリのトップかを確認する。git コマンドは素で実行し、`cd <絶対パス> && git ...`・`git -C <パス>`・`GIT_DIR=`/`GIT_WORK_TREE=` によるパス指定はしない。
- `git status` で未コミットの変更がないかを確認する。未コミット・未 push の変更が残っていたら、branch 切替や削除に進む前に依頼者に確認する（切替・削除で失う恐れがある）。
- default branch 名を決め打ちしない。`git remote show origin` や `git symbolic-ref refs/remotes/origin/HEAD` で確認する（`main`/`master`/`develop` のいずれか）。

## (2) default branch への復帰と最新化

- default branch へ切り替える（`git switch <default>`）。
- 最新化する（`git fetch --prune` の後 `git pull --ff-only`）。fast-forward できない場合は状況を確認してから対処する。

## (3) マージ済み local branch の削除

- 削除候補が本当にマージ済みかを検証する。`git branch --merged <default>` に出るか、`gh pr view <branch> --json state`（または PR 番号）で `MERGED` を確認する。
- 検証できたら `git branch -d <branch>` で削除する（`-d` はマージ済みでないと拒否する安全側）。`-D` での強制削除は、未マージと分かっていて捨てると明示された場合のみ、確認を取ってから使う。

## (4) マージ済み worktree の削除（破壊的操作）

- worktree の削除はディレクトリごと消える破壊的操作。以下を確認してから実施する。
  - 対象 worktree の branch がマージ済みであること（(3) と同じ方法で検証）。
  - 対象 worktree に未コミットの変更がないこと。
- 削除対象の worktree の中にいる場合は、そのままでは削除できない。先に単独 cd で main worktree（元ディレクトリ＝リポジトリトップ）へ戻る。main worktree のパスは `git worktree list` の先頭行で特定できる。
- `git worktree list` で対象パスを特定し、`git worktree remove <path>` で削除する。ディレクトリへ `cd` せず、リポジトリトップからパス指定で消す。
  - `git worktree remove` は未コミット変更やロックがあると拒否する。`--force` は、失う変更がないと確認できた場合のみ使う。
- 削除後に `git worktree prune` で参照を掃除する。
- worktree を専用フォルダ（例: `<repo>.worktrees/`）にまとめている場合、削除でそのフォルダが空になることがある。空なら `rmdir <専用フォルダ>` で掃除する。非再帰の `rmdir` は、他の worktree が残っていれば安全に失敗するので、中身の有無を気にせず打ってよい。

## (5) rebase・前提 PR の後始末（依頼された場合）

- 「最新の default branch へ rebase」を求められたら、(2) で最新化した後に作業 branch で `git rebase <default>` する。
- 前提としていた PR（例: `#100`）が取り込まれた場合は、現在の PR description にその前提 PR への言及があれば、実態に合わせて修正・削除する（マージ済みなので「前提」ではなくなっている）。

## (6) 仕上げの確認

- `git status` と `git worktree list` で、default branch にいること・不要な branch/worktree が残っていないことを確認する。
- 次の指示を待つ、または依頼された後続作業へ進む。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| default branch 名を `main` と決め打ちする | remote から実際の default を確認する |
| マージ確認せず branch を消す | `--merged` や `gh pr view` で `MERGED` を検証する |
| いきなり `git branch -D` する | まず安全側の `-d`。`-D` は確認後のみ |
| worktree を未確認で `--force` 削除する | 未コミット変更がないと確認してから削除する |
| worktree ディレクトリへ `cd` して消す | リポジトリトップからパス指定で `worktree remove` |
| 削除対象の worktree の中にいたまま remove しようとして失敗する | 先に単独 cd で main worktree（リポジトリトップ）へ戻る |
| 削除後に空の専用フォルダ（`<repo>.worktrees/`）を残す | 空なら `rmdir` で掃除する |
| 前提 PR 取り込み後も description を放置する | 言及があれば修正・削除する |
