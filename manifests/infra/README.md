# Infrastructure Manifests

`manifests/infra/` には、GitHub Actions から `kubectl apply` する公開可能な Kubernetes manifest を置きます。

含めてよいもの:

- Namespace、RBAC、Deployment、Service などの公開可能な定義
- そのまま GitHub Actions で再適用してよい基盤コンポーネント

含めないもの:

- Secret の実体
- 実運用の `kubeconfig`
- 実 IP、実 FQDN、認証情報を含むファイル

このディレクトリに `*.yaml`、`*.yml`、`*.json` がまだ無い場合、CI の apply step は自動的にスキップされます。

Calico を置く場合は、`manifests/infra/calico/` 配下を先に ordered apply し、その後で残りの `manifests/infra/` を適用します。
