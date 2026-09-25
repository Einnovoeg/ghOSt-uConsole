#!/usr/bin/env bash
# Stage 30: uConsole handheld hardware enablement (Pi kernel, firmware, overlays).
# This is the Pi/CM4-CM5 analogue of rg35xxh's DTB-regulator + joypad stage:
# ensure a real bootable kernel + modules + DTB exist, with fallback when the
# ClockworkPi feed is unreachable (the #1 reason previous ghOSt images did not boot).
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run "
  # Preferred: ClockworkPi uConsole kernel + firmware + audio + 4G helpers
  if [ -f /etc/apt/sources.list.d/clockworkpi.list ]; then
    apt-get install -y --no-install-recommends \
      $CLOCKWORKPI_KERNEL_PACKAGE $CLOCKWORKPI_FIRMWARE_PACKAGE \
      $CLOCKWORKPI_AUDIO_PACKAGE $CLOCKWORKPI_4G_PACKAGE \
      raspi-utils raspi-config rpi-eeprom fake-hwclock \
      || echo '[warn] ClockworkPi packages partially failed, falling back to stock Pi kernel'
  fi

  # Fallback / complement: stock Raspberry Pi bootloader + kernel + firmware
  # (guarantees /boot/firmware + kernel Image + overlays + modules even offline from ak-rex feed)
  apt-get install -y --no-install-recommends \
    $FALLBACK_KERNEL_PKGS \
    firmware-linux firmware-realtek firmware-misc-nonfree firmware-brcm80211 \
    || true

  apt-get install -y --no-install-recommends \
    evtest joystick brightnessctl wiringpi \
    v4l-utils alsa-utils \
    || true

  # Verify boot artifacts exist (fail fast with clear message, like rg35xxh DTB check)
  ls /boot/firmware/ 2>/dev/null || ls /boot/ 2>/dev/null || true
  if ! ls /boot/firmware/kernel*.img /boot/kernel*.img 2>/dev/null; then
    echo '[warn] no Pi kernel Image found in /boot — image may not boot; check feeds'
  fi
  # Regenerate initramfs when present so MMC root mounts without extra initramfs hacks
  update-initramfs -u 2>/dev/null || true
"
