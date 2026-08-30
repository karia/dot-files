---
name: launching-claude-remote-control
description: Herdr の新しい workspace を作り、そこで Remote Control を有効にした Claude Code を起動して、trust folder の確認プロンプトまで通す手順。起動前に空きメモリを確認し、新しいセッションで使用率が 75% に達する場合は依頼者へ警告する。「新しいworkspaceでClaudeを起動して」「remote control有効でClaudeを立ち上げて」「別workspaceにClaudeを追加して」のような依頼で使用する。起動先の cwd やラベルが引数で渡された場合はそれを使う。
---

# Herdr の新規 workspace で Remote Control 付き Claude を起動する

Herdr の workspace を新規に作り、その pane で `claude --remote-control` を起動して、初回の trust folder 確認まで通すための手順。

CLI の構文そのものは `herdr` skill が権威なので、コマンド群の詳細はそちらに従う。
このスキルは、その上で起動シーケンス特有の落とし穴（クライアントとサーバのバージョン差、trust プロンプトの確定方法）を扱う。

## (1) 実行前の確認

- Herdr 管理下の pane にいることを確認する。

  ```bash
  test "${HERDR_ENV:-}" = 1
  ```

  失敗したら、Herdr の外にいる旨を伝えて中断する。

- クライアントとサーバのバージョンが一致しているかを確認する。

  ```bash
  herdr status server
  ```

  `compatible: no` と表示された場合、`herdr` の全サブコマンドが `protocol_mismatch` で失敗する。
  mise の `latest` 指定で CLI だけが新しくなり、起動済みのサーバが古いままのときに起きる。

## (2) protocol mismatch への対処

エラーメッセージはサーバの再起動（`herdr server stop`）を促してくる。
しかしサーバを止めると全 pane のプロセスが落ちる。
自分自身がその pane で動いている場合、実行した瞬間に自分のセッションごと消える。

再起動する代わりに、サーバと同じバージョンのクライアントで話しかける。
`herdr status server` の `version` を読み、mise で一時的にそのバージョンを実行する。

```bash
mise x herdr@0.7.4 -- herdr workspace list
```

以降のコマンドもすべて同じ前置きを付けて実行する。
グローバル設定を書き換えないため、副作用は残らない。

サーバ再起動が本当に必要だと判断した場合は、実行前に依頼者へ確認する。
このセッションが落ちること、再接続後に `claude --continue` で再開する必要があることを伝える。

## (3) 空きメモリの確認

Claude のセッションは 1 つで数百 MB を占める。
workspace を作る前に、増える分を含めた物理メモリの使用率が 75% に達しないかを確かめる。

```bash
free -m | awk '/^Mem:/ { print "total="$2, "available="$7 }'
ps -eo rss,comm --sort=-rss | awk '$2 == "claude" { print int($1 / 1024); exit }'
```

使用率は `(total - available) / total` で求める。
`available` は、swap を使わず新しいアプリケーションを起動できる物理メモリの推定値で、再利用可能な page cache も考慮する。
`free` 列は再利用できるキャッシュを空きから外すため、使用率を過大に見せる。
環境や `procps` のバージョンによる `used` 列の定義差を避けるため、`total` と `available` だけを基準にする。

swap の空きは余力に数えない。
物理メモリが尽きて退避が始まった時点で応答が目に見えて遅くなるため、判定は物理メモリだけで行う。

新しいセッションが増やす分は、稼働中の Claude プロセスの RSS 実測値で見積もる。
この skill 自体が Claude のセッションで動くため、測る対象は必ず 1 つ以上ある。
RSS は共有分を各プロセスに二重計上するので、合計ではなく最大の 1 件を 1 セッション分の見積もりとして使う。

`(total - available + 見積もり) / total` が 75% 以上になる場合は、workspace を作らずに依頼者へ警告する。
総容量、現在の使用率、見積もりを足した使用率を示し、続行してよいかを確認する。
続行の指示を得るまで workspace を作らない。
続行しない判断になった場合は、不要なセッションを終了してから測り直す。

### WSL2 の場合

WSL2 の `free` が示すのは WSL2 VM 内のメモリで、Windows ホスト全体の空きメモリではない。
kernel release に `microsoft` が含まれる場合は WSL2 とみなし、VM 内の判定に加えて Windows ホストも確認する。

```bash
if grep -qi microsoft /proc/sys/kernel/osrelease; then
  powershell.exe -NoProfile -NonInteractive -Command '$os = Get-CimInstance Win32_OperatingSystem; $mem = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory; "total={0} available={1}" -f [math]::Floor($os.TotalVisibleMemorySize / 1024), $mem.AvailableMBytes'
fi
```

出力は MiB 単位で、Windows ホストについても `(total - available + 見積もり) / total` を計算する。
VM 内と Windows ホストのどちらか一方でも 75% 以上になる場合は警告する。
`powershell.exe` が使えない、または値を取得できない場合は、ホスト側の空きメモリを確認できなかったことを警告し、続行してよいかを確認する。
ホスト側の確認が失敗しても、そのまま workspace を作ってはならない。

## (4) workspace の作成

```bash
herdr workspace create --label "claude-remote" --no-focus
```

- 依頼者が「切り替えて」と明示していない限り `--no-focus` を付ける。
  依頼者のフォーカスを奪わない。
- 起動先のディレクトリを指定されたら `--cwd PATH` を付ける。
  指定がなければ既定の cwd（通常はホーム）のままにする。
- 応答 JSON の `result.root_pane.pane_id` を読む。
  この pane ID を以降の操作対象にする。
  workspace 番号や表示順から ID を組み立てない。

pane にラベルを付けておくと、後から一覧で識別しやすい。

```bash
herdr pane rename <pane_id> "claude-remote"
```

## (5) Claude の起動

```bash
herdr pane run <pane_id> "claude --remote-control"
```

`--remote-control` は対話セッションを Remote Control 有効で開始する。
セッション名を付けたい場合は `claude --remote-control <name>` と書く。

## (6) trust folder プロンプトの確定

未信頼のディレクトリで起動すると、確認プロンプトが出る。

```
❯ 1. Yes, I trust this folder
  2. No, exit
```

出力を読んでプロンプトの有無を確認する。

```bash
herdr pane read <pane_id> --source visible --lines 40
```

プロンプトが出ていれば、選択肢 1 が既に選択された状態なので Enter だけを送る。

```bash
herdr pane send-keys <pane_id> Enter
```

ここで `pane run` を使わない。
`pane run` はテキストと Enter をまとめて送るため、選択済みのリストに余計な入力が入る。

ホームディレクトリで起動した場合、Yes を選んでも確認結果は永続化されない。
`~/.claude.json` の該当ディレクトリが `hasTrustDialogAccepted: false` のまま `projectOnboardingSeenCount` だけ増えていく。
起動のたびにプロンプトが出るので、2回目以降も同じ手順で通す。

## (7) 起動の確認

```bash
herdr pane get <pane_id>
herdr pane read <pane_id> --source visible --lines 45
```

- `pane get` の `agent`：`claude` になっていること。
- `pane get` の `agent_session.value`：セッション ID が入っていること。
  trust プロンプトで止まっている pane も `agent: claude` かつ `agent_status: idle` を返すため、
  `agent_status` では起動の成否を判別できない。止まっている間は `agent_session.value` が `null`。
- `pane get` の `terminal_title_stripped`：`null` でなくなっていること。
  新規起動なら `Claude Code`、`--resume` ならセッションのタイトルが入る。
- `pane read` の出力：`/remote-control is active` の行と `https://claude.ai/code/session_...` の URL が出ていること。

この URL を依頼者に伝える。
スマートフォンやブラウザから同じセッションを操作するための入り口になる。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| protocol mismatch のメッセージに従ってサーバを再起動する | 自分のセッションごと落ちる。`mise x herdr@<サーバ版> --` でバージョンを合わせる |
| 空きメモリを確かめずに workspace を作る | 作る前に使用率を測り、新しいセッションの見積もりを足して 75% に達するなら警告する |
| `free` 列や swap の空きを余力として数える | `available` 列だけを基準に判定する |
| WSL2 で `free` だけを見て Windows ホストにも余裕があると判断する | VM 内と Windows ホストの両方を確認する |
| 警告を出したうえで workspace 作成に進む | 続行の指示を得るまで作らない |
| `--focus`（既定）で workspace を作る | 依頼者のフォーカスを奪う。`--no-focus` を付ける |
| pane ID を workspace 番号から推測する | 作成応答の `result.root_pane.pane_id` を読む |
| trust プロンプトに `pane run` で "1" を送る | 選択肢 1 は選択済み。`send-keys Enter` だけ送る |
| プロンプトの有無を確認せずキーを送る | 先に `pane read` で画面を読む |
| `agent_status: idle` を見て起動成功と判断する | プロンプトで止まっていても `idle` を返す。`agent_session.value` で確認する |
| 前回 Yes を選んだので今回は出ないと考える | ホームディレクトリでは永続化されない。2回目以降も確認する |
| 起動コマンドを打った時点で完了とする | `agent_session.value` がセッション ID になったことを確認し、Remote Control の URL を伝える |
