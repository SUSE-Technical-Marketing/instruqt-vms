#!/bin/bash

K3S_VERSION="v1.31.7+k3s1"
CERTMANAGER_VERSION="v1.17.1"
LETSENCRYPT_EMAIL_ADDRESS=john.wick@google.com

# Increase file descriptors limit
ulimit -n 65536

zypper install -y https://download.opensuse.org/repositories/utilities/15.6/x86_64/yq-4.44.6-lp156.42.1.x86_64.rpm

# support tools
rpm -Uvh https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.rpm

# install helm
zypper in -y helm

curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL="${K3S_VERSION}" INSTALL_K3S_EXEC="--disable=traefik" K3S_NODE_NAME="sobs-master" K3S_KUBECONFIG_MODE="644" sh -

# install ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install \
  --namespace ingress-nginx \
  --create-namespace \
  ingress-nginx ingress-nginx/ingress-nginx

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=ingress-nginx -n ingress-nginx --timeout=300s

# install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  --version ${CERTMANAGER_VERSION} \
  --set crds.enabled=true \
  --namespace cert-manager \
  --create-namespace \
  cert-manager jetstack/cert-manager

kubectl apply -f <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${LETSENCRYPT_EMAIL_ADDRESS}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${LETSENCRYPT_EMAIL_ADDRESS}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

