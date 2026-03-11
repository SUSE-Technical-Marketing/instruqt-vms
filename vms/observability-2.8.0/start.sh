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

echo ">>> Waiting for kubernetes to be running"
for i in {1..60}; do
  if kubectl cluster-info &>/dev/null; then
    echo "Kubernetes is running"
    break
  fi
  echo "Waiting for kubernetes to be running..."
  sleep 5
done

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=traefik -n traefik --timeout=300s


if [ "${USE_INSTRUQT_SSL_CERTIFICATE:-false}" == "true" ]; then
  echo ">>> Using Instruqt provided SSL certificate"
  download_gcp_certificate sandbox.crt sandbox.key
  k8s_install_sprouter
  k8s_create_wildcardtlssecret sandbox.crt sandbox.key wildcard-tls
  observability_generate_values_new "${OBSERVABILITY_LICENSE}" "${OBSERVABILITY_HOST}" "${OBSERVABILITY_ADMIN_PASSWORD}" "${OBSERVABILITY_SERVICE_TOKEN}" "none" "wildcard-tls" "traefik"
else
  observability_generate_values_new "${OBSERVABILITY_LICENSE}" "${OBSERVABILITY_HOST}" "${OBSERVABILITY_ADMIN_PASSWORD}" "${OBSERVABILITY_SERVICE_TOKEN}" "letsencrypt-prod" "tls-secret" "traefik"
fi

observability_install_server_new "2.8.0" true
if [ $? -ne 0 ]; then
  kubectl get pods -n suse-observability
  fail-message "Failed to wait for observability pods to be ready."
fi
