#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "::group::Apply control plane config"
talosctl apply-config \
  --talosconfig "$TALOSCONFIG" \
  --endpoints "$CONTROL_PLANE_IP" \
  --nodes "$CONTROL_PLANE_IP" \
  --file "$CONTROL_PLANE_CONFIG"
echo "::endgroup::"

echo "::group::Verify Talos API recovery"
for attempt in $(seq 1 20); do
  if talosctl version \
    --talosconfig "$TALOSCONFIG" \
    --endpoints "$CONTROL_PLANE_IP" \
    --nodes "$CONTROL_PLANE_IP"
  then
    break
  fi

  sleep 15

  if [[ "$attempt" -eq 20 ]]; then
    echo "Talos API did not recover after apply-config" >&2
    exit 1
  fi
done
echo "::endgroup::"

echo "::group::Generate kubeconfig"
talosctl kubeconfig "$KUBECONFIG" \
  --merge=false \
  --force \
  --talosconfig "$TALOSCONFIG" \
  --endpoints "$CONTROL_PLANE_IP" \
  --nodes "$CONTROL_PLANE_IP"
chmod 600 "$KUBECONFIG"
echo "::endgroup::"

if ! find manifests/infra -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) -print -quit | grep -q .; then
  echo "No infrastructure manifests found under manifests/infra; skipping apply."
  exit 0
fi

echo "::group::Apply infrastructure manifests"
./scripts/apply-calico.sh
kubectl apply --recursive -f manifests/infra
echo "::endgroup::"
