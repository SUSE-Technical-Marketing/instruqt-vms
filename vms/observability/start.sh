#!/bin/bash

# This script is used during the Instruqt track_scripts phase to configure the pre-provisioned Rancher for the track instance.

# waits for Instruqt host bootstrap to finish
until [ -f /opt/instruqt/bootstrap/host-bootstrap-completed ]
do
  sleep 1
done

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Source env file
. "${SCRIPT_DIR}/../../env"

echo "Script directory: ${SCRIPT_DIR}"
. $SCRIPT_DIR/../../functions/index.sh


# Wait for cert-manager
echo ">>> Waiting for cert-manager to be ready"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
echo ">>> Waiting for ingress-nginx to be ready"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=ingress-nginx -n ingress-nginx --timeout=300s


export OBSERVABILITY_ADMIN_PASSWORD="$(tr -dc '[:alnum:]' </dev/urandom | head -c 13; echo '69')"
agent variable set OBSERVABILITY_ADMIN_PASSWORD "${OBSERVABILITY_ADMIN_PASSWORD}"

if [ -z "${OBSERVABILITY_LICENSE}" ]; then
  fail-message "OBSERVABILITY_LICENSE is not set. Please provide a valid license."
fi

# Ensure the observability service token is set
if [ -z "${OBSERVABILITY_SERVICE_TOKEN}" ]; then
  fail-message "OBSERVABILITY_SERVICE_TOKEN is not set. Please provide a valid service token."
fi

# Ensure the observability host is set
if [ -z "${OBSERVABILITY_HOST}" ]; then
  fail-message "OBSERVABILITY_HOST is not set. Please provide a valid host."
fi

observability_generate_values "${OBSERVABILITY_LICENSE}" "${OBSERVABILITY_HOST}" "${OBSERVABILITY_ADMIN_PASSWORD}" "${OBSERVABILITY_SERVICE_TOKEN}"
observability_install_server $OBSERVABILITY_VERSION true
if [ $? -ne 0 ]; then
  kubectl get pods -n suse-observability
  fail-message "Failed to wait for observability pods to be ready."
fi
