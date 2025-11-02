install_kubewarden() {
  echo ">> Install Kubewarden Security Platform"
  helm repo add kubewarden https://charts.kubewarden.io
  helm repo update

  kubectl create namespace kubewarden
  helm install -n kubewarden kubewarden-crds kubewarden/kubewarden-crds
  helm install --wait -n kubewarden kubewarden-controller kubewarden/kubewarden-controller

  helm upgrade -i --wait --namespace kubewarden --create-namespace kubewarden-defaults kubewarden/kubewarden-defaults --reuse-values
}