#!/usr/bin/env bash

set -exuo pipefail

# Check in which directory the script is running
# This is important to know because the script will be sourced in the vms directory
# and the functions will be used in the vms directory

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Script directory: ${SCRIPT_DIR}"
# Source env file
. "${SCRIPT_DIR}/../../env"
# Source functions
for file in "${SCRIPT_DIR}"/../../functions/*/*.sh
do
  echo "Sourcing $(basename $file)"
  . "${file}"
done

install_tooling "${K9S_VERSION}"
echo ">> Increase limits"
increase_limits
echo ">> Setup k3s"
k3s_create_cluster "v1.34.4+k3s1" "rancher-master"
k3s_copy_kubeconfig
echo ">> Install Traefik"
k8s_install_traefik "${TRAEFIK_VERSION}"
echo ">> Install cert-manager"
k8s_install_certmanager "1.19.4"
k8s_create_letsencryptclusterissuer "traefik" "${LETSENCRYPT_EMAIL_ADDRESS}"

observability_add_helm_repo

echo ">> Generate (NEW) values for observability"
# Provision with dummy values, this ensures that the observability server is installed and most pods will not change afterwards
observability_generate_values_new "no-license" "test.host" "dummy-password" "svctok-instruqt" "none" "wildcard-tls" "traefik"
observability_install_server_new "2.8.0"

echo ">>> Waiting for Observability Pods to be available..."
observability_wait_for_pods
