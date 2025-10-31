appco_create_token() {
    local appco_user=$1
    local appco_password=$2
    local appco_org=$3
    local sandbox_id=$4
    
    local token_json=$(curl --retry 50 --retry-max-time 6000 -sS -X POST \
        --url https://api.apps.rancher.io/v1/service-accounts \
        --header 'Accept: application/json' \
        -u "${appco_user}:${appco_password}" \
        --header 'Content-Type: application/json' \
        --data "{\"description\": \"Service account for $sandbox_id\",\"organization_id\": $appco_org}")
    echo "$token_json"
}

appco_delete_token() {
    local appco_user=$1
    local appco_password=$2
    local token_username=$3

    curl --retry 50 --retry-max-time 6000 -X DELETE \
        -H "Content-Type: application/json" \
        --user "${appco_user}:${appco_password}" \
        --url https://api.apps.rancher.io/v1/service-accounts/${token_username}
}