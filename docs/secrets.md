# Secret Management with SOPS

`mistship` は public repository として運用するため、平文の cluster input や TalOS / Kubernetes secret bundle は Git に含めません。

その代わりに、SOPS で暗号化したファイルを Git で管理し、ローカル作業や GitHub Actions では一時的に `.secret/` へ復号して使います。

## 管理対象

暗号化して Git に置くもの:

- `secrets/mistship/cluster-inputs.sops.env`
- `secrets/mistship/cluster-secrets.sops.yaml`

Git に置かないもの:

- `talosconfig`
- `kubeconfig`
- 生成済みの `controlplane.yaml`
- 生成済みの `worker.yaml`
- `age` private key

`.secret/` は復号済み作業領域として使い、Git では引き続き [`.secret/.gitkeep`](/home/azuki/work/mistship/.secret/.gitkeep) だけを追跡します。

## 役割分担

- `cluster-inputs.sops.env`
  - cluster 名、control plane IP、install disk、TalOS version、schematic ID などの入力値を保持する
- `cluster-secrets.sops.yaml`
  - `talosctl gen secrets` の出力を保持する
- `.secret/cluster-inputs.env`
  - `cluster-inputs.sops.env` をローカルに復号した一時ファイル
- `.secret/cluster-secrets.yaml`
  - `cluster-secrets.sops.yaml` をローカルに復号した一時ファイル

## ローカルでの使い方

1. age private key を `SOPS_AGE_KEY` に入れる
2. `nix develop` で dev shell に入る
3. 復号する

```bash
export SOPS_AGE_KEY='AGE-SECRET-KEY-1...'
nix develop .#default --command bash ./scripts/decrypt-cluster-secrets.sh
```

4. machine config と `talosconfig` を生成する

```bash
set -a
source .secret/cluster-inputs.env
set +a
nix develop .#default --command bash ./scripts/prepare-cluster-access.sh
```

## GitHub Actions での使い方

- GitHub environment secret `SOPS_AGE_KEY` に CI 用 `age` private key を入れる
- secret を復号する workflow は `Development` environment などの trusted context に限定する
- [`cluster-access`](/home/azuki/work/mistship/.github/actions/cluster-access/action.yml) は `SOPS_AGE_KEY` をそのまま使って [`scripts/decrypt-cluster-secrets.sh`](/home/azuki/work/mistship/scripts/decrypt-cluster-secrets.sh) を呼び、`.secret/cluster-inputs.env` と `.secret/cluster-secrets.yaml` を生成する
- 復号後は既存の [`scripts/prepare-cluster-access.sh`](/home/azuki/work/mistship/scripts/prepare-cluster-access.sh) で `talosconfig` と machine config を再生成する

この repo では次の境界で運用します。

- `talos-update.yml`
  - trusted context でのみ実行する
  - 実 secret を復号して cluster へ apply する
- `talos-preflight.yml`
  - PR でも実行する
  - 実 secret は復号しない
  - dummy secrets で `prepare-cluster-access.sh` の生成経路だけ検証する

## 鍵管理

- 人間の operator は各自の `age` key pair を持つ
- CI 用には専用の `age` key pair を 1 つ用意する
- public key だけを `.sops.yaml` に登録する
- private key は repo に置かない

recipient の追加・削除を行うときは、`.sops.yaml` を更新した上で `sops updatekeys` を使います。

## 初回セットアップ

この repo には recipient の実値と暗号化済み実データは含めていません。

最初の投入時は次を行います。

1. `.sops.yaml` に operator と CI の public key を記入する
2. [`templates/cluster-inputs.env.example`](/home/azuki/work/mistship/templates/cluster-inputs.env.example) を元に平文の cluster input を作る
3. `talosctl gen secrets` で平文の `cluster-secrets.yaml` を作る
4. `sops --encrypt` で `secrets/mistship/cluster-inputs.sops.env` と `secrets/mistship/cluster-secrets.sops.yaml` を作る
5. 平文ファイルは削除し、`.secret/` は作業終了後に消す
