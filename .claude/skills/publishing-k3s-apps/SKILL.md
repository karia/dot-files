---
name: publishing-k3s-apps
description: Use when deploying a new app to the local k3s cluster (yuno04) or exposing an app to the internet via Cloudflare Tunnel / side2.net — 新しいアプリをk3sで動かす・インターネット公開する・独自ホスト名を割り当てるとき。keywords: k3s, kubectl, Ingress, Traefik, cloudflared, Cloudflare Tunnel, DNS, terraform, side2.net
---

# k3sアプリのデプロイとインターネット公開

## Overview

yuno04のk3sはCloudflare Tunnel（`yuno-k3s`）で公開済み。Tunnelはcatch-allで全トラフィックを `http://traefik.kube-system:80` に転送し、TraefikがHostヘッダで各アプリのIngressに振り分ける。**アプリ追加時にTunnel設定の変更は不要**。必要なのは「k8sマニフェスト適用」と「DNSレコード追加（Terraform経由）」だけ。

構成一式は private repo [`karia/yuno04-k3s`](https://github.com/karia/yuno04-k3s)（ローカル `~/ghq/github.com/karia/yuno04-k3s`、ghq管理）、DNSは別repo [`karia/side2.net`](https://github.com/karia/side2.net) の `terraform/dns/` で管理。

## 手順

1. マニフェストを `~/ghq/github.com/karia/yuno04-k3s/apps/<アプリ名>/` に作成（下の例を参照）
2. `kubectl apply -R -f ~/ghq/github.com/karia/yuno04-k3s/apps/<アプリ名>/`
3. DNS登録: `karia/side2.net` の `terraform/dns/records.tf` に proxied CNAME を追加 → **PR作成 → レビュー → マージ後にローカルで `terraform apply`**（レコードはこの apply で作成される）
4. 検証: `kubectl rollout status deploy/<アプリ名>` → `curl -s https://<ホスト名>.side2.net` で期待するレスポンスを確認

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
- **Ingress+DNSを作った瞬間に全世界公開**。認証が必要なアプリは公開前にCloudflare Access導入を依頼者と相談する
