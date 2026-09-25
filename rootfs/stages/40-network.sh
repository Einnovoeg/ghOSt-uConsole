#!/usr/bin/env bash
# Stage 40: network helpers (NetworkManager, Bluetooth, Tor, Tailscale optional).
# Mirrors rg35xxh 40-network.sh.
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run '
  apt-get install -y --no-install-recommends \
    network-manager-openvpn wireguard wireguard-tools \
    tor torsocks proxychains4 \
    bluetooth bluez-tools \
    || true
  systemctl enable bluetooth || true
  systemctl enable tor || true
'
