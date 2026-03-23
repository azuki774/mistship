# Encrypted Cluster Inputs

このディレクトリには、SOPS で暗号化した cluster input を置きます。

想定ファイル:

- `cluster-inputs.sops.env`
- `cluster-secrets.sops.yaml`

平文の `cluster-inputs.env`、`cluster-secrets.yaml`、`talosconfig`、`kubeconfig` はここへ置きません。
