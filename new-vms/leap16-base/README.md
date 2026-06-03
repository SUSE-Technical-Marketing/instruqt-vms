# leap16-base KIWI Image

openSUSE Leap 16.0 base qcow2 image for Harvester VMs.

## What's included

- Full `kernel-default` (not `kernel-default-base`) — all modules including `iscsi_tcp`
- `openSUSE-repos-Leap` for proper repo management
- `cloud-init` — enabled, so per-VM customization still works on top of this base
- `firewalld` — pre-configured with k8s ports (6443, pod/service CIDRs)
- `open-iscsi` / `cryptsetup` — storage prerequisites
- `qemu-guest-agent` — Harvester VM integration
- `k3s-selinux` — SELinux policy for k3s
- Tooling: `helm`, `kubernetes-client`, `k9s`, `fastfetch`, `btop`, `vim`, `git`, etc.
- User `jeroen` with sudo, SSH key, bcrypt password baked in
- IPv6 disabled via sysctl
- inotify limits tuned for Kubernetes
- `iscsi_tcp` module loaded via `modules-load.d`

## Directory structure

```
leap16-base/
├── config.xml          # KIWI image description (packages, repos, type)
├── config.sh           # Runs at build time in chroot (systemd enables, sudoers, SSH keys)
├── build.sh            # Build runner (uses podman)
└── root/               # Overlay tree - copied verbatim into the image
    └── etc/
        ├── rancher/k3s/config.yaml
        ├── sysctl.d/99-disable-ipv6.conf
        ├── modules-load.d/iscsi.conf
        ├── bash.bashrc.local
        └── zypp/repos.d/devel-kubic.repo
```

## Building

Run on a Linux host (or a VM on polaris) with podman:

```bash
./build.sh
# or specify output directory:
./build.sh /var/lib/images/output
```

The build needs `--privileged` for loop device access. This is a hard KIWI requirement
for disk image builds — it cannot run on macOS directly.

Output: `_output/leap16-base.x86_64-1.0.0.qcow2`

## Uploading to Harvester

```bash
# Via Harvester UI: Virtual Machine Images → Create → URL or upload
# Via API:
curl -k -X POST https://HARVESTER_VIP/apis/harvesterhci.io/v1beta1/namespaces/default/virtualmachineimages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "metadata": {"name": "leap16-base"},
    "spec": {
      "displayName": "openSUSE Leap 16 Base",
      "sourceType": "upload"
    }
  }'
```

## cloud-init on top

Because `cloud-init` is installed and enabled in the image, you can still pass
per-VM user-data from Harvester for anything that needs to happen at first boot
(hostname, k3s install, Rancher setup, etc.). The base image handles everything
that doesn't need a running system.

## Notes

- The `devel-kubic` repo has `gpgcheck=0` — fine for a lab, harden for production.
- `firewall-cmd --permanent` rules are written at build time; firewalld applies them on first boot.
- The bcrypt password hash in `config.xml` is for the `jeroen` user. Replace as needed.
- SELinux is enforcing by default on Leap 16. The `k3s-selinux` package provides the
  correct policy so k3s binaries in `/usr/local/bin` are properly labeled at install time.
