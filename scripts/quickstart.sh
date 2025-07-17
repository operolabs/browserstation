#!/usr/bin/env bash
set -euo pipefail
usage() { echo "Usage: $0 --arm|--x86 [--api-key=KEY]"; exit 1; }

ARCH= API_KEY=""
for a in "$@"; do
  case $a in
    --arm) ARCH=arm64 ;;
    --x86) ARCH=x86_64 ;;
    --api-key=*) API_KEY=${a#*=} ;;
    *) usage ;;
  esac
done
[[ $ARCH ]] || usage

for c in kind helm kubectl docker; do command -v "$c" >/dev/null || { echo "$c missing"; exit 1; }; done

kind create cluster --name browserstation || true

helm repo add kuberay https://ray-project.github.io/kuberay-helm/ 2>/dev/null || true
helm repo update
helm upgrade --install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system --create-namespace --version 1.3.0 --wait

DOCKERFILE=$(
  [[ $ARCH == arm64 && -f Dockerfile.arm ]] && echo Dockerfile.arm \
  || echo Dockerfile.$ARCH
)
[[ -f $DOCKERFILE ]] || { echo "Missing $DOCKERFILE"; exit 1; }

docker build -t browserstation:latest -f "$DOCKERFILE" .
kind load docker-image browserstation:latest --name browserstation

kubectl apply -f rayservice.yaml >/dev/null

echo -n "⏳ Waiting for Ray head pod to start ..."
while ! kubectl get pods -n ray-system -l ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; do
  sleep 2; echo -n "."
done
echo

kubectl wait --for=condition=Ready pod -l ray.io/node-type=head -n ray-system --timeout=300s

[[ $API_KEY ]] && export BROWSERSTATION_API_KEY="$API_KEY"

# restart port‑forward
pkill -f "kubectl port-forward.*8050:8050" 2>/dev/null || true
kubectl port-forward -n ray-system svc/browser-cluster-public 8050:8050 &
PF_PID=$!

sleep 2
if ps -p $PF_PID &>/dev/null; then
  echo "✓ Service reachable at http://localhost:8050  (kill $PF_PID to stop)"
else
  echo "✗ Port‑forward failed; inspect with: kubectl get pods,svc -n ray-system"
fi
