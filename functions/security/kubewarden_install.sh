install_kubewarden() {
  appco_username=$1
  appco_token=$2

  echo ">> Install Kubewarden Security Platform"
  helm repo add kubewarden https://charts.kubewarden.io
  helm repo update

  kubectl create namespace kubewarden
  kubectl create secret docker-registry suse-application-collection --docker-server=dp.apps.rancher.io --docker-username=${appco_username} --docker-password=${appco_token} -n kubewarden

  helm install -n kubewarden kubewarden-crds kubewarden/kubewarden-crds
  helm install --wait -n kubewarden kubewarden-controller kubewarden/kubewarden-controller

  helm upgrade -i --wait --namespace kubewarden --create-namespace kubewarden-defaults kubewarden/kubewarden-defaults --reuse-values --set policyServer.imagePullSecret=suse-application-collection
}