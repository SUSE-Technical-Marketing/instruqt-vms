install_tooling() {
    local k9s_version="$1"
    zypper in -y helm
    zypper install -y https://download.opensuse.org/repositories/utilities/15.6/x86_64/yq-4.44.6-lp156.42.1.x86_64.rpm

    # support tools
    rpm -Uvh https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_linux_amd64.rpm
}
