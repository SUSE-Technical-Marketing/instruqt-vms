#!/bin/bash
# config.sh - Runs inside the image root during build (chroot)
# No dbus, no systemd, no network available here.
# Static files are handled by the root/ overlay tree.

set -euo pipefail

#======================================
# Pre-import GPG keys for all repos so zypper never prompts interactively
#--------------------------------------
zypper --gpg-auto-import-keys refresh

#======================================
# Fix permissions on SSH keys and sudoers
# (overlay copies files but doesn't set mode)
#--------------------------------------
chmod 700 /home/jeroen/.ssh
chmod 600 /home/jeroen/.ssh/authorized_keys
chown -R jeroen:users /home/jeroen/.ssh

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

chmod 440 /etc/sudoers.d/jeroen
chmod +x /usr/local/bin/configure-firewall.sh

#======================================
# Enable systemd units
# (systemctl enable works in chroot - just creates symlinks)
#--------------------------------------
systemctl enable NetworkManager.service
systemctl enable cloud-init-local.service
systemctl enable cloud-init.service
systemctl enable cloud-config.service
systemctl enable cloud-final.service
systemctl enable firewalld.service
systemctl enable iscsid.service
systemctl enable qemu-guest-agent.service
systemctl enable configure-firewall.service


