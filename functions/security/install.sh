security_values() {
  local hostname=$1
  local rancher_url=$2
  local username=${3:-admin}
  local password=${4:-admin}

  cat << EOF > neuvector-values.yaml
global:
  cattle:
    url: ${rancher_url}
    systemDefaultRegistry: registry.rancher.com
  systemDefaultRegistry: registry.rancher.com
registry: registry.rancher.com
manager:
  ingress:
    enabled: true
    tls: true
    env:
      ssl: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      kubernetes.io/ingress.class: nginx
    host: ${hostname}
    secretName: neuvector-tls
  svc:
    type: ClusterIP
k3s:
  enabled: true
  runtimePath: /run/k3s/containerd/containerd.sock
controller:
  replicas: 1
  prime:
    enabled: true
  federation:
    mastersvc:
      type: ClusterIP
  pvc:
    enabled: false
  ranchersso:
    enabled: true
  configmap:
    enabled: true
    data:
      passwordprofileinitcfg.yaml: |
        active_profile_name: default
        pwd_profiles:
        # only default profile is supported.
        - name: default
          comment: default from configMap
          min_len: 6
          min_uppercase_count: 0
          min_lowercase_count: 0
          min_digit_count: 0
          min_special_count: 0
          enable_block_after_failed_login: false
          block_after_failed_login_count: 0
          block_minutes: 0
          enable_password_expiration: false
          password_expire_after_days: 0
          enable_password_history: false
          password_keep_history_count: 0
          # Optional. value between 30 -- 3600  default 300
          session_timeout: 3600
      sysinitcfg.yaml: |
        New_Service_Profile_Baseline: basic
        Auth_By_Platform: true
        Cluster_Name: myclu
      userinitcfg.yaml: |
        users:
        - Fullname: ${username}
          Password: ${password}
          Role: admin
          Timeout: 3600
cve:
  scanner:
    enabled: true
    replicas: 1
scanner:
  enabled: true
  replicas: 1
rbac: true
EOF
}

security_install() {
  local version=$1
  helm repo add rancher-charts https://charts.rancher.io
  helm repo update
  helm install neuvector-crd --namespace cattle-neuvector-system --create-namespace rancher-charts/neuvector-crd --version=${version}
  helm upgrade -i \
    neuvector \
    rancher-charts/neuvector --version=$version \
    --namespace cattle-neuvector-system \
    --labels=catalog.cattle.io/cluster-repo-name=rancher-charts \
    --create-namespace \
    -f neuvector-values.yaml
}

# neuvector_accept_eula() {
#   local username=${1:-admin}
#   local password=${2:-admin}

#   neuvector_ip=$(kubectl get svc neuvector-svc-controller-api -n cattle-neuvector-system -o jsonpath='{.spec.clusterIP}')

#   curl $curl_extras -k -H "Content-Type: application/json" -d '{"password": {"username": "'$username'", "password": "'$password"}}' "https://${_nv_ip}:10443/v1/auth" > /dev/null 2>&1 > token.json
# _TOKEN_=`cat token.json | jq -r '.token.token'`


# curl $curl_extras -s -k -H 'Content-Type: application/json' -H "X-Auth-Token: ${_TOKEN_}" -d '{"eula":{"accepted":true}}' https://${_nv_ip}:10443/v1/eula

# }
