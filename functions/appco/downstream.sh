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