#!/bin/bash

rancher_install_liz_ui() {
  rancher_url=$1
  bearer_token=$2
  version=$3
  echo ">>> Installing Liz in the cluster"
  kubectl apply -f - <<EOF
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: liz-ui-plugins
spec:
  gitRepo: https://github.com/torchiaf/rancher-ai-ui
  gitBranch: gh-pages
EOF

  curl -sSL $curl_extras $rancher_url/v1/catalog.cattle.io.clusterrepos/liz-ui-plugins?action=install \
    -X POST \
    -H "Authorization: Bearer $bearer_token" \
    -d '{"charts":[{"chartName":"rancher-ai-ui","version":"'"$version"'","releaseName":"rancher-ai-ui","annotations":{},"values":{}}],"namespace":"cattle-ui-plugin-system"}'
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Liz UI"
    exit 1
  fi
}