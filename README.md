# mistship

TalOS ベースのインフラを管理するためのリポジトリです。

このリポジトリは Public repository として運用します。そのため、平文の IP アドレス、FQDN、秘密鍵、TalOS 設定に含まれる機微情報、クラスタ参加トークン、Kubeconfig、Tailscale の認証情報などは Git に含めません。
一方で、cluster input は SOPS で暗号化した上で Git に含めます。

## 基本方針

- Git には「再現可能な定義」と「手順」だけを置く
- 平文の環境固有値や秘匿情報は Git の外で管理する
- そのまま適用すると本番情報が見えるファイルはコミットしない
- コミットしてよいのは、テンプレート、サンプル、生成手順、公開可能な設定、SOPS で暗号化した cluster input のみ

## このリポジトリで管理するもの

- TalOS Image Factory 向けの公開可能なイメージ定義
- TalOS / Kubernetes の構成テンプレート
- TalOS machine config に適用する公開可能な patch
- 構築・更新・復旧の手順書
- 必要なコマンド例とファイル配置ルール

現時点では [`image.yml`](/home/azuki/work/mistship/image.yml) に TalOS イメージ拡張の定義を置いています。これは公開可能な情報のみで構成します。

control plane の初期起動手順は [`docs/bootstrap.md`](/home/azuki/work/mistship/docs/bootstrap.md) にまとめます。

既存 single-node クラスタを `Flannel + kube-proxy` から再構築で移行する手順は [`docs/networking-migration.md`](/home/azuki/work/mistship/docs/networking-migration.md) にまとめます。
クラスタのネットワーク構成方針は [`docs/networking-stack.md`](/home/azuki/work/mistship/docs/networking-stack.md) にまとめます。
Calico eBPF の Service dataplane を観測するデモ手順は [`manifests/infra/ebpf-demo/README.md`](/home/azuki/work/mistship/manifests/infra/ebpf-demo/README.md) にまとめます。

machine config のうち公開可能な設定は [`patches/common.yaml`](/home/azuki/work/mistship/patches/common.yaml)、[`patches/controlplane.yaml`](/home/azuki/work/mistship/patches/controlplane.yaml)、[`patches/worker.yaml`](/home/azuki/work/mistship/patches/worker.yaml) で管理します。

Kubernetes の基盤 manifest は [`manifests/infra/`](/home/azuki/work/mistship/manifests/infra/README.md) で管理します。

Calico の staged apply は [`scripts/apply-calico.sh`](/home/azuki/work/mistship/scripts/apply-calico.sh) で共通化します。

SOPS を使った secret の扱いは [`docs/secrets.md`](/home/azuki/work/mistship/docs/secrets.md) にまとめます。

## Nix 開発環境

TalOS を操作する CLI は [`flake.nix`](/home/azuki/work/mistship/flake.nix) の `devShell` でまとめて提供します。

```bash
nix develop
```

このシェルには次のコマンドを入れます。

- `talosctl`
- `talhelper`
- `kubectl`
- `jq`
- `yq`
- `sops`
- `age`

シェル起動時に次の環境変数を既定で設定します。

- `MISTSHIP_SECRETS_DIR=${MISTSHIP_SECRETS_DIR:-<repo-root>/.secret}`
- `TALOSCONFIG=${TALOSCONFIG:-$MISTSHIP_SECRETS_DIR/talosconfig}`
- `KUBECONFIG=${KUBECONFIG:-$MISTSHIP_SECRETS_DIR/kubeconfig}`

想定しているローカル配置例:

```text
.secret/
├── .gitkeep
├── talosconfig
├── kubeconfig
└── nodes/
    └── controlplane.yaml
```

動作確認例:

```bash
nix develop --command talosctl version --client
nix develop --command talhelper --help
```

`flake.lock` はコミットして、チーム内で同じ `nixpkgs` リビジョンを使う前提にします。更新したい時だけ `nix flake update` を実行します。

## GitHub Actions での TalOS 更新

[`talos-update.yml`](/home/azuki/work/mistship/.github/workflows/talos-update.yml) は、`master` への push 時に TalOS 関連ファイルまたは [`manifests/infra/`](/home/azuki/work/mistship/manifests/infra/README.md) 配下が変わった場合と、GitHub Actions UI からの手動実行時に control plane の machine config を更新します。

この workflow は repository 内の SOPS 暗号化ファイルを復号して CI 内で使います。

- `secrets/mistship/cluster-inputs.sops.env`
- `secrets/mistship/cluster-secrets.sops.yaml`

必要な GitHub Actions secrets:

- `SOPS_AGE_KEY`

CI では `SOPS_AGE_KEY` で cluster input を `.secret/` へ復号してから、`talosconfig` と machine config を再生成し、`talosctl apply-config` で既存クラスタへ反映します。TalOS API の復帰確認後に `kubeconfig` を再生成し、Calico を ordered apply してから [`manifests/infra/`](/home/azuki/work/mistship/manifests/infra/README.md) 配下の manifest を `kubectl apply` します。更新対象は現時点では control plane と基盤 manifest です。

cluster 接続準備のうち、`.secret` の作成、SOPS 暗号化ファイルの復号、`cluster-inputs.env` の読み込み、`talosconfig` の生成は [`cluster-access`](/home/azuki/work/mistship/.github/actions/cluster-access/action.yml) Composite Action に切り出して共通化しています。

PR 向けの [`talos-preflight.yml`](/home/azuki/work/mistship/.github/workflows/talos-preflight.yml) は secret を復号しません。SOPS 復号は `Development` environment に保護された trusted context の [`talos-update.yml`](/home/azuki/work/mistship/.github/workflows/talos-update.yml) だけで行います。

この workflow は GitHub Actions の `Development` environment を使う前提です。environment secrets や protection rules を使いたい場合は、この名前で GitHub 側に設定してください。

workflow では secret の内容をログへ出さず、`.secret` を artifact 化せず、job 終了時に `.secret` を削除します。

## Git に含めないもの

以下は公開リポジトリに含めません。

- グローバル IP、プライベート IP、VIP、ノード一覧
- 実運用のホスト名、DNS 名、ドメイン名
- `talosconfig`
- `kubeconfig`
- 秘密鍵、証明書、CSR、age key、Tailscale auth key
- TalOS machine config のうち機微情報を含む実体ファイル
- bootstrap token、join token、API token、クラウド認証情報
- 実運用環境を特定できる inventory や配布物

補足:
IP アドレスは一般的な意味での秘密情報ではない場合もありますが、このリポジトリでは「公開しない運用情報」として扱います。

## Git に含めてよいもの

- 伏せ字またはダミー値に置き換えたサンプル
- `.example` や `.template` 形式のテンプレート
- `image.yml` のような公開可能な定義
- `*.sops.yaml` や `*.sops.env` のような暗号化済み cluster input
- 手順書、設計メモ、運用ルール
- 実値を含まないスクリプトや生成コマンド

## 推奨運用

平文の環境固有値は次のいずれかで管理します。

- ローカル専用ファイル
- パスワードマネージャや Secret Manager
- CI/CD の Secret Store

このリポジトリには、実値そのものではなく以下を置きます。

- `*.example`
- `*.template`
- `secrets/**/*.sops.env`
- `secrets/**/*.sops.yaml`
- `patches/*.yaml`
- 生成に必要な説明
- 必須パラメータ一覧

## 推奨ファイル設計

例:

```text
.
├── README.md
├── image.yml
├── secrets/
│   └── mistship/
│       ├── cluster-inputs.sops.env
│       └── cluster-secrets.sops.yaml
├── docs/
│   ├── bootstrap.md
│   ├── operations.md
│   └── secrets.md
├── manifests/
│   └── infra/
├── patches/
│   ├── common.yaml
│   ├── controlplane.yaml
│   └── worker.yaml
├── templates/
│   ├── controlplane.yaml.example
│   └── worker.yaml.example
└── .gitignore
```

ローカルまたは別管理に置くものの例:

```text
.secret/
├── cluster-inputs.env
├── .gitkeep
├── cluster-secrets.yaml
├── talosconfig
├── kubeconfig
├── generated/
│   ├── controlplane.yaml
│   ├── worker.yaml
│   └── talosconfig
├── nodes/
│   ├── controlplane.yaml
│   └── worker.yaml
└── tailscale-authkey.txt
```

## ドキュメントを書くときのルール

- 実 IP は書かず、`192.0.2.10` や `198.51.100.0/24` などの予約済みサンプル値を使う
- 実ドメインは書かず、`example.com` を使う
- 実鍵や実トークンは貼らない
- 実ファイル名を示したい場合は `.example` を付けるか、SOPS 管理対象なら `*.sops.*` を使う
- コマンド例には環境変数名やプレースホルダを使う

例:

```bash
talosctl version --talosconfig "$TALOSCONFIG" --endpoints "$CONTROL_PLANE_IP" --nodes "$CONTROL_PLANE_IP"
kubectl --kubeconfig "$KUBECONFIG" get nodes
```

## 作業時チェックリスト

コミット前に次を確認します。

- 実 IP アドレスが入っていない
- 実ホスト名、実ドメイン名が入っていない
- `*.key`, `*.pem`, `talosconfig`, `kubeconfig` を含んでいない
- トークンやパスワード文字列を貼っていない
- サンプル値がダミー値に置き換わっている

判定基準を固定したい場合は [`docs/commit-secret-reviewer.md`](/home/azuki/work/mistship/docs/commit-secret-reviewer.md) を参照します。

## 今後の整備候補

- `.gitignore` の整備
- `templates/` 配下への `.example` 追加
- 機密情報の保管場所と生成手順の明文化
- TalOS 初期構築手順と更新手順の分離

このリポジトリでは、公開できる情報と SOPS で暗号化した cluster input だけでインフラの構造と再現手順を共有し、平文の実運用値は Git の外で管理します。

`.secret` ディレクトリは作業用の置き場として使いますが、Git では [`.secret/.gitkeep`](/home/azuki/work/mistship/.secret/.gitkeep) だけを追跡します。

TalOS の system extension を使う場合は、起動用イメージだけでなく installer image も同じ schematic に合わせます。詳細は [`image.yml`](/home/azuki/work/mistship/image.yml) と [`docs/bootstrap.md`](/home/azuki/work/mistship/docs/bootstrap.md) を参照してください。

TalOS の秘密情報は SOPS で暗号化した `cluster-secrets.sops.yaml` から `.secret/cluster-secrets.yaml` へ復号し、`--with-secrets` で machine config を再生成します。
