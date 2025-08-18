#!/bin/bash

# This script is used during the Instruqt track_scripts phase to configure the pre-provisioned Rancher for the track instance.

# waits for Instruqt host bootstrap to finish
until [ -f /opt/instruqt/bootstrap/host-bootstrap-completed ]
do
  sleep 1
done

echo "PATH: $PATH"
echo "User: $(whoami)"
echo "UID: $(id -u)"
echo "GID: $(id -g)"


# makes sure the registration is ok
# registercloudguest --force-new

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Script directory: ${SCRIPT_DIR}"

. $SCRIPT_DIR/../../functions/index.sh

RANCHER_DOMAIN="rancher.${HOSTNAME}.${_SANDBOX_ID}.instruqt.io"
RANCHER_URL="https://${RANCHER_DOMAIN}"

RANCHER_API_URL="${RANCHER_URL}/v3"
RANCHER_ADMIN="admin"
RANCHER_ADMIN_PASSWORD="$(tr -dc '[:alnum:]' </dev/urandom | head -c 13; echo '69')"

########################## DELETE FOR PROD
echo -e "\n\n\nthis is it ${RANCHER_ADMIN_PASSWORD}\n\n\n\n"
########################  DELETE FOR PROD


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

# kubectl patch ingress rancher -n cattle-system --type='json' -p='[{"op": "replace", "path": "/spec/rules/0/host", "value": "'"${RANCHER_DOMAIN}"'"}, {"op": "replace", "path": "/spec/tls/0/hosts/0", "value": "'"${RANCHER_DOMAIN}"'"}]'
# # Wait for certificate to be issued
# kubectl wait --for=condition=Ready certificate rancher-tls -n cattle-system --timeout=300s

# rancher_first_login $RANCHER_URL $RANCHER_ADMIN_PASSWORD
