---
name: home-server-update
description: 自宅の Linux サーバー群を最新化する定例手順。各ホストへ Herdr の pane から ssh し、dot-files の git pull とローカル変更の PR 化、mise 管理ツールの更新（mise up）、Claude Code のマーケットプレイスとプラグインの更新までを行う。Tailscale SSH の認証 URL が出たら依頼者に承認を依頼する。「ホームサーバーを最新化して」「自宅サーバーの mise up して」「特定のホストのツールを更新して」のような依頼で使用する。対象ホストが引数で渡された場合はそのホストだけを対象にする。
---

# ホームサーバー最新化手順

自宅の Linux サーバー群で、dot-files・mise 管理ツール・Claude Code プラグインをまとめて最新化する。各ホストへは Herdr の pane から Tailscale SSH で入り、pane 上でコマンドを実行する。pane の操作方法は `herdr` skill に従う。

この手順は Herdr 上のセッション（`HERDR_ENV=1`）で実行する。この skill の起動は Herdr を使う指示を含む。Herdr の外で起動されたときは、依頼者に伝えて止まる。

## 対象ホスト

Tailscale でタグ `tag:home-server` または `tag:wsl` を付けたノードが対象になる。以下で名前・タグ・オンライン状態・作業中のホストかどうかを列挙する。

```bash
tailscale status --json | jq -r '(.Self | .me = true), (.Peer[] | .me = false) | select((.Tags // []) | index("tag:home-server") or index("tag:wsl")) | [(.DNSName | split(".")[0]), (.Tags | join(",")), .Online, .me] | @tsv'
```

- 接続先には 1 列目の名前を使う。`HostName` は OS 上のホスト名で、Tailscale 上の名前と異なることがある。
- 1 件も出ないときは、タグが付いていない。依頼者に伝えて止まる。
- 引数でホストが渡されたら、上の一覧からそのホストだけを対象にする。一覧にないホストなら、依頼者に伝えて止まる。
- 依頼が工程を名指ししているとき（mise up だけ、など）は、(1) の接続と名指しされた工程だけを行う。

| タグ | オフラインのとき |
|---|---|
| `tag:home-server` | 常時起動のはずなので、異常として報告する |
| `tag:wsl` | 常時起動していないので、飛ばして報告に書く |

## (1) 接続

1. ホストごとに pane を作る。
2. 4 列目が `true` のホストは、この手順を実行している手元のホストなので、接続せずにその pane で直接作業する。手元のホスト名はループバックアドレスに解決されることがあり、ssh すると手元の sshd につながる。
3. それ以外のホストでは `tailscale ssh <ホスト>` を実行する。素の `ssh` は、初めて接続するホストでホスト鍵の確認に止まる。`tailscale ssh` は tailnet から取得した鍵で検証するので止まらない。
4. `# To authenticate, visit: https://login.tailscale.com/a/...` と出たら、URL を依頼者に伝えて承認を依頼する。承認されるとそのままログインが進む。`--timeout` を付けた `herdr pane wait-output` を、ログインが済むまで繰り返す。1 回の待ちは Bash ツールの呼び出しの上限を超えないようにする。
5. ログイン後に `hostname` を実行し、意図したホストに入れたか確かめる。

`tailnet policy does not permit you to SSH to this node` で断られたときは、Tailscale の ACL に、そのタグを宛先とする SSH ルールが足りない。依頼者に伝え、そのホストは飛ばす。

### コマンドの完了を待つ方法

コマンドの末尾で終了マーカーを出し、`herdr pane wait-output --match` で待つ。

- マーカーはコマンドごとに変える（`echo __DO""NE_pull__` と `--match __DONE_pull__` のように、工程名や連番を入れる）。`wait-output` は画面に残っている過去の出力も検索するので、同じマーカーを使い回すと前のコマンドのマーカーにすぐマッチする。
- マーカーは `__DO""NE_pull__` のように引用符で分断する。入力したコマンド行の表示にマッチさせないためである。

## (2) dot-files の更新

`~/ghq/github.com/karia/dot-files` で `git pull --ff-only` する。mise の設定（`~/.config/mise/config.toml`）は dot-files へのシンボリックリンクなので、先に pull して最新の設定で (3) を実行する。

- default branch にいるかを `git branch --show-current` で確かめる。いなければ切り替えず、報告に書いて pull を飛ばす。
- pull の後に、止まった場合も含めて `git status --short` で追跡対象ファイルの変更を確かめる。あれば次の「ローカル変更の扱い」に従う。上流が触っていないファイルの変更は pull を止めないので、pull の成否だけでは見つからない。
- 未追跡ファイルは触らない。

### ローカル変更の扱い

変更されたファイルごとに、差分の中身で扱いを決める。stash はしない。

#### 扱いの判定

| 差分の中身 | 扱い |
|---|---|
| origin の default branch と同じ | 取り込み済みの変更なので、`git checkout -- <ファイル>` で破棄する |
| JSON のキーの並び順だけが違う | 意味のない差分なので、`git checkout -- <ファイル>` で破棄する |
| 上の 2 つに当たらない | 実際の差分として PR にする |

- origin と同じかは、`git fetch` の後に `git diff --quiet origin/<default branch> -- <ファイル>` の終了コードが 0 かで確かめる。
- 並び順だけかは、JSON に限って `diff <(git show HEAD:<ファイル> | jq -S .) <(jq -S . <ファイル>)` の出力が空かで確かめる。ツールが設定ファイルを書き戻すときに、キーの順序を入れ替えることがある。
- JSON 以外の形式は、行の順序に意味があることが多い（シェルの PATH 設定、TOML のセクション）。並び順だけとは判定せず、実際の差分として扱う。

破棄したファイルだけで止まっていたなら、もう一度 `git pull --ff-only` する。

#### 実際の差分を PR にする

1. `git diff -- <ファイル>` で差分を読む。
2. 手元の dot-files で、`pr-flow` skill に従って PR を作る。別ホストの差分は pane で読み取り、手元の worktree に反映する。そのホストのファイルは編集しない。
   - JSON の並び替えが混ざっていれば、worktree に反映するときに HEAD の並び順に戻し、実際の差分だけを残す。
   - 同じ差分が複数のホストにあれば、1 つの PR にまとめる。
3. そのホストのローカル変更は残したまま、今回の pull は飛ばして先へ進む。PR がマージされれば、次回の実行で「origin の default branch と同じ」に当たって破棄される。

## (3) mise の更新

ホームディレクトリで `mise up 2>&1 | tail -40` を実行する。報告の `旧版 → 新版` は、出力の末尾にある `Upgraded N tools:` の一覧から書く。

mise 本体は APT で管理しており、この手順では扱わない（sudo の権限がない）。`mise up` の出力に mise 本体の新版の通知が出ても、報告に添えるだけにする。

`mise up` はホストをまたいで同時に走らせず、1 ホストずつ直列にする。どのホストも同じ自宅回線から取得するため、同時に走らせると配布元の rate limit に当たりうる。

dot-files の mise 設定の `minimum_release_age` により、公開から間もない版は見送られる。このとき出る WARN は正常な動作なので、報告に添えるだけでよい。

## (4) Claude Code プラグインの更新

マーケットプレイスの取得とプラグインの更新は別のコマンドなので、この順で両方実行する。マーケットプレイスを更新しないと、キャッシュが古いまま「最新版です」と判定される。更新の前後で版の一覧を保存し、報告に使う。

```bash
claude plugin list --json | jq -r '.[] | "\(.id)\t\(.scope)\t\(.version)"' > /tmp/plugins-before.tsv
claude plugin marketplace update
cut -f1,2 /tmp/plugins-before.tsv | while IFS=$'\t' read -r id scope; do
  echo "--- $id ($scope)"
  claude plugin update "$id" --scope "$scope" --json 2>&1 | tail -1
done
claude plugin list --json | jq -r '.[] | "\(.id)\t\(.scope)\t\(.version)"' | diff /tmp/plugins-before.tsv -
```

- `claude plugin update` はプラグインを 1 つずつ受け取る。scope は `list --json` の値を `--scope` で明示して渡す。
- 結果に `shownCommand` が出たら、マーケットプレイスが宣言したコマンドの確認を求められている。コマンドと sha256 を依頼者に見せ、了承を得てから `--accept-command <sha256>` を付けて再実行する。確認を飛ばす `-y` は付けない。
- マーケットプレイスから消えたプラグインは `not found` で失敗する。失敗扱いにせず、報告して `claude plugin uninstall` するかを依頼者に確かめる。

## (5) herdr サーバーの再起動

`mise up` で herdr の版が上がったホストでは、動いているサーバーが旧版のままなので、クライアントとの版の不一致が出る。依頼者の了承を得てから再起動する。

```bash
herdr server stop
setsid -f herdr server >/dev/null 2>&1 </dev/null
```

- `herdr server stop` は、そのホストの Herdr で動いている pane のプロセスをすべて止める。この手順を実行しているセッション自身が載っているホストでは実行せず、依頼者に手動での再起動を頼む。
- `setsid -f` で切り離して起動すると、ssh が切れてもサーバーは止まらない。起動後に `herdr --version` と `herdr workspace list` で、新しい版で応答することを確かめる。

## (6) 結果の報告

各ホストで `cat /var/run/reboot-required 2>/dev/null` を実行し、OS の再起動が要るかを確かめてから、ホストごとに以下をまとめる。

- 接続：接続できたか。飛ばしたホストはその理由。
- dot-files：pull の結果。破棄したファイルと、その理由。作った PR の URL。
- mise up：更新したツールの `旧版 → 新版`。メジャーバージョンが上がったものは目立たせる。
- Claude Code プラグイン：版が上がったものの `旧版 → 新版`。反映には Claude Code の再起動が要る。
- herdr サーバー：再起動したか。
- OS の再起動：必要なホストがあれば添える。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| Bash ツールから直接 `tailscale ssh <ホスト> '<コマンド>'` を実行する | pane から入る。認証 URL の待ちで Bash ツールの呼び出しがタイムアウトする |
| 認証 URL を放置して待ち続ける | URL を依頼者に伝えて承認を依頼する |
| 一覧にないホストを対象にする | `tag:home-server` と `tag:wsl` の付いたノードだけを対象にする |
| `tag:wsl` のホストに入れないことを失敗扱いにする | 常時起動していないので、飛ばして報告する |
| 素の `ssh` で入る | `tailscale ssh` で入る |
| 手元のホストにも ssh する | 接続せず、pane で直接作業する |
| dot-files を pull する前に `mise up` する | 先に pull し、最新の mise 設定で更新する |
| pull が通ったのでローカル変更はないと考える | pull の後に `git status --short` で確かめる |
| ローカル変更を stash して pull する | 差分を判定し、取り込み済みや JSON の並び順だけなら破棄し、それ以外は PR にする |
| JSON 以外のファイルを行の並べ替えで比べて破棄する | 実際の差分として PR にする |
| mise 本体の新版通知に従って更新する | 報告に添えるだけにする |
| 複数ホストの `mise up` を同時に走らせる | 1 ホストずつ直列にする |
| `claude plugin update` だけ実行する | 先に `claude plugin marketplace update` を実行する |
| `claude plugin update` に `-y` を付ける | 確認を求められたら依頼者に見せ、`--accept-command` で承認する |
| 自分が載っているホストで `herdr server stop` する | そのホストは依頼者に手動での再起動を頼む |
| 同じ終了マーカーを使い回す | コマンドごとに変え、引用符で分断する |
