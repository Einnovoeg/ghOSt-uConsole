#!/usr/bin/env bash
# Stage 20: GUI (Cage/Wayland + ghOSt launcher deps) + ghost user + autologin.
# Adapted from rg35xxh 20-xfce.sh (user creation + autologin pattern).
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run "
  apt-get install -y --no-install-recommends \
    cage weston wayland-utils \
    pipewire pipewire-pulse pipewire-audio wireplumber \
    libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev \
    python3-sdl2 python3-evdev \
    fish tmux micro vim \
    fonts-terminus grim slurp \
    || true

  # Create ghost user (robust against stale UID 1000 from bad passwd copies)
  if ! id -u $TARGET_USER >/dev/null 2>&1; then
    for g in sudo audio video input plugdev netdev bluetooth dialout render; do
      getent group \$g >/dev/null 2>&1 || groupadd -r \$g
    done
    if getent passwd $TARGET_UID >/dev/null 2>&1; then
      userdel \$(getent passwd $TARGET_UID | cut -d: -f1) 2>/dev/null || sed -i '/^[^:]*:[^:]*:$TARGET_UID:/d' /etc/passwd || true
    fi
    useradd -m -u $TARGET_UID -s /bin/bash -G sudo,audio,video,input,plugdev,netdev,bluetooth,dialout,render $TARGET_USER \
      || useradd -m -s /bin/bash -G sudo,audio,video,input,plugdev,netdev,bluetooth,dialout,render $TARGET_USER
    echo '$TARGET_USER ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-$TARGET_USER
    chmod 440 /etc/sudoers.d/90-$TARGET_USER
    passwd -d $TARGET_USER 2>/dev/null || true
  fi

  # getty autologin to ghost (Pi has no LightDM here; Cage starts via ghost-gui.service)
  mkdir -p /etc/systemd/system/getty@tty1.service.d
  cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $TARGET_USER --noclear %I \\\$TERM
EOF
"
