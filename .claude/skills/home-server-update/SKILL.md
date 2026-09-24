---
name: home-server-update
description: 自宅の Linux サーバー群を最新化する定例手順。各ホストへ Herdr の pane から ssh し、dot-files の git pull とローカル変更の PR 化、mise 管理ツールの更新（mise up）、Claude Code のマーケットプレイスとプラグインの更新までを行う。Tailscale SSH の認証 URL が出たら依頼者に承認を依頼する。「ホームサーバーを最新化して」「自宅サーバーの mise up して」「yuno04 のツールを更新して」「home-server-update」のような依頼で使用する。対象ホストが引数で渡された場合はそのホストだけを対象にする。
---

# ホームサーバー最新化手順

自宅の Linux サーバー群で、dot-files・mise 管理ツール・Claude Code プラグインをまとめて最新化する。各ホストへは Herdr の pane から Tailscale SSH で入り、pane 上でコマンドを実行する。pane の操作方法は `herdr` skill に従う。

## 対象ホスト

Tailscale でタグ `tag:home-server` または `tag:wsl` を付けたノードが対象になる。以下で名前・タグ・オンライン状態・作業中のホストかどうかを列挙する。

```bash
tailscale status --json | jq -r '(.Self | .me = true), (.Peer[] | .me = false) | select((.Tags // []) | index("tag:home-server") or index("tag:wsl")) | [(.DNSName | split(".")[0]), (.Tags | join(",")), .Online, .me] | @tsv'
```

- 接続先には 1 列目の名前を使う。`HostName` は OS 上のホスト名で、Tailscale 上の名前と異なることがある。
- 1 件も出ないときは、タグが付いていない。依頼者に伝えて止まる。

| タグ | オフラインのとき |
|---|---|
| `tag:home-server` | 常時起動のはずなので、異常として報告する |
| `tag:wsl` | 常時起動していないので、飛ばして報告に書く |

## (1) 接続

1. ホストごとに pane を作る。
2. 4 列目が `true` のホストは、この手順を実行している手元のホストなので、接続せずにその pane で直接作業する。
3. それ以外のホストでは `tailscale ssh <ホスト>` を実行する。素の `ssh` は、初めて接続するホストでホスト鍵の確認に止まる。`tailscale ssh` は tailnet から取得した鍵で検証するので止まらない。
4. `# To authenticate, visit: https://login.tailscale.com/a/...` と出たら、URL を依頼者に伝えて承認を依頼する。承認されるとそのままログインが進むので、プロンプトが出るまで `herdr pane wait-output` で待つ。
5. ログイン後に `hostname` を実行し、意図したホストに入れたか確かめる。

`tailnet policy does not permit you to SSH to this node` で断られたときは、Tailscale の ACL に、そのタグを宛先とする SSH ルールが足りない。依頼者に伝え、そのホストは飛ばす。

pane でコマンドの完了を待つときは、コマンドの末尾で終了マーカーを出し、`herdr pane wait-output --match` で待つ。マーカーは `echo __DO""NE__` のように引用符で分断する。そのまま書くと、入力したコマンド行の表示にマッチしてすぐ返ってしまう。

## (2) dot-files の更新

`~/ghq/github.com/karia/dot-files` で `git pull --ff-only` する。mise の設定（`~/.config/mise/config.toml`）は dot-files へのシンボリックリンクなので、先に pull して最新の設定で (3) を実行する。

- default branch にいるかを `git branch --show-current` で確かめる。いなければ切り替えず、報告に書いて pull を飛ばす。
- 追跡対象ファイルの変更で pull が止まったら、次の「ローカル変更の扱い」に従う。未追跡ファイルは pull を妨げないので触らない。

### ローカル変更の扱い

`git status --short` で変更されたファイルを挙げ、ファイルごとに差分の中身で扱いを決める。stash はしない。

#### 扱いの判定

| 差分の中身 | 扱い |
|---|---|
| origin の default branch と同じ | 取り込み済みの変更なので、`git checkout -- <ファイル>` で破棄する |
| 並び順だけが違う | 意味のない差分なので、`git checkout -- <ファイル>` で破棄する |
| 実際の差分がある | PR にする |

- origin と同じかは、`git fetch` の後に `git diff --quiet origin/<default branch> -- <ファイル>` の終了コードが 0 かで確かめる。
- 並び順だけかは、両方を並べ替えてから比べる。ツールが設定ファイルを書き戻すときに、キーの順序を入れ替えることがある。
  - JSON は `diff <(git show HEAD:<ファイル> | jq -S .) <(jq -S . <ファイル>)` の出力が空かで確かめる。
  - それ以外の形式は `diff <(git show HEAD:<ファイル> | sort) <(sort <ファイル>)` の出力が空かで確かめる。

破棄したファイルだけで止まっていたなら、もう一度 `git pull --ff-only` する。

#### 実際の差分を PR にする

1. `git diff -- <ファイル>` で差分を読む。並び替えが混ざっていれば、HEAD の並び順に戻し、実際の差分だけを残す。
2. 手元の dot-files で、`pr-flow` skill に従って PR を作る。別ホストの差分は pane で読み取り、手元の worktree に反映する。同じ差分が複数のホストにあれば、1 つの PR にまとめる。
3. そのホストのローカル変更は残したまま、今回の pull は飛ばして先へ進む。PR がマージされれば、次回の実行で「origin の default branch と同じ」に当たって破棄される。

## (3) mise の更新

ホームディレクトリで `mise up 2>&1 | tail -40` を実行する。

mise 本体は更新しない。APT で入れたホストでは `mise self-update` が使えず、`sudo apt upgrade` を実行する権限もない。

`mise up` はホストをまたいで同時に走らせず、1 ホストずつ直列にする。どのホストも同じ自宅回線から取得するため、同時に走らせると配布元の rate limit に当たりうる。

`minimum_release_age`（dot-files の mise 設定で 1h）により、公開から 1 時間以内の版は見送られる。このとき出る WARN は正常な動作なので、報告に添えるだけでよい。

## (4) Claude Code プラグインの更新

マーケットプレイスの取得とプラグインの更新は別のコマンドなので、この順で両方実行する。マーケットプレイスを更新しないと、キャッシュが古いまま「最新版です」と判定される。

```bash
claude plugin marketplace update
claude plugin list --json | jq -r '.[] | "\(.id)\t\(.scope)"' | while IFS=$'\t' read -r id scope; do
  echo "--- $id ($scope)"
  claude plugin update "$id" --scope "$scope" -y 2>&1 | tail -3
done
```

- `claude plugin update` はプラグインを 1 つずつ受け取る。`--scope` の既定は `user` なので、`list --json` の値を渡して他の scope を取りこぼさない。
- マーケットプレイスから消えたプラグインは `Failed to update ... not found` になる。失敗扱いにせず、報告して `claude plugin uninstall` するかを依頼者に確かめる。

## (5) herdr サーバーの再起動

`mise up` で herdr の版が上がったホストでは、動いているサーバーが旧版のままなので、クライアントとの版の不一致が出る。依頼者の了承を得てから再起動する。

```bash
herdr server stop
setsid -f herdr server >/dev/null 2>&1 </dev/null
```

- `herdr server stop` は、そのホストの Herdr で動いている pane のプロセスをすべて止める。この手順を実行しているセッション自身が載っているホストでは実行せず、依頼者に手動での再起動を頼む。
- `setsid -f` で切り離して起動すると、ssh が切れてもサーバーは止まらない。起動後に `herdr --version` と `herdr workspace list` で、新しい版で応答することを確かめる。

## (6) 結果の報告

ホストごとに以下をまとめる。

- 接続：接続できたか。飛ばしたホストはその理由。
- dot-files：pull の結果。破棄したファイルと、その理由。作った PR の URL。
- mise up：更新したツールの `旧版 → 新版`。メジャーバージョンが上がったものは目立たせる。
- Claude Code プラグイン：版が上がったものの `旧版 → 新版`。反映には Claude Code の再起動が要る。
- herdr サーバー：再起動したか。
- ログイン時に `*** System restart required ***` が出ていれば、そのことを添える。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| Bash ツールから直接 `tailscale ssh <ホスト> '<コマンド>'` を実行する | pane から入る。認証 URL の待ちで Bash ツールの呼び出しがタイムアウトする |
| 認証 URL を放置して待ち続ける | URL を依頼者に伝えて承認を依頼する |
| 対象ホストを決め打ちする | `tag:home-server` と `tag:wsl` の付いたノードを `tailscale status --json` から拾う |
| `tag:wsl` のホストに入れないことを失敗扱いにする | 常時起動していないので、飛ばして報告する |
| 素の `ssh` で入る | `tailscale ssh` で入る。素の `ssh` はホスト鍵の確認で止まり、手元のホスト名はループバックに解決されることがある |
| 手元のホストにも ssh する | 接続せず、pane で直接作業する |
| dot-files を pull する前に `mise up` する | 先に pull し、最新の mise 設定で更新する |
| ローカル変更を stash して pull する | 差分を判定し、取り込み済みや並び順だけなら破棄し、実際の差分なら PR にする |
| `mise self-update` や `sudo apt upgrade` で mise 本体を更新する | 実行しない。`mise up` だけにする |
| 複数ホストの `mise up` を同時に走らせる | 1 ホストずつ直列にする |
| `claude plugin update` だけ実行する | 先に `claude plugin marketplace update` を実行する |
| 自分が載っているホストで `herdr server stop` する | そのホストは依頼者に手動での再起動を頼む |
| 終了マーカーをそのまま書いて `wait-output` で待つ | 引用符で分断し、コマンド行の表示にマッチさせない |
