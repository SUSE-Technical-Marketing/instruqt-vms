install_sbom_scanner() {
    echo ">> Install Cloud Native Postgres Operator"
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    helm repo update
    helm install cnpg \
    --namespace cnpg-system \
    --create-namespace \
    --wait \
    cnpg/cloudnative-pg

    echo ">> Install SBOM Scanner Polaris"
    helm repo add kubewarden https://charts.kubewarden.io
    helm repo update
    helm install sbomscanner kubewarden/sbomscanner \
    --namespace sbomscanner \
    --create-namespace \
    --set controller.replicas=1 \
    --set storage.replicas=1 \
    --set storage.postgres.cnpg.instances=1 \
    --set worker.replicas=1 \
    --wait
}