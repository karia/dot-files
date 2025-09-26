# CLAUDE.md

## Conversation Guidelines

* 常に日本語で会話すること

## Development Guidelines

git commitするとき以下に注意すること

* 変更内容が混在している場合は、git add -pで必要な部分のみをステージングし、テーマごとにcommitを分けること
* ステージング後にgit diff --cachedで確認し、本来の作業と無関係な変更が含まれていたら、commit前に依頼者に確認すること
* commitメッセージは1行しか表示されないため、説明は1行に収めること（Co-Authored-By: など追加要素は2行目以降で良い）
* commitメッセージは見やすさの観点から英語で統一すること
* commitはなるべく細かい単位で実施すること（細かすぎる場合はあとでまとめるので、気にせず細かくしてよい）
* commit時にpre-commitの警告をskipする場合、skipしてよいかを理由込みで依頼者に確認すること（確認が必要だからpre-commitを設定しているので、通常skipすべきではない）

IssueやPRを作成するとき以下に注意すること

* descriptionの記述量をミニマムに保つこと。多すぎると読んでくれません。特にコードを読めばわかることは記述しない。
* tsumikiinc organizationに対するPR/Issueの場合に限り、レビュアーが日本人のため、title,descriptionの項目を日本語で記述すること
* Issue/PRを作成完了したら、内容を確認するためopenコマンドを使ってURLを開くこと
