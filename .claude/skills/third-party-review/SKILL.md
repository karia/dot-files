---
name: third-party-review
description: 自分が書いた PR を、実装のコンテキストを持たない別のエージェント（codex / cursor agent / 自分の subagent）にレビューさせ、指摘へ返信して ready for review まで持っていく手順。draft PR の用意・レビュアーの起動・コンテキストを渡さない依頼の書き方・レビュー完了の検知・修正 commit URL 付きの返信・draft 解除までを扱う。「第三者レビューして」「レビューを回して」「codexにレビューさせて」「別エージェントにPRを見てもらって」「セルフレビューじゃなく客観的に見てほしい」のような依頼で使用する。対象 PR 番号が引数で渡された場合はそれを対象にする。
---

# 第三者レビューの依頼手順

自分が書いた変更を、実装の経緯を知らない別のエージェントにレビューさせるための手順。

同じセッションの延長でレビューさせても第三者レビューにはならない。実装時の前提や「ここはこう決めた」という判断をそのまま引き継ぐため、その判断自体を疑えない。だからレビュアーには別のプロセス（または別の subagent）を使い、渡す情報を PR そのものだけに絞る。

これは個人の作り方であり、会社としての規定ではない。実行前に、対象リポジトリの `CLAUDE.md` に固有ルールがあればそれを優先する。

## (0) draft PR を用意する

- PR がまだなければ `pr-flow` に従って draft PR を作る。作成手順はそちらが権威なので、ここでは重複させない。
- 既に ready for review の PR をレビューさせる場合は、`gh pr ready --undo <PR番号>` で draft へ戻す。レビュー対応中にマージされるのを防ぐため。
- PR 番号と URL を控える。レビュアーへ渡すのはこれだけになる。

## (1) レビュアーの選定と起動

使えるものを次の優先順で選ぶ。

1. `codex`
2. `cursor-agent`
3. 自分の subagent

外部 CLI を優先するのは、別プロセスのほうがコンテキストの分離が確実で、レビュー中も元セッションを使い続けられるため。`command -v` で存在を確認してから選ぶ。

Herdr 管理下（`test "${HERDR_ENV:-}" = 1`）で外部 CLI が使えるなら、別 pane で起動する。CLI の構文は `herdr` skill に従う。`launching-claude-remote-control` は使わない。同 skill は `claude --remote-control` 専用で、trust folder プロンプトの確定や `agent: claude`・`/remote-control is active` を成否判定に使うため、codex や cursor-agent では判定が通らない。

- workspace は `herdr workspace create --no-focus` で作る。依頼者のフォーカスを奪わない。
- pane には `herdr pane rename <pane_id> "review"` でラベルを付ける。後から一覧で識別するため。
- 起動できたかは `herdr pane read <pane_id>` で当該 CLI のプロンプトが出ていることを見る。

Herdr の外にいる場合、または外部 CLI がない場合は自分の subagent を使う。subagent は会話の履歴を引き継がないため、コンテキスト分離の条件は満たせる。

## (2) レビュー依頼（コンテキストを渡さない）

渡してよいのはリポジトリ名と PR 番号（または PR の URL）だけ。

渡してはいけないもの:

- 設計意図、検討して捨てた案、実装で悩んだ点
- 「ここは意図的にこうしている」といった先回りの弁明
- 元セッションの会話ログ、関連する plan や ADR へのポインタ

レビュアーが PR から自力で読み取れない情報は、渡さずに黙っておく。読み取れないこと自体が PR の説明不足であり、レビューで指摘されるべき事項だから。先に補足すると、その欠陥が見えなくなる。

依頼には次の 3 点を必ず含める。

- **a. レビュー用スキルがあれば使う。** Claude なら `/code-review`、codex や cursor agent なら各々のレビュー機能。対象リポジトリ内にレビュー用 skill があればそれを優先する。
- **b. 指摘は GitHub の行コメントで書く。** PR 全体への総括コメント 1 つで済ませない。該当行に紐付けないと、どの記述への指摘か追えず、返信も resolve もスレッド単位で扱えなくなる。
  - 行コメントは diff hunk 内の行にしか付けられず、範囲外を指定すると 422 で失敗する。description の不足や、diff に現れないファイルへの波及など、行に紐付けられない指摘に限り総括コメントに書いてよい。
  - 複数の指摘は 1 つの review にまとめて submit する。指摘ごとに submit すると通知が飛び散るため。REST には既存の pending review へコメントを足すエンドポイントがないので、`gh api` を使うなら create-review（`POST /repos/{owner}/{repo}/pulls/{n}/reviews`）の 1 リクエストに `comments[]` を配列で渡す。GitHub MCP tool が使えるなら `pull_request_review_write` の `create` → `add_comment_to_pending_review` → `submit_pending` の流れでよい。
- **c. 「指摘」と「変更提案」を分け、提案口調で書く。** 事実として問題があるもの（バグ、規約違反、記述の矛盾）が指摘、好みや改善案が変更提案。行頭に `[指摘]` / `[提案]` のようなラベルを付けて区別する。文末は「〜します」ではなく「〜してはいかがでしょうか」「〜を推奨します」にする。レビュアーは背景を持たないまま書いているので、断定されると元セッション側が事情を説明しづらくなる。

依頼プロンプトの例:

```text
karia/dot-files の PR #123 をレビューしてください。
前提や背景は渡しません。PR の diff と description から読み取れる情報だけで判断してください。

- レビュー用のスキル（/code-review など）が使えるなら使ってください
- 指摘は GitHub の行コメントとして該当行に付けてください。総括コメント 1 つにまとめないでください
  （diff の行に紐付けられない指摘だけは、総括コメントに書いて構いません）
- 複数の指摘は 1 つの review にまとめて submit してください
- 「指摘」（バグ・規約違反・記述の矛盾）と「変更提案」（好み・改善案）を分け、
  行頭に [指摘] / [提案] のラベルを付けてください
- 断定形は避け、「〜してはいかがでしょうか」「〜を推奨します」という提案口調で書いてください
```

## (3) レビュー完了の検知

判定の根拠は **PR にレビューが付いたか** に置く。レビュアーが「完了しました」と言っていても、コメントの post に失敗していることがあるため。

```bash
gh pr view <PR番号> --json reviews,comments
gh api repos/<owner>/<repo>/pulls/<PR番号>/comments
```

- subagent に任せた場合は完了通知が届くので、待機の仕掛けはいらない。通知を受けたら上のコマンドで実際にコメントが付いているかを確認する。
- 別 pane に任せた場合は待機が必要になる。pr-flow のマージ監視と同じく `/loop` を間隔指定なし（動的間隔モード）で仕掛け、独自の shell ループは組まない。レビューは数分で終わることが多いので、初回 1 分から倍々にし、上限 15 分で頭打ちにする。プロンプトは毎回同じものが再投入され何回目かは分からないため、待ち時間を毎回発言に残させて次回そこから決めさせる。`Monitor` は使わない。即時 wake すると backoff が効かなくなるため。

  ```text
  /loop PR #<PR番号> に第三者レビューのコメントが付いたか `gh api repos/<owner>/<repo>/pulls/<PR番号>/comments --jq length` で確認する。1 件以上ならループを終了し、third-party-review (4) の対応へ進む。0 件のままなら `herdr pane read <pane_id> --source visible --lines 40` で pane の出力を読み、レビューが失敗・停止していればループを止めて原因を知らせる。まだ実行中なら次の確認まで待つ。待ち時間は前回宣言した値の 2 倍（初回は 1 分、15 分で頭打ち）とし、毎回「次の確認まで N 分待つ」と明記してから待つ。`Monitor` は使わない
  ```

- pane が idle になっていてもコメントが 0 件なら、レビュー自体が失敗している。`herdr pane read` で出力を読み、原因（権限不足、PR が見つからない等）を確認してから仕切り直す。

## (4) 指摘への対応と返信

**すべての指摘に返信する。** 対応する・しないに関わらず、無言で放置しない。

対応する場合:

- 修正を commit する。1 指摘 1 commit を基本にする（細かすぎれば後でまとめればよい）。
- push してから、返信に commit の GitHub URL を含める。`https://github.com/<owner>/<repo>/commit/<sha>` の形。push 前の sha を貼ると 404 になるため、push 後に貼る。
- sha は commit 直後に `git rev-parse HEAD` で控えておき、指摘とセットで記録する。まとめて push した後に `git rev-parse HEAD` を読むと最後の commit しか指さず、どの返信も無関係な commit にリンクすることになる。控え損ねた場合は `git log --oneline <base>..HEAD` から該当 commit を特定する。
- 返信はその指摘の行コメントスレッドに返す。総括コメントで一括返信しない。

  ```bash
  gh api repos/<owner>/<repo>/pulls/<PR番号>/comments/<comment_id>/replies \
    -f body='ご指摘ありがとうございます。修正しました。 https://github.com/<owner>/<repo>/commit/<sha>'
  ```

対応しない場合:

- 理由を書く。「意図的にそうしている」で終わらせない。その意図が PR や本文から読み取れなかったから指摘されたので、必要なら description やコメントに背景を追記し、追記した旨も返信に書く。
- 指摘が誤りだと判断した場合も、どこが事実と違うかを具体的に書く。

返信を終えたスレッドは resolve する。対応せずに閉じた（＝理由を説明して見送った）スレッドも、返信済みなら resolve してよい。

resolve は REST にエンドポイントがなく、GraphQL の `resolveReviewThread` を使う。対象は `PRRT_...` 形式の thread node ID で、comment ID とは別物。

```bash
gh api graphql -f query='
  query($owner:String!, $repo:String!, $pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:50) { nodes { id isResolved comments(first:1) { nodes { body } } } }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F pr=<PR番号>

gh api graphql -f query='
  mutation($id:ID!) { resolveReviewThread(input:{threadId:$id}) { thread { isResolved } } }
  ' -F id=<thread_id>
```

上の query は (5) で「全スレッドが resolve 済みか」を確認するときにも使う（`isResolved` を見る）。

## (5) ready for review 化

次を確認してから draft を外す。

- すべての行コメントスレッドに返信済みで、resolve 済みであること（(4) の GraphQL query の `isResolved` で確認する）。
- 修正 commit が push 済みであること。
- CI があるリポジトリでは CI が通っていること（`gh pr checks <PR番号>`）。check が 1 件も報告されていないリポジトリでは、同コマンドは "no checks reported" を出して非ゼロ終了するため、この確認は不要。

```bash
gh pr ready <PR番号>
```

外したら PR の URL を `open` で開き、返信とスレッドの状態を目視確認する。

`karia/` 配下のリポジトリでは、ここで pr-flow (4) のマージ監視を仕掛ける。pr-flow は draft PR には監視を仕掛けないため、draft で作った PR ならここが監視の開始点になる。

ただし (0) で `gh pr ready --undo` を使って draft へ戻した PR には、pr-flow が作成時に仕掛けた監視が生きている可能性がある。`--undo` はループを止めず、pr-flow のループは state が OPEN の間は待ち続けるため。監視が残っていれば仕掛け直さない。二重に走らせると、マージ後に同じ worktree と branch に対して `merged-branch-cleanup` が 2 回実行される。

## よくある取りこぼし

| 取りこぼし | 正しくは |
|---|---|
| 同じセッションでセルフレビューする | コンテキストを持たない別プロセス・別 subagent に渡す |
| 「この変更の狙いは〜」と背景を添えて依頼する | 渡すのはリポジトリ名と PR 番号だけ |
| 説明が足りない箇所を先回りで補足する | 黙っておく。説明不足なら指摘されるべき事項 |
| ready のまま第三者レビューを回す | draft に戻してから回す（`gh pr ready --undo`） |
| 指摘をすべて PR 全体への総括コメントで受け取る | 原則は該当行の行コメント。diff の行に紐付けられない指摘だけ総括コメントで受け取る |
| 指摘ごとに review を submit して通知を飛ばす | 1 つの review にまとめて submit させる |
| 「指摘」と「変更提案」を混ぜて書かせる | ラベルで分けさせる |
| レビュアーに断定形で書かせる | 提案口調（「〜してはいかがでしょうか」）で書かせる |
| レビュアーの「完了しました」を鵜呑みにする | PR に実際にコメントが付いたかを API で確認する |
| 別 pane の待機に独自 shell ループを組む | `/loop` の動的間隔モードを使う（1 分から倍々、上限 15 分） |
| `/loop` に停止条件を書かず回り続けさせる | コメント検知・レビュー失敗のどちらでも止まるようプロンプトに書く |
| 対応しない指摘を無言で放置する | 理由を書いて返信する |
| 修正した旨だけ返信する | 修正 commit の GitHub URL を添える |
| push 前の sha で commit URL を貼る | push してから貼る（404 になるため） |
| 返信後にスレッドを開いたままにする | resolve する |
| 返信を終えて draft のまま放置する | `gh pr ready` で ready for review にする |
| ready 化後にマージ監視を仕掛け忘れる | `karia/` 配下なら pr-flow (4) の監視をここで開始する |
| draft へ戻した PR に監視を仕掛け直して二重に走らせる | `--undo` は既存の監視を止めない。残っていれば仕掛けない |
| CI のないリポジトリで `gh pr checks` の結果を待つ | check 0 件なら非ゼロ終了する。CI があるリポジトリでのみ確認する |
