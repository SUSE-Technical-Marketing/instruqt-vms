install_tooling() {
    local k9s_version="$1"
    zypper addrepo https://download.opensuse.org/repositories/openSUSE:Factory/standard/openSUSE:Factory.repo
    zypper refresh
    zypper in -y helm yq

    # support tools
    rpm -Uvh https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_linux_amd64.rpm
}
