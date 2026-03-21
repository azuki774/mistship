#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

worker_patch_args=()
worker_patch_contents="$(grep -vE "^[[:space:]]*(#|$)" patches/worker.yaml | tr -d "[:space:]" || true)"
if [[ -n "$worker_patch_contents" && "$worker_patch_contents" != "{}" ]]; then
  worker_patch_args+=(--config-patch-worker "@patches/worker.yaml")
fi

echo "::group::Generate Talos artifacts"
talosctl gen config "$CLUSTER_NAME" "https://$CONTROL_PLANE_IP:6443" \
  --with-secrets "$CLUSTER_SECRETS" \
  --install-disk "$INSTALL_DISK" \
  --install-image "$INSTALL_IMAGE" \
  --config-patch "@patches/common.yaml" \
  --config-patch-control-plane "@patches/controlplane.yaml" \
  "${worker_patch_args[@]}" \
  --output "$GENERATED_CONFIG_DIR"

cp "$GENERATED_CONFIG_DIR/controlplane.yaml" "$CONTROL_PLANE_CONFIG"
cp "$GENERATED_CONFIG_DIR/worker.yaml" "$WORKER_CONFIG"
cp "$GENERATED_CONFIG_DIR/talosconfig" "$TALOSCONFIG"
chmod 600 "$CONTROL_PLANE_CONFIG" "$WORKER_CONFIG" "$TALOSCONFIG"
echo "::endgroup::"

if [[ "${GENERATE_KUBECONFIG:-false}" == "true" ]]; then
  echo "::group::Generate kubeconfig"
  talosctl kubeconfig "$KUBECONFIG" \
    --merge=false \
    --force \
    --talosconfig "$TALOSCONFIG" \
    --endpoints "$CONTROL_PLANE_IP" \
    --nodes "$CONTROL_PLANE_IP"
  chmod 600 "$KUBECONFIG"
  echo "::endgroup::"
fi
