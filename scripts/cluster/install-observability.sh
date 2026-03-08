#!/usr/bin/env bash
set -euo pipefail

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f k8s/observability/prometheus-values.yaml

helm upgrade --install loki grafana/loki-stack \
  -n monitoring \
  -f k8s/observability/loki-values.yaml

echo "Observability stack installed."
echo "Prometheus NodePort: 30900"
echo "Grafana NodePort: 30300"
