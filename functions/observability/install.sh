observability_add_helm_repo() {
    helm repo add suse-observability https://charts.rancher.com/server-charts/prime/suse-observability
    helm repo update
}

observability_generate_values() {
    local license=$1
    local host=$2
    local admin_password=$3
    local service_token=$4

    local values_dir=.

    helm template --set license=$license \
        --set baseUrl="https://$host" \
        --set adminPassword=$admin_password \
        --set sizing.profile=trial \
        suse-observability-values suse-observability/suse-observability-values \
        --output-dir $values_dir

    rm -f $values_dir/suse-observability-values/templates/ingress_values.yaml
    cat << EOF > $values_dir/suse-observability-values/templates/ingress_values.yaml
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
  ingressClassName: nginx
  hosts:
    - host: $host
  tls:
    - hosts:
        - $host
      secretName: tls-secret
EOF

    rm -f $values_dir/suse-observability-values/templates/bootstrap_token.yaml
    cat << EOF > $values_dir/suse-observability-values/templates/bootstrap_token.yaml
stackstate:
  authentication:
    serviceToken:
      bootstrap:
        token: $service_token
        roles: ["stackstate-k8s-troubleshooter", "stackstate-admin", "stackstate-k8s-admin"]
EOF

    rm -f $values_dir/suse-observability-values/templates/experimental_values.yaml
    cat << EOF > $values_dir/suse-observability-values/templates/experimental_values.yaml
stackstate:
  deployment:
    mode: SelfHosted
    edition: "Prime"
  components:
    all:
      deploymentStrategy:
        type: Recreate
      extraEnv:
        open:
          CONFIG_FORCE_stackgraph_retentionWindowMs: "86400000"
          CONFIG_FORCE_stackstate_traces_retentionDays: "1"
          CONFIG_FORCE_stackstate_featureSwitches_monitorEnableExperimentalAPIs: "true"
    server:
      config: |
        stackstate.webUIConfig.defaultTimeRange: "LAST_1_HOUR"
    e2es:
      retention: 1
    receiver:
      extraEnv:
        open:
          CONFIG_FORCE_stackstate_receiver_processAgent_maxConnectionObservationsPerHost: "15000000"
          CONFIG_FORCE_stackstate_receiver_processAgent_maxComponentsPerHost: "1000000"
          CONFIG_FORCE_stackstate_receiver_processAgent_maxRelationsPerHost: "1000000"
          CONFIG_FORCE_stackstate_receiver_processAgent_maxNewRelationsHourlyPerHost: "1000000"
          CONFIG_FORCE_stackstate_receiver_processAgent_maxNewComponentsHourlyPerHost: "1000000"
      retention: 1
      # The receiver has by default an unavailability of 0, meaning that the new one should be present before killing the old one, this breaks in our tiny setup.
      poddisruptionbudget:
        maxUnavailable: 1
    state:
      config: |
        stackstate.stateService.defaultPropagation = Transparent
victoria-metrics-0:
  backup:
    enabled: false
clickhouse:
  enabled: true
  backup:
    enabled: false
backup:
  enabled: false
  configuration:
    scheduled:
      enabled: false
EOF
}

observability_install_server() {
    local version=$1
    local values_dir=.
    local wait=${2:-false}

    if [ "$wait" = "true" ]; then
        wait_opts="--wait --timeout 300s"
    else
        wait_opts=""
    fi
    helm upgrade --install --namespace suse-observability --create-namespace \
        $wait_opts \
        --version $version \
        --values $values_dir/suse-observability-values/templates/baseConfig_values.yaml \
        --values $values_dir/suse-observability-values/templates/experimental_values.yaml \
        --values $values_dir/suse-observability-values/templates/sizing_values.yaml \
        --values $values_dir/suse-observability-values/templates/ingress_values.yaml \
        --values $values_dir/suse-observability-values/templates/bootstrap_token.yaml \
        suse-observability suse-observability/suse-observability
}

observability_wait_for_pods() {
    local namespace="suse-observability"
    echo ">>> Waiting for Observability Pods to be available..."

    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=suse-observability -n $namespace --timeout=300s
}
