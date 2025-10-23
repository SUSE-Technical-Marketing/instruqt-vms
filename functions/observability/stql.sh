#!/bin/bash

#######################################
# Get the state of a component in SUSE Observability
# Arguments:
#   stql
#   url (SUSE Observability)
#   service_token (SUSE Observability)
# Output:
#   "CRITICAL", "DEVIATING", "UNKNOWN" or "CLEAR"
# Examples:
#   observability_get_component_state "label = \"cluster-name:$DOWNSTREAM_CLUSTER_NAME\" AND ..." https://obs.suse.com/ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#######################################
observability_get_component_state() {
    local stql=$1
    local url=$2
    local service_token=$3

    local component
    component=$(observability_get_component_snapshot $url $service_token "$stql")
    echo $component | jq -r '.viewSnapshotResponse.components[0].state.healthState'
}

#######################################
# Query the snapshot of a component in SUSE Observability
# Arguments:
#   stql
#   url (SUSE Observability)
#   service_token (SUSE Observability)
# Output:
#   JSON viewSnapshotResponse
# Examples:
#   observability_get_component_snapshot "label = \"cluster-name:$DOWNSTREAM_CLUSTER_NAME\" AND ..." https://obs.suse.com/ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#######################################
observability_get_component_snapshot() {
    local stql=$1
    local url=$2
    local service_token=$3

    local req
    req=$(cat <<EOF
{
  "queryVersion": "1.0",
  "metadata":     {
    "groupingEnabled":       false,
    "showIndirectRelations": false,
    "minGroupSize":          10,
    "groupedByLayer":        false,
    "groupedByDomain":       false,
    "groupedByRelation":     false,
    "autoGrouping":          false,
    "connectedComponents":   false,
    "neighboringComponents": false,
    "showFullComponent":     false
  }
}
EOF
)
    req=$(echo $req | jq --arg stql "$stql" '.query = "\($stql)"')
    curl -s -k -H "Authorization: ApiKey $service_token" -H "Content-Type: application/json" -X POST -d "$req" $url/api/snapshot
}
