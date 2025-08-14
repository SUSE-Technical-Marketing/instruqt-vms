install_tooling() {
    local k9s_version="$1"
    curl -sSfL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq
    curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/bin/kubectl && chmod +x /usr/bin/kubectl

    zypper in -y helm jq

    # support tools
    rpm -Uvh https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_linux_amd64.rpm
}
