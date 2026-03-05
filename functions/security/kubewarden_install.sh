install_kubewarden() {
  appco_username=$1
  appco_token=$2

  install_kubewarden_core
  install_kubewarden_defaults "$appco_username" "$appco_token"
}

install_kubewarden_core() {
  echo ">> Install Kubewarden Security Platform"
  helm repo add kubewarden https://charts.kubewarden.io
  helm repo update

  helm install -n kubewarden kubewarden-crds ./instruqt-vms/assets/charts/kubewarden-crds-$KUBEWARDEN_CRDS_VERSION.tgz
  helm install --wait -n kubewarden kubewarden-controller ./instruqt-vms/assets/charts/kubewarden-controller-$KUBEWARDEN_CONTROLLER_VERSION.tgz
}

install_kubewarden_defaults() {
  appco_username=$1
  appco_token=$2

  if [ -z "$appco_username" ] || [ -z "$appco_token" ]; then
    echo ">> APPCO credentials not provided, stopping"
    return 1
  fi

  kubectl create secret docker-registry suse-application-collection --docker-server=dp.apps.rancher.io --docker-username=${appco_username} --docker-password=${appco_token} -n kubewarden
  helm upgrade -i --wait --namespace kubewarden --create-namespace kubewarden-defaults ./instruqt-vms/assets/charts/kubewarden-defaults-$KUBEWARDEN_DEFAULTS_VERSION.tgz --reuse-values --set policyServer.imagePullSecret=suse-application-collection
}