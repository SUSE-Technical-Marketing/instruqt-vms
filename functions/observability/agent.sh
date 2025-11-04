#!/bin/bash

#######################################
# Install the Observability agent in the cluster and not wait for the pods to be ready
# Arguments:
#   url (SUSE Observability)
#   cluster_name
#   ingestion_api_key
# Examples:
#   observability_agent_install_nowait demo https://obs.suse.com xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#######################################
observability_agent_install_nowait() {
    local cluster_name=$1
    local url=$2
    local ingestion_api_key=$3
    echo "Installing Observability agent..."
    echo "  URL: $url"
    echo "  Cluster name: $cluster_name"
    echo "  Ingestion API key: $ingestion_api_key"

    helm repo add suse-observability https://charts.rancher.com/server-charts/prime/suse-observability
    helm repo update

    helm upgrade --install suse-observability-agent suse-observability/suse-observability-agent \
        --namespace suse-observability --create-namespace \
        --set stackstate.apiKey="${ingestion_api_key}" \
        --set stackstate.url="${url%/}/receiver/stsAgent" \
        --set stackstate.cluster.name="${cluster_name}"
}

#######################################
# Install the Observability agent in the cluster
# Arguments:
#   url (SUSE Observability)
#   cluster_name
#   ingestion_api_key
# Examples:
#   observability_agent_install https://obs.suse.com demo xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#######################################
observability_agent_install() {
    local cluster_name=$1
    local url=$2
    local ingestion_api_key=$3

    observability_agent_install_nowait $cluster_name $url $ingestion_api_key

    kubectl wait pods -n suse-observability -l app.kubernetes.io/instance=suse-observability-agent --for condition=Ready
}

#######################################
# Create an Agent Service Token for SUSE Observability
# Output:
#   The Agent Service Token
# Arguments:
#   cluster_name
#   url (SUSE Observability)
#   service_token (SUSE Observability)
# Examples:
#   observability_create_agent_service_token demo https://obs.suse.com/ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#######################################
observability_create_agent_service_token() {
  local cluster_name=$1
  local url=$2
  local service_token=$3

  local resp
  /usr/local/bin/sts rbac create-subject --subject $cluster_name-agent --service-token $service_token --url $url >/dev/null 2>&1
  /usr/local/bin/sts rbac grant --subject $cluster_name-agent --permission update-metrics --service-token $service_token --url $url >/dev/null 2>&1
  resp=$(/usr/local/bin/sts service-token create --name $cluster_name --roles $cluster_name-agent --service-token $service_token --url $url -o json)
  echo $resp | jq -r '."service-token".token'
}
