#!/bin/bash

# This script is used during the Instruqt track_scripts phase to configure the pre-provisioned Rancher for the track instance.

# waits for Instruqt host bootstrap to finish
until [ -f /opt/instruqt/bootstrap/host-bootstrap-completed ]
do
  sleep 1
done

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Script directory: ${SCRIPT_DIR}"
. $SCRIPT_DIR/../../functions/index.sh

export RANCHER_DOMAIN="rancher.${HOSTNAME}.${_SANDBOX_ID}.instruqt.io"
export RANCHER_URL="https://${RANCHER_DOMAIN}"

export RANCHER_API_URL="${RANCHER_URL}/v3"
export RANCHER_ADMIN="admin"
export RANCHER_ADMIN_PASSWORD="$(tr -dc '[:alnum:]' </dev/urandom | head -c 13; echo '69')"

echo "--------------------------------"
echo "Rancher Configuration Details:"
echo "Rancher URL: ${RANCHER_URL}"
echo "Rancher Admin Username: ${RANCHER_ADMIN}"
echo "Rancher Admin Password: ${RANCHER_ADMIN_PASSWORD}"
echo "--------------------------------"

# Set variables for the instructions and passing down to other scripts
agent variable set "RANCHER_ADMIN" "$RANCHER_ADMIN"
agent variable set "RANCHER_ADMIN_PASSWORD" "$RANCHER_ADMIN_PASSWORD"

# Wait for kubernetes to be running

echo ">>> Waiting for kubernetes to be running"
for i in {1..60}; do
  if kubectl cluster-info &>/dev/null; then
    echo "Kubernetes is running"
    break
  fi
  echo "Waiting for kubernetes to be running..."
  sleep 5
done

# Wait for cert-manager
echo ">>> Waiting for cert-manager to be ready"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
echo ">>> Waiting for ingress-nginx to be ready"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=ingress-nginx -n ingress-nginx --timeout=300s

echo ">>> Recreating Rancher Ingress"
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found
kubectl delete ingress rancher -n cattle-system --ignore-not-found
rancher_create_ingress "nginx" "${RANCHER_DOMAIN}"

# Wait until certificate to exist (can't use kubectl because the cert is not present yet)
echo ">>> Waiting for Rancher TLS certificate to be created"
for i in {1..60}; do
  if kubectl get certificate rancher-tls -n cattle-system &>/dev/null; then
    echo "Rancher TLS certificate is ready"
    break
  fi
  echo "Waiting for Rancher TLS certificate to be created..."
  sleep 5
done

# # Wait for certificate to be issued
kubectl wait --for=condition=Ready certificate rancher-tls -n cattle-system --timeout=300s

# Wait for Rancher deployment to be ready
echo ">>> Waiting for Rancher deployment to be ready"
kubectl wait --for=condition=Available deployment/rancher -n cattle-system --timeout=300s

rancher_first_login $RANCHER_URL "$RANCHER_ADMIN_PASSWORD"
export RANCHER_BEARER_TOKEN=$(rancher_login_withpassword $RANCHER_URL $RANCHER_ADMIN "$RANCHER_ADMIN_PASSWORD")

KUBECONFIG=$(rancher_download_kubeconfig $RANCHER_URL $RANCHER_BEARER_TOKEN "local")

KUBECONFIG=$(echo "$KUBECONFIG" | jq -r ".config")
echo "$KUBECONFIG" | yq e '.clusters[0].cluster["insecure-skip-tls-verify"] = true | .clusters[0].cluster.certificate-authority-data = "" | .clusters[0].cluster.server = "https://rancher.${HOSTNAME}.${_SANDBOX_ID}.instruqt.io/k8s/clusters/local" | .clusters[0].cluster.server |= envsubst' > ./${HOSTNAME}-kubeconfig.yaml

# Split DOWNSTREAM_CLUSTERS and iterate over each cluster name
IFS=',' read -ra CLUSTERS <<< "$DOWNSTREAM_CLUSTERS"
for CLUSTER in "${CLUSTERS[@]}"; do
  echo ">>> Copying kubeconfig to downstream cluster: ${CLUSTER}"
  scp -o StrictHostKeyChecking=accept-new ./${HOSTNAME}-kubeconfig.yaml ${CLUSTER}:${HOSTNAME}-kubeconfig.yaml
done
