#!/bin/sh
# Install or upgrade Grafana Cloud monitoring on the current kube context.
# Usage: GRAFANA_CLOUD_TOKEN=glc_... ./monitoring/install.sh
set -eu
: "${GRAFANA_CLOUD_TOKEN:?set GRAFANA_CLOUD_TOKEN (Grafana Cloud access policy token)}"
cd "$(dirname "$0")"

helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update grafana >/dev/null

helm upgrade --install grafana-cloud grafana/k8s-monitoring \
  --version 4.5.2 \
  --namespace monitoring --create-namespace \
  -f values.yaml \
  --set-string collectorCommon.alloy.remoteConfig.auth.password="$GRAFANA_CLOUD_TOKEN" \
  --wait --timeout 10m
