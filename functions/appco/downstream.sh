#!/bin/bash

appco_setup_downstream() {
    local appco_user=$1
    local appco_token=$2
    kubectl create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username=${appco_user} --docker-password=${appco_token}
    kubectl annotate secret/application-collection "sprouter.geeko.me/enabled"="true"
    helm install sprouter \
        oci://ghcr.io/hierynomus/sprouter/charts/sprouter \
        --namespace sprouter \
        --create-namespace

    kubectl apply -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: appco-auth
  namespace: cattle-system
type: kubernetes.io/basic-auth
stringData:
  password: ${appco_token}
  username: ${appco_user}
---
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: application-collection
  namespace: cattle-system
spec:
  clientSecret:
    name: appco-auth
    namespace: cattle-system
  insecurePlainHttp: false
  url: oci://dp.apps.rancher.io/charts
EOF
}

appco_copy_token_downstream() {
  local downstream_clusters=$1
  local appco_user=$2
  local appco_token=$3

  IFS=',' read -ra CLUSTERS <<< "$downstream_clusters"
  for CLUSTER in "${CLUSTERS[@]}"; do
    echo ">>> Creating AppCo Secret on $CLUSTER"
    cat << EOF > /tmp/appco-secret.json
  {
    "username": "$appco_user",
    "token": "$appco_token"
  }
  EOF
    scp -o StrictHostKeyChecking=accept-new /tmp/appco-secret.json $CLUSTER:/tmp/appco-secret.json
  done
}