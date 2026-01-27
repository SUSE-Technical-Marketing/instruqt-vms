#!/bin/bash
# Collection of functions to add components to manage certificates in a Kubernetes cluster

#######################################
# Install cert-manager and wait for the the application to be running
# Arguments:
#   cert-manager version
# Examples:
#   k8s_install_certmanager "v1.11.0"
#######################################
k8s_install_certmanager() {
  local version=$1

  echo 'Installing cert-manager...'
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true \
    --version ${version}
  if [ $? -ne 0 ]; then
    echo "Failed to install cert-manager"
    exit 1
  fi
  sleep 5
  kubectl wait pods -n cert-manager -l app.kubernetes.io/instance=cert-manager --for condition=Ready 2>/dev/null
}

k8s_install_sprouter() {
  echo 'Installing Sprouter...'
  helm install sprouter -n sprouter --create-namespace oci://ghcr.io/hierynomus/sprouter/charts/sprouter
  if [ $? -ne 0 ]; then
    echo "Failed to install SProuter"
    exit 1
  fi
  # Wait for pod to be created
  sleep 5
  kubectl wait pods -n sprouter -l app.kubernetes.io/instance=sprouter --for condition=Ready 2>/dev/null
}

k8s_create_wildcardtlssecret() {
  local certFile=$1
  local keyFile=$2
  local secretName=${3:-wildcard-tls}

  echo "Creating wildcard TLS secret..."
  kubectl create secret tls ${secretName} --cert=${certFile} --key=${keyFile}
  if [ $? -ne 0 ]; then
    echo "Failed to create wildcard TLS secret"
    exit 1
  fi
  kubectl annotate secret ${secretName} sprouter.geeko.me/enabled="true"
}

#######################################
# Create certificate cluster issuers using Let's Encrypt
# Arguments:
#   Ingress class name (traefik, nginx, etc.)
#   administrator email address (to receive notifications for Let's Encrypt)
# Examples:
#   k8s_create_letsencryptclusterissuer traefik john.wick@thecontinental.hotel
#######################################
k8s_create_letsencryptclusterissuer() {
  local ingressClassname=$1
  local emailAddress=$2

  echo "Creating certificate issuers using Let's Encrypt..."
  kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${emailAddress}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: ${ingressClassname}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${emailAddress}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: ${ingressClassname}
EOF
  if [ $? -ne 0 ]; then
    echo "Failed to create Let's Encrypt cluster issuer"
    exit 1
  fi

  # Wait for the cluster issuers to be ready
  kubectl wait --for=condition=Ready clusterissuer/letsencrypt-staging --timeout=60s
  kubectl wait --for=condition=Ready clusterissuer/letsencrypt-prod --timeout=60s
}
