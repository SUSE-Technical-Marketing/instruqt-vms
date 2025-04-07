#!/bin/bash

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

install_tooling
echo ">> Increase limits"
increase_limits
echo ">> Setup k3s"
k3s_create_cluster "${K3S_VERSION}" "rancher-master"
k3s_copy_kubeconfig
echo ">> Install Ingress Nginx"
k8s_install_ingress_nginx
echo ">> Install cert-manager"
k8s_install_certmanager "${CERTMANAGER_VERSION}"
k8s_create_letsencryptclusterissuer "nginx" "${LETSENCRYPT_EMAIL_ADDRESS}"

echo ">> Install Rancher"
rancherprime_install_withcertmanagerclusterissuer "${RANCHER_VERSION}" "rancher.test.host"
