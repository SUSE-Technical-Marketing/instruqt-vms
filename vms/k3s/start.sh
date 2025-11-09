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
echo "Waiting for rancher-webhook deployment to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/rancher-webhook -n cattle-system