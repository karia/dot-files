# CLAUDE.md

## Conversation Guidelines

* 常に日本語で会話すること

## Development Guidelines

git commitするとき以下に注意すること

* git addを実行するときは、本題と関係ない差分が含まれないようにすること（行指定でのaddを活用する）
* git diffコマンドでステージされた変更を確認したとき、作業内容と無関係の差分が含まれていたときは、commit前に依頼者に確認すること
* コミットメッセージは1行しか表示されないため、説明は1行に収めること（Co-Authored-By: など追加要素は2行目以降で良い）
* コミットメッセージは見やすさの観点から英語で統一すること

IssueやPRを作成するとき以下に注意すること

* descriptionの記述量をミニマムに保つこと。多すぎると読んでくれません。特にコードを読めばわかることは記述しない。
* tsumikiinc organizationに対するPR/Issueの場合に限り、レビュアーが日本人のため、descriptionの項目を日本語で記述すること
* Issue/PRを作成完了したら、内容を確認するためopenコマンドを使ってURLを開くこと
