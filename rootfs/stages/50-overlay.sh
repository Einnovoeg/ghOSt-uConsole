#!/usr/bin/env bash
# Stage 50: copy overlay/ verbatim into rootfs, enable services, write LABEL fstab.
# Ported from rg35xxh 50-overlay.sh (rsync + systemctl enable + journal dir + LABEL fstab).
set -euo pipefail
ROOTFS="$1"
OVERLAY="$2"
. "$(dirname "$0")/../../VERSIONS"

rsync -aHAX --chown=root:root "$OVERLAY/" "$ROOTFS/"

# Make scripts executable
chmod +x "$ROOTFS"/usr/local/bin/* 2>/dev/null || true
chmod +x "$ROOTFS"/usr/local/sbin/* 2>/dev/null || true
chmod +x "$ROOTFS"/opt/ghost/scripts/*.sh 2>/dev/null || true
chmod +x "$ROOTFS"/opt/ghost/launcher/*.py 2>/dev/null || true

run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run "
  systemctl enable ghost-expand-fs.service || true
  systemctl enable firstboot.service || true
  systemctl enable stealthd.service || true
  systemctl enable ghost-gui.service || true
  systemctl enable intercept.service || true
  systemctl enable cyberchef.service || true
  systemctl enable ssh || true
  systemctl enable NetworkManager || true
  systemctl set-default graphical.target || true
"

# Persistent journal dir (like reference)
install -d -o root -g 100 -m 2755 "$ROOTFS/var/log/journal" 2>/dev/null || \
  mkdir -p "$ROOTFS/var/log/journal"

# fstab — LABEL-based (set in pack-image.sh), tmpfs for SD longevity.
# Replaces fragile BOOT_UUID/ROOT_UUID sed placeholders in legacy assemble_image.
cat > "$ROOTFS/etc/fstab" <<EOF
LABEL=GHOST_BOOT  /boot/firmware  vfat  defaults,noatime,fmask=0022,dmask=0022  0 2
LABEL=GHOST_ROOT  /               ext4  defaults,noatime,nodiratime,commit=600,errors=remount-ro  0 1
tmpfs             /tmp            tmpfs defaults,nosuid,nodev,size=128M  0 0
tmpfs             /var/tmp        tmpfs defaults,nosuid,nodev,size=64M   0 0
EOF
