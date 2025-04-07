k8s_install_ingress_nginx() {
  echo "Installing Ingress NGINX..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm upgrade --install \
    --namespace ingress-nginx --create-namespace \
    ingress-nginx ingress-nginx/ingress-nginx
  if [ $? -ne 0 ]; then
    echo "Failed to install Ingress NGINX"
    exit 1
  fi
  kubectl wait pods -n ingress-nginx -l app.kubernetes.io/instance=ingress-nginx --for condition=Ready
}
