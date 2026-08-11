---
name: publishing-k3s-apps
description: >-
  Use when deploying or updating an app on the local k3s cluster (yuno04),
  running release migrations, or exposing an app through Cloudflare Tunnel /
  side2.net. 新規アプリの公開、既存アプリのイメージ更新、マイグレーション、
  独自ホスト名の割り当てを行うときに使用する。Triggers include k3s, kubectl,
  deploy, migration, rollout, Ingress, Traefik, cloudflared, Cloudflare Tunnel,
  DNS, terraform, and side2.net.
---

# k3sアプリのデプロイとインターネット公開

## Overview

yuno04のk3sはCloudflare Tunnel（`yuno-k3s`）で公開済み。Tunnelはcatch-allで全トラフィックを `http://traefik.kube-system:80` に転送し、TraefikがHostヘッダで各アプリのIngressに振り分ける。**アプリ追加時にTunnel設定の変更は不要**。必要なのは「k8sマニフェスト適用」と「DNSレコード追加（Terraform経由）」だけ。

構成一式は private repo [`karia/yuno04-k3s`](https://github.com/karia/yuno04-k3s)（ローカル `~/ghq/github.com/karia/yuno04-k3s`、ghq管理）、DNSは別repo [`karia/side2.net`](https://github.com/karia/side2.net) の `terraform/dns/` で管理。

## 変更管理

`karia/yuno04-k3s`と`karia/side2.net`の変更は、規模を問わずdefault branchへ直接pushしない。
各repoの元ディレクトリを最新のdefault branchに保ち、`pr-flow`に従って横並びのworktreeでbranchを作り、commit・push・PR作成を行う。
クラスタへ先に適用した場合も、稼働状態とgit管理のマニフェストを一致させるPRを必ず作成する。

## 新規アプリの手順

1. マニフェストを `~/ghq/github.com/karia/yuno04-k3s/apps/<アプリ名>/` に作成（下の例を参照）
2. yuno04-k3sのPRを作成する
3. `kubectl apply -R -f ~/ghq/github.com/karia/yuno04-k3s/apps/<アプリ名>/`
4. DNS登録: `karia/side2.net` の `terraform/dns/records.tf` に proxied CNAME を追加 → **PR作成 → レビュー → マージ後にローカルで `terraform apply`**（レコードはこの apply で作成される）
5. 検証: `kubectl rollout status deploy/<アプリ名>` → `curl -s https://<ホスト名>.side2.net` で期待するレスポンスを確認

## 既存アプリのイメージ更新

最初にアプリrepo固有の`CLAUDE.md`と、`yuno04-k3s/apps/<アプリ名>/README.md`を読む。
マイグレーションがアプリ起動から分離されている場合は、次の順序を崩さない。

1. default branchの対象commitに対するイメージビルドが成功していることを確認する
2. 完全なcommit SHAのtagからdigestを取得する
   ```bash
   mise x crane@0.21.9 -- crane digest ghcr.io/<owner>/<image>:sha-<full-commit-sha>
   ```
3. 専用worktreeで、Deploymentとmigration Jobの**両方**を同じ`tag@digest`へ更新する
4. yuno04-k3sのPRを作成する。先にクラスタへ適用する場合でもdefault branchへ直接pushしない
5. `generateName`を持つmigration Jobを`kubectl create -f`で作成する。`apply`は使わない
6. Jobの`Complete`を待ち、ログで実行対象のmigrationが成功したことを確認する
7. Job完走後にDeploymentをapplyし、rollout完了を待つ
8. Podのready数、実際のイメージ、外部health endpointを確認する

```bash
job=$(kubectl create -f apps/<アプリ名>/migrate-job.yaml -o name)
kubectl -n <namespace> wait --for=condition=complete "$job" --timeout=180s
kubectl -n <namespace> logs "$job"

kubectl apply -f apps/<アプリ名>/deployment.yaml
kubectl -n <namespace> rollout status deploy/<アプリ名> --timeout=180s
kubectl -n <namespace> get deploy/<アプリ名> \
  -o jsonpath='{.status.readyReplicas}/{.status.replicas}{" ready, image="}{.spec.template.spec.containers[0].image}{"\n"}'
curl --fail --silent --show-error -o /dev/null -w '%{http_code}\n' https://<ホスト名>/up
```

rollout完了直後は、経路の切り替え中に外部health checkが一度だけ502になることがある。
即座に失敗と判断せず、PodがReadyか、ServiceのEndpointが新Podを指すか、アプリログ内のhealth checkが200かを確認してから外部確認を再実行する。
502が継続する場合はIngress・Service・Endpoint・アプリログを調査する。

## DNSレコード（terraform/dns/records.tf に追記する形）

既存の `yuno04.side2.net` / `grafana.side2.net` が雛形。content の tunnel ID部分は、`records.tf` 内の既存レコードから同じ値を引用するか、`cloudflared tunnel list` または Cloudflare API（`~/.config/cloudflare/token` を使用）で取得すること:

```hcl
resource "cloudflare_dns_record" "myapp_yuno04_tunnel" {
  comment = "k3s tunnel (myapp)"
  content = "<TUNNEL_ID>.cfargotunnel.com"
  name    = "myapp.side2.net"
  proxied = true
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = var.zone_id
  settings = {
    flatten_cname = false
  }
}
```

## マニフェスト例（最小構成: Deployment + Service + Ingress）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: myapp, namespace: default}
spec:
  replicas: 1
  selector: {matchLabels: {app: myapp}}
  template:
    metadata: {labels: {app: myapp}}
    spec:
      containers:
        - name: myapp
          image: myimage:tag
          ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata: {name: myapp, namespace: default}
spec:
  selector: {app: myapp}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: myapp, namespace: default}
spec:
  ingressClassName: traefik
  rules:
    - host: myapp.side2.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend: {service: {name: myapp, port: {number: 80}}}
```

実例: `~/ghq/github.com/karia/yuno04-k3s/apps/nginx/`（稼働中の `yuno04.side2.net`）

## Quick Reference

| 項目 | 値 |
|---|---|
| DNS管理 | `karia/side2.net` の `terraform/dns/records.tf` に追記 → PR → `terraform apply` |
| Tunnel ID（CNAME content） | `records.tf` の既存レコードから引用、または `cloudflared tunnel list` / Cloudflare APIで取得 |
| Cloudflare APIトークン / ID類 | `~/.config/cloudflare/token`, `~/.config/cloudflare/config` |
| cloudflared本体 | namespace `cloudflared`（`~/ghq/github.com/karia/yuno04-k3s/cloudflared/`） |
| Tunnel設定 | catch-all固定。触らない |

## Common Mistakes

- **2階層サブドメイン（`x.yuno.side2.net`）は使わない** — Universal SSLの対象外で証明書エラーになる。ACM（$10/月）未契約のため1階層のみ
- IngressのhostとDNSレコード名の不一致 → Traefikが404を返す。完全一致させる
- `ingressClassName: traefik` の指定漏れ（defaultだが明示する）
- **DNSはTerraform管理**。ダッシュボードやAPIで直接レコードを作らない（state と乖離する）。必ず records.tf を編集して PR → apply
- **yuno04-k3sのdefault branchへ直接pushしない**。デプロイ済みでもマニフェスト更新はworktreeからPRにする
- migration Jobだけ、またはDeploymentだけを新digestにしない。古いコードでmigrationを実行したり、新しいコードが古いschemaへ接続したりする
- Deploymentを先に更新しない。migration Jobの完走を確認してからrolloutする
- rollout直後の単発502だけでrollbackしない。readiness、Endpoint、ログを確認して再試行する
- **Ingress+DNSを作った瞬間に全世界公開**。認証が必要なアプリは公開前にCloudflare Access導入を依頼者と相談する
