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

# rancher_import_cluster ${HOSTNAME}
# CLUSTER_ID="$(rancher_return_clusterid ${HOSTNAME})"

# # Get the ClusterRegistrationToken
# CLUSTER_TOKEN=$(rancher_return_clusterregistrationmanifest "${CLUSTER_ID}")

# # Switch to downstream cluster
# unset KUBECONFIG

# kubectl apply -f "${CLUSTER_TOKEN}"

# echo "Waiting for the cluster to be registered..."
# export KUBECONFIG=~/${MANAGER_HOSTNAME}-kubeconfig.yaml
# kubectl wait --for=condition=Ready --timeout=300s cluster.provisioning.cattle.io -n fleet-default ${HOSTNAME}
