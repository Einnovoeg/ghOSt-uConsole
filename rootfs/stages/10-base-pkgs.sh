#!/usr/bin/env bash
# Stage 10: base packages + Pi/RPi + ClockworkPi apt feeds in chroot.
# Mirrors rg35xxh 10-base-pkgs.sh chroot helper (bind proc/sys/dev, resolv.conf, trap).
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

run_chroot() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  cp /etc/resolv.conf "$ROOTFS/etc/"
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run_chroot "
  locale-gen
  mkdir -p /usr/share/keyrings /etc/apt/sources.list.d

  # Raspberry Pi feed (pinned key, arm64)
  echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.gpg] $RPI_MIRROR $DEBIAN_RELEASE main' > /etc/apt/sources.list.d/raspi.list
  curl -fsSL --retry 5 --retry-delay 3 '$RPI_KEY_URL' | gpg --batch --yes --dearmor -o /usr/share/keyrings/raspberrypi-archive-keyring.gpg || echo '[warn] RPi key fetch failed, continuing with Debian only'

  # ClockworkPi feed (community uConsole kernel/overlays; may be unreachable — non-fatal)
  echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/clockworkpi-archive-keyring.gpg] $CLOCKWORKPI_APT_URL stable main' > /etc/apt/sources.list.d/clockworkpi.list || true
  curl -fsSL --retry 3 --retry-delay 3 '$CLOCKWORKPI_APT_KEY_URL' | gpg --batch --yes --dearmor -o /usr/share/keyrings/clockworkpi-archive-keyring.gpg || {
    echo '[warn] ClockworkPi key unreachable, disabling feed for this build'
    rm -f /etc/apt/sources.list.d/clockworkpi.list
  }

  echo 'Acquire::http::Timeout \"30\";' > /etc/apt/apt.conf.d/99timeout
  echo 'Acquire::Retries \"5\";' >> /etc/apt/apt.conf.d/99timeout
  apt-get update || apt-get update --fix-missing || true

  apt-get install -y --no-install-recommends \
    linux-base initramfs-tools \
    e2fsprogs dosfstools parted gdisk \
    openssh-server cron rsync wget curl gnupg2 \
    network-manager dnsmasq-base \
    bluez bluez-tools rfkill \
    python3 python3-pip \
    upower brightnessctl \
    sudo passwd login \
    locales tzdata keyboard-configuration console-setup \
    bmap-tools || true

  systemctl enable ssh || true
  systemctl enable NetworkManager || true
"
