#!/usr/bin/env bash
# Smoke boot-test for ghOSt-uConsole image (no hardware required).
# Mounts the .img via loop+kpartx and checks: partition layout + labels,
# Pi boot files, rootfs essentials, ghost user, enabled services, launcher.
# QEMU full-system boot of CM4/CM5 firmware is not reliable in CI, so this
# static + chroot smoke is the gate before hardware flash.
#
# Usage: sudo scripts/smoke-boot-test.sh dist/ghOSt-uConsole-*.img
set -euo pipefail
IMG="${1:-}"
[ -n "$IMG" ] || { echo "usage: $0 <image.img>"; exit 2; }
[ -f "$IMG" ] || { echo "image not found: $IMG"; exit 2; }
[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }

pass=0; fail=0
ok()   { echo "[ok] $*"; pass=$((pass+1)); }
bad()  { echo "[FAIL] $*"; fail=$((fail+1)); }

echo "[smoke] image: $IMG ($(du -h "$IMG" | cut -f1))"

# 1. Partition layout
echo "[smoke] partition table:"
parted -s "$IMG" print || { bad "parted print failed"; }
if parted -s "$IMG" print | grep -qi 'msdos'; then ok "MBR (DOS) label"; else bad "expected MBR label"; fi

LOOP=$(losetup --find --show "$IMG")
KPMAP=$(basename "$LOOP")
trap 'kpartx -d "$LOOP" 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true' EXIT
kpartx -a -s "$LOOP"
udevadm settle || true
P1=/dev/mapper/${KPMAP}p1
P2=/dev/mapper/${KPMAP}p2
for i in $(seq 1 10); do [ -b "$P2" ] && break; sleep 1; udevadm settle || true; done
[ -b "$P1" ] && ok "p1 block device ($P1)" || bad "p1 missing"
[ -b "$P2" ] && ok "p2 block device ($P2)" || bad "p2 missing"

# 2. Filesystem labels (must match fstab LABEL=GHOST_BOOT/GHOST_ROOT)
L1=$(blkid -s LABEL -o value "$P1" 2>/dev/null || true)
L2=$(blkid -s LABEL -o value "$P2" 2>/dev/null || true)
[ "$L1" = "GHOST_BOOT" ] && ok "p1 label GHOST_BOOT" || bad "p1 label is '$L1' (want GHOST_BOOT)"
[ "$L2" = "GHOST_ROOT" ] && ok "p2 label GHOST_ROOT" || bad "p2 label is '$L2' (want GHOST_ROOT)"

# 3. Mount and inspect
MNT=$(mktemp -d)
mount -o ro "$P2" "$MNT"
mkdir -p "$MNT/boot/firmware"
mount -o ro "$P1" "$MNT/boot/firmware"

[ -f "$MNT/boot/firmware/config.txt" ] && ok "config.txt" || bad "config.txt missing"
[ -f "$MNT/boot/firmware/cmdline.txt" ] && ok "cmdline.txt" || bad "cmdline.txt missing"
ls "$MNT/boot"/kernel*.img "$MNT/boot/firmware"/kernel*.img 2>/dev/null | head -1 | grep -q . \
  && ok "kernel Image ($(ls "$MNT/boot"/kernel*.img "$MNT/boot/firmware"/kernel*.img 2>/dev/null | head -1))" \
  || bad "kernel Image missing"
ls "$MNT/boot"/*.dtb "$MNT/boot/firmware"/*.dtb 2>/dev/null | head -1 | grep -q . \
  && ok "DTB present" || bad "DTB missing"
grep -q 'root=LABEL=GHOST_ROOT' "$MNT/boot/firmware/cmdline.txt" 2>/dev/null \
  && ok "cmdline root=LABEL=GHOST_ROOT" || bad "cmdline root wrong"
grep -q 'console=tty1' "$MNT/boot/firmware/cmdline.txt" 2>/dev/null \
  && ok "cmdline console=tty1" || bad "cmdline console missing"
[ -f "$MNT/etc/fstab" ] && grep -q 'LABEL=GHOST_ROOT' "$MNT/etc/fstab" \
  && ok "fstab LABEL-based" || bad "fstab wrong"
[ -f "$MNT/etc/hostname" ] && ok "hostname: $(cat "$MNT/etc/hostname")" || bad "hostname missing"
[ -f "$MNT/sbin/init" ] || [ -L "$MNT/sbin/init" ] || [ -f "$MNT/lib/systemd/systemd" ] \
  && ok "init/systemd present" || bad "/sbin/init missing"

# 4. Chroot checks (user, services, launcher) — needs qemu on x86_64 runners
if command -v qemu-aarch64-static >/dev/null 2>&1; then
  cp "$(command -v qemu-aarch64-static)" "$MNT/usr/bin/" 2>/dev/null || true
  for m in proc sys dev; do mount --bind /$m "$MNT/$m" 2>/dev/null || true; done
  chroot "$MNT" /bin/bash -c "id ghost" >/dev/null 2>&1 \
    && ok "user ghost exists ($(chroot "$MNT" /bin/bash -c 'id -u ghost' 2>/dev/null))" \
    || bad "user ghost missing"
  chroot "$MNT" /bin/bash -c "test -f /etc/systemd/system/ghost-expand-fs.service" >/dev/null 2>&1 \
    && ok "ghost-expand-fs.service" || bad "expand service missing"
  chroot "$MNT" /bin/bash -c "python3 -m py_compile /opt/ghost/launcher/launcher.py" >/dev/null 2>&1 \
    && ok "launcher.py compiles" || bad "launcher.py broken"
  chroot "$MNT" /bin/bash -c "python3 -m py_compile /opt/ghost/stealthd/stealthd.py /opt/ghost/hey/hey.py" >/dev/null 2>&1 \
    && ok "stealthd/hey compile" || bad "stealthd/hey broken"
  for m in dev sys proc; do umount -l "$MNT/$m" 2>/dev/null || true; done
  rm -f "$MNT/usr/bin/qemu-aarch64-static"
else
  echo "[warn] qemu-aarch64-static missing, skipping chroot checks"
fi

umount "$MNT/boot/firmware" 2>/dev/null || true
umount "$MNT" 2>/dev/null || true
rmdir "$MNT"
kpartx -d "$LOOP" 2>/dev/null || true
losetup -d "$LOOP"; trap - EXIT

echo "[smoke] pass=$pass fail=$fail"
[ "$fail" = 0 ]
