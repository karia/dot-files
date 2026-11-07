---
name: renovate-triage
description: Renovateの依存関係更新PRをトリアージし、必要な修正・承認・マージ・後片付けまで行う。「renovateのPRをトリアージしてマージして」「依存関係更新PRを片付けて」のような依頼で使用する。リポジトリやPR番号が引数で渡された場合は、その範囲だけを対象にする。
---

# Renovate PRのトリアージとマージ

更新内容と実行環境の互換性を確認し、安全に取り込めるPRを1件ずつマージする。対象リポジトリの`CLAUDE.md`に固有ルールがあれば優先する。以下のコマンドはすべて対象リポジトリのCWDで実行する。

## (1) 着手前の確認

- `pwd`と`git rev-parse --show-toplevel`で、CWDが対象リポジトリのトップかを確認する。
- `git status --short`で未コミット変更を確認し、他の作業の変更を退避・破棄・上書きしない。
- `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`でdefault branch名を調べ、`git branch --show-current`と照合する。default branch以外なら、既存作業を保護できることを確認してから`git switch <default branch>`で移動する。
- `CLAUDE.md`を読み、`git fetch --prune`と`git pull --ff-only`で最新化する。失敗したら原因を確認し、強制的に履歴を合わせない。
- ランタイム指定、ビルドコマンド、デプロイ設定、CIワークフローの中身を読む。ローカル・CI・ビルド・デプロイ先で、どの設定が実際に使われるかを把握する。
- `git log --first-parent --format='%h %s' -n 20`と最近のマージ済みPRを照合し、通常のマージ方法を調べる。merge・squash・rebaseを決め打ちせず、不明ならリポジトリの方針を確認する。

## (2) 対象PRと保留更新の一覧

```bash
gh pr list --author app/renovate --state open --limit 100 --json number,title,url,headRefName,headRefOid,baseRefName,statusCheckRollup,mergeable,mergeStateStatus
gh issue list --state open --search '"Dependency Dashboard" in:title' --limit 100
```

- 一覧が上限に達したら`--limit`を増やして全件を取得する。PR番号の指定があれば、その範囲に絞る。対象の作成者とbase branchも確かめる。
- Dependency Dashboardがあれば`gh issue view <Issue番号>`で本文を読む。同時作成数・時間当たりの制限で待機中の更新と、承認待ち・保留中の更新を確認する。
- `mergeable`が未確定なら再取得する。競合やチェック失敗を解消済みと見なさない。

## (3) PRごとの判定と修正

`gh pr view <PR番号> --json body,headRefName,headRefOid,baseRefName`で本文のリリースノートを読み、`gh pr diff <PR番号>`で差分を確認する。大きな差分はファイル単位に絞り、追加・削除行を中心に読む。ロックファイルは依存先・バージョン・解決元の変化を確認し、ハッシュ値の逐語確認は省く。

### 判定基準

| 分類 | 判断する内容 |
|---|---|
| 安全に取り込める候補 | ツールのpatch・minor更新、固定したActionのSHA更新、ロックファイルのみの更新で、互換性を確認でき、CIが成功している |
| 修正が必要 | ランタイム更新などが実行環境と合わず、そのままではビルド・デプロイ・実行に支障がある |
| メジャー更新 | 破壊的変更を読み、影響する利用箇所を`rg`で探して互換性と修正の要否を判断する |

- CIの成功に加え、**変更箇所をCIが検証しているか**を確認する。CIが独自にランタイムを固定していると、ローカルやビルド用のバージョン指定の更新は検証されないことがある。
- デプロイ先が対応するランタイムを公式資料や実際の設定で確かめる。ビルドコマンドがバージョン管理ツールを呼ぶなど、更新対象への暗黙の依存も追う。互換性を確認できないPRは理由を添えて残す。
- 修正が必要なら、互換性のある最新バージョンへの変更をRenovateブランチへ追加する、`gh pr close <PR番号>`で閉じる、理由を添えて依頼者に残す、のいずれかを選ぶ。閉じる前にDashboardやRenovate設定を確認し、今後の更新提案への影響を把握する。
- 修正する場合は対象ブランチと先端SHAを取り直し、専用のローカルブランチで変更する。必要な検証を行い、修正をcommitして対象のRenovateブランチへpushする。公開前は`secret-scan-before-push`に従う。
- バージョンや更新内容を変えたら、`gh pr edit <PR番号> --title '<修正後のタイトル>'`でタイトルも合わせる。
- **Renovateは手動編集を検知したブランチの自動更新を止めることがある。** 修正したPRを記録し、その後の追従が手動になる可能性を依頼者へ伝える。

## (4) 1件ずつ承認してマージ

1. 対象PRの最新の差分と先端SHAを取得し、判定後に内容が変わっていないか確認する。
2. `gh pr checks <PR番号> --watch`でチェック完了を待ち、必須チェックがすべて成功したことを確認する。保留中・失敗中はマージしない。チェックがない場合や必須チェックが見当たらない場合は、ワークフローと必須設定を照合し、未実行を成功扱いしない。
3. `gh pr review <PR番号> --approve`で承認する。承認できなければ理由を報告して残し、保護ルールを迂回しない。
4. 通常の方法に応じて`gh pr merge <PR番号> --merge --match-head-commit <確認済みSHA>`を実行する。squashなら`--merge`を`--squash`、rebaseなら`--rebase`に置き換える。先端が変わっていたら差分・CI・承認を確認し直す。
5. `gh pr view <PR番号> --json state,mergedAt`でマージ済みを確認してから次へ進む。マージキューに入った場合は完了を待つ。

### 競合とRenovateによる追従

- 同じバージョン指定ファイルやワークフローの隣接行を更新するPRは、先行PRのマージ後に競合しやすい。
- 競合したPRはRenovateが自動でrebaseすることが多い。まず`git fetch --prune`とPR情報の再取得で先端SHAを確かめ、Renovateの追従を待つ。
- 手動で追従する場合は、fetch後に再作成元のリモート先端SHAを記録する。最新の`origin/<default branch>`から専用のローカルブランチを作り、対象PRの意図した変更だけを再作成する。他者のcommitや手動修正を落とさず、差分と必要な検証を確認する。
- 公開前の確認後、`git push --force-with-lease=refs/heads/<Renovateブランチ>:<記録したSHA> origin HEAD:refs/heads/<Renovateブランチ>`で更新する。
- `stale info`で拒否されたら、Renovateなどが先に更新した可能性がある。再fetchして差分と先端を確認する。新しいSHAへ機械的に置き換えて再pushせず、更新済みならそのブランチを使う。
- 自動・手動を問わず、rebase後は差分を読み直し、新しい先端SHAに対するCIの完了を待ってから承認・マージする。

### 新規PRの取り込み

一巡したら(2)の一覧とDashboardを再取得する。マージで同時作成数・時間当たりの枠が空き、新しいPRが作成されることがある。対象範囲の新着も(3)から判定し、処理できるPRがなくなるまで繰り返す。作成待ち・承認待ち・修正待ちが残る場合は、その理由を記録して終える。PR番号の指定範囲は広げない。

## (5) 後片付けと報告

- `git switch <default branch>`で戻り、`git pull --ff-only`で最新化する。
- 手動修正・rebase用に今回作ったローカルブランチを`git branch -d <ブランチ名>`で削除する。未マージ判定で削除できない場合は強制削除せず、残ったブランチを報告する。他の作業のブランチは触らない。
- 依頼者へ次を報告する。
  - マージしたPRの番号とURL。
  - 修正したPRとその理由、自動更新が止まる可能性。
  - 閉じたPR・残したPR・Dashboardの待機項目と、それぞれの理由。
  - 未確認の影響。インフラやツールの更新をマージしても、デプロイや実環境での動作確認まで行ったとは扱わない。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| default branch名を固定する | リポジトリから取得する |
| CI成功だけで互換性を判断する | CIが検証する範囲と実行環境を照合する |
| メジャー更新をバージョン番号だけで判断する | 破壊的変更とコードの利用箇所を確認する |
| 手動編集後もRenovateの自動追従を期待する | 自動更新が止まる可能性を報告する |
| 競合したらすぐに手動rebaseする | fetchしてRenovateの追従を確認する |
| leaseの拒否後に強制pushする | 先行更新を取得して検証する |
| rebase前のCI結果でマージする | 新しい先端SHAの差分とCIを確認する |
| 最初の一覧を処理して終える | 新着PRとDashboardを再確認する |
