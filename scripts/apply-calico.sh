#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
calico_dir="$repo_root/manifests/infra/calico"

if [[ ! -d "$calico_dir" ]]; then
  echo "No Calico manifests found under $calico_dir; skipping Calico apply."
  exit 0
fi

kubectl apply -f "$calico_dir/00-namespace.yaml"
kubectl apply -f "$calico_dir/10-kubernetes-services-endpoint.yaml"
kubectl apply -f "$calico_dir/20-tigera-operator.yaml"

kubectl rollout status deployment/tigera-operator -n tigera-operator --timeout=5m

kubectl wait --for=condition=Established crd/installations.operator.tigera.io --timeout=2m
kubectl wait --for=condition=Established crd/apiservers.operator.tigera.io --timeout=2m
kubectl wait --for=condition=Established crd/felixconfigurations.crd.projectcalico.org --timeout=2m
kubectl wait --for=condition=Established crd/tigerastatuses.operator.tigera.io --timeout=2m

kubectl apply -f "$calico_dir/30-installation.yaml"
kubectl apply -f "$calico_dir/31-apiserver.yaml"
kubectl apply -f "$calico_dir/32-felixconfiguration.yaml"

kubectl rollout status deployment/calico-kube-controllers -n calico-system --timeout=10m
kubectl rollout status daemonset/calico-node -n calico-system --timeout=10m
kubectl rollout status deployment/calico-apiserver -n calico-apiserver --timeout=10m

kubectl get tigerastatus
