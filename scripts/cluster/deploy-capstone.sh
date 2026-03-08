#!/usr/bin/env bash
set -euo pipefail

# Usage:
# ./scripts/cluster/deploy-capstone.sh <MASTER_PUBLIC_IP>

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <MASTER_PUBLIC_IP>"
  exit 1
fi

MASTER_PUBLIC_IP="$1"

kubectl apply -f k8s/namespace.yaml

# Update frontend runtime API URL before apply.
sed "s|MASTER_PUBLIC_IP|$MASTER_PUBLIC_IP|g" k8s/configmap.yaml | kubectl apply -f -

kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/mongo-pv-pvc.yaml
kubectl apply -f k8s/mongo-statefulset.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/services.yaml

echo "Installing ArgoCD..."
bash scripts/cluster/install-argocd.sh

echo "Registering QuickHire ArgoCD Application..."
kubectl apply -f k8s/argocd-application.yaml

echo "Installing Prometheus/Grafana/Loki/Promtail..."
bash scripts/cluster/install-observability.sh

echo "Deployment complete."
echo "Frontend URL: http://$MASTER_PUBLIC_IP:30080"
echo "Backend URL:  http://$MASTER_PUBLIC_IP:30081/api"
echo "Prometheus:   http://$MASTER_PUBLIC_IP:30900"
echo "Grafana:      http://$MASTER_PUBLIC_IP:30300"
