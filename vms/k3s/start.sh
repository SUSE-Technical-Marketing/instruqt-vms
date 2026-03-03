#!/bin/bash

# waits for Instruqt host bootstrap to finish
until [ -f /opt/instruqt/bootstrap/host-bootstrap-completed ]
do
  sleep 1
done

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Script directory: ${SCRIPT_DIR}"
. $SCRIPT_DIR/../../functions/index.sh

export KUBECONFIG=~/${MANAGER_HOSTNAME}-kubeconfig.yaml
cat ~/${MANAGER_HOSTNAME}-kubeconfig.yaml

# k8s_patch_traefik_gateway_with_host "\*.${HOSTNAME}.${_SANDBOX_ID}.instruqt.io"

rancher_import_cluster ${HOSTNAME}
CLUSTER_ID="$(rancher_return_clusterid ${HOSTNAME})"

echo "Cluster ID: ${CLUSTER_ID}"

# Get the ClusterRegistrationToken
CLUSTER_TOKEN=$(rancher_return_clusterregistrationmanifest "${CLUSTER_ID}")

echo "Cluster registration token manifest: ${CLUSTER_TOKEN}"
# Switch to downstream cluster
unset KUBECONFIG

kubectl apply -f "${CLUSTER_TOKEN}"

echo "Waiting for the cluster to be registered..."
export KUBECONFIG=~/${MANAGER_HOSTNAME}-kubeconfig.yaml
kubectl wait --for=condition=Ready --timeout=300s cluster.provisioning.cattle.io -n fleet-default ${HOSTNAME}

# Switch to downstream cluster
unset KUBECONFIG

# Wait for the rancher-webhook deployment to be ready
# Wait until the rancher-webhook deployment is present
until kubectl get deployment rancher-webhook -n cattle-system &> /dev/null
do
  sleep 2
done

echo "Waiting for rancher-webhook deployment to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/rancher-webhook -n cattle-system

if [ "${USE_INSTRUQT_SSL_CERTIFICATE:-false}" == "true" ]; then
  echo ">>> Using Instruqt provided SSL certificate"
  download_gcp_certificate sandbox.crt sandbox.key
  k8s_install_sprouter
  k8s_create_wildcardtlssecret sandbox.crt sandbox.key wildcard-tls
  echo ">>> Waiting for Rancher Wildcard TLS secret to be synced"
  for i in {1..60}; do
    if kubectl get secret wildcard-tls -n cattle-system &>/dev/null; then
      echo "Rancher Wildcard TLS is ready"
      break
    fi
    echo "Waiting for Rancher Wildcard TLS secret to be synced..."
    sleep 5
  done
fi