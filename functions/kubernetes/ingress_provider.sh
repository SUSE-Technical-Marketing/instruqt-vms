k8s_install_ingress_nginx() {
  echo "******** DEPRECATED: This function is deprecated and will be removed in future versions. Please use Traefik instead. ********"
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

k8s_install_traefik() {
  local traefik_version="$1"
  echo "Installing Traefik..."
  echo << EOF > traefik-values.yaml
providers:
  kubernetesGateway:
    enabled: true
gateway:
  enabled: true
  listeners:
    web:
      port: 8000
      protocol: HTTP
      namespacePolicy:
        from: All
    websecure:
      port: 8443
      protocol: HTTPS
      namespacePolicy:
        from: All
      certificateRefs:
        - name: wildcard-tls
          kind: Secret
EOF
  helm repo add traefik https://traefik.github.io/charts
  helm repo update
  helm upgrade --install \
    --namespace traefik --create-namespace \
    --values traefik-values.yaml \
    --version ${traefik_version} \
    traefik traefik/traefik
  if [ $? -ne 0 ]; then
    echo "Failed to install Traefik"
    exit 1
  fi
  sleep 5
  kubectl wait pods -n traefik -l app.kubernetes.io/name=traefik --for condition=Ready
}

k8s_patch_traefik_gateway_with_host() {
  local host="$1"
  echo "Patching Traefik Gateway with host ${host}..."
  kubectl patch gateway -n traefik traefik-gateway --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/listeners/0/hostname\", \"value\": \"${host}\"}, {\"op\": \"replace\", \"path\": \"/spec/listeners/1/hostname\", \"value\": \"${host}\"}]"

}