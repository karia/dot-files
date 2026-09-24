---
name: home-server-update
description: 自宅の Linux サーバー群を最新化する定例手順。各ホストへ Herdr の pane から ssh し、dot-files の git pull、mise 本体と mise 管理ツールの更新（mise up）、Claude Code のマーケットプレイスとプラグインの更新までを行う。Tailscale SSH の認証 URL が出たら依頼者に承認を依頼する。「ホームサーバーを最新化して」「自宅サーバーの mise up して」「yuno04 のツールを更新して」「home-server-update」のような依頼で使用する。対象ホストが引数で渡された場合はそのホストだけを対象にする。
---

# ホームサーバー最新化手順

自宅の Linux サーバー群で、dot-files・mise 管理ツール・Claude Code プラグインをまとめて最新化する。各ホストへは Herdr の pane から ssh し、pane 上でコマンドを実行する。pane の操作方法は `herdr` skill に従う。

## 対象ホスト

Tailscale でタグ `tag:home-server` を付けたノードが対象になる。以下で対象ホストの名前とオンライン状態を列挙する。

```bash
tailscale status --json | jq -r '(.Self, .Peer[]) | select((.Tags // []) | index("tag:home-server")) | [(.DNSName | split(".")[0]), .Online] | @tsv'
```

- ssh 先には 1 列目の名前を使う。`HostName` は OS 上のホスト名で、Tailscale 上の名前と異なることがある。
- 1 件も出ないときは、タグが付いていない。依頼者に伝えて止まる。

名前が `-wsl` で終わるホストは WSL で、Windows の電源が切れていて常時起動していない。オフラインのとき、または ssh がタイムアウトしたときは、そのホストを飛ばして報告に書く。それ以外のホストがオフラインなら、異常として報告する。

## (1) ssh 接続

1. ホストごとに pane を作り、`ssh -o ConnectTimeout=10 <ホスト>` を実行する。今いるホストが対象でも、同じく ssh で入る。
2. `# To authenticate, visit: https://login.tailscale.com/a/...` と出たら、URL を依頼者に伝えて承認を依頼する。承認されるとそのままログインが進むので、プロンプトが出るまで `herdr pane wait-output` で待つ。
3. ログイン後に `hostname` を実行し、意図したホストに入れたか確かめる。

pane でコマンドの完了を待つときは、コマンドの末尾で終了マーカーを出し、`herdr pane wait-output --match` で待つ。マーカーは `echo __DO""NE__` のように引用符で分断する。そのまま書くと、入力したコマンド行の表示にマッチしてすぐ返ってしまう。

## (2) dot-files の更新

`~/ghq/github.com/karia/dot-files` で `git pull --ff-only` する。mise の設定（`~/.config/mise/config.toml`）は dot-files へのシンボリックリンクなので、先に pull して最新の設定で (3) を実行する。

- default branch にいるかを `git branch --show-current` で確かめる。いなければ切り替えず、報告に書いて pull を飛ばす。
- 未コミット変更で pull が止まったら、stash や破棄はせず、ファイル名を報告に書いて先へ進む。

## (3) mise の更新

1. `mise self-update -y` で mise 本体を更新する。
   - APT で入れたホストでは `sudo apt update && sudo apt install --only-upgrade mise` を促すメッセージが出て、更新されない。sudo にはパスワードが要るので実行せず、そのコマンドを報告に書く。
2. ホームディレクトリで `mise up 2>&1 | tail -40` を実行する。

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
- dot-files：pull の結果。未コミット変更で止まった場合はファイル名。
- mise 本体：更新前後の版。APT のため未更新なら、実行すべきコマンド。
- mise up：更新したツールの `旧版 → 新版`。メジャーバージョンが上がったものは目立たせる。
- Claude Code プラグイン：版が上がったものの `旧版 → 新版`。反映には Claude Code の再起動が要る。
- herdr サーバー：再起動したか。
- ログイン時に `*** System restart required ***` が出ていれば、そのことを添える。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| Bash ツールから直接 `ssh <ホスト> '<コマンド>'` を実行する | pane から ssh する。認証 URL の待ちで Bash ツールの呼び出しがタイムアウトする |
| 認証 URL を放置して待ち続ける | URL を依頼者に伝えて承認を依頼する |
| 対象ホストを決め打ちする | `tag:home-server` の付いたノードを `tailscale status --json` から拾う |
| `-wsl` のホストに入れないことを失敗扱いにする | 常時起動していないので、飛ばして報告する |
| dot-files を pull する前に `mise up` する | 先に pull し、最新の mise 設定で更新する |
| 未コミット変更を stash して pull する | 触らずに報告する |
| APT で入れた mise を sudo で更新しようとする | コマンドを報告し、依頼者に任せる |
| 複数ホストの `mise up` を同時に走らせる | 1 ホストずつ直列にする |
| `claude plugin update` だけ実行する | 先に `claude plugin marketplace update` を実行する |
| 自分が載っているホストで `herdr server stop` する | そのホストは依頼者に手動での再起動を頼む |
| 終了マーカーをそのまま書いて `wait-output` で待つ | 引用符で分断し、コマンド行の表示にマッチさせない |
