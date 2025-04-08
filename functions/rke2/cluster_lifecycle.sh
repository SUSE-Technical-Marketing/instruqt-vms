#!/bin/bash

#####
# Create a new RKE2 cluster
# Arguments:
#   RKE2 version
#   Node name
# Examples:
#   rke2_create_cluster "v1.23" "rancher-master"
######
rke2_create_cluster() {
    local version=$1
    local nodename=$2

    echo 'Installing RKE2...'
    mkdir -p /etc/rancher/rke2
    cat <<EOF > /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "644"
node-name: "${nodename}"
EOF
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="${version}" sh -

    echo 'Configuring RKE2 service...'
    systemctl enable rke2-server.service
    systemctl start rke2-server.service
}

#####
# Copy RKE2 kubeconfig file to local user file
# Arguments:
#   None
# Examples:
#   rke2_copy_kubeconfig
######
rke2_copy_kubeconfig() {
    mkdir -p ~/.kube
    cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
    chmod 600 ~/.kube/config
}
