#!/usr/bin/env bash
# ghOSt-uConsole image smoke test (no hardware required).
# Loop-mounts the assembled GPT image and verifies the CM4 Lite SD-boot chain:
# partition layout + labels, Pi firmware files, kernel, cmdline/fstab wiring,
# ghost user, first-boot + GUI services, launcher code.
#
# Usage: sudo scripts/smoke-test-image.sh <image.img>
set -euo pipefail
IMG="${1:-}"
[ -n "$IMG" ] || { echo "usage: $0 <image.img>"; exit 2; }
[ -f "$IMG" ] || { echo "image not found: $IMG"; exit 2; }
[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }

pass=0; fail=0
ok()  { echo "[smoke-ok] $*"; pass=$((pass+1)); }
bad() { echo "[smoke-FAIL] $*"; fail=$((fail+1)); }

echo "[smoke] image: $IMG ($(du -h "$IMG" | cut -f1))"

parted -s "$IMG" print || { bad "parted print failed"; exit 1; }
parted -s "$IMG" print | grep -qi 'gpt' && ok "GPT label" || bad "expected GPT label"

LOOP=$(losetup --find --show -P "$IMG")
trap 'losetup -d "$LOOP" 2>/dev/null || true' EXIT
sleep 2
P1="${LOOP}p1"; P2="${LOOP}p2"; P3="${LOOP}p3"
for i in $(seq 1 10); do [ -b "$P3" ] && break; sleep 1; done
[ -b "$P1" ] && ok "p1 boot device" || bad "p1 missing"
[ -b "$P2" ] && ok "p2 root device" || bad "p2 missing"
[ -b "$P3" ] && ok "p3 swap device" || bad "p3 missing (4GB CM4 swap)"

[ "$(blkid -s LABEL -o value "$P1" 2>/dev/null)" = "GHOST_BOOT" ] \
  && ok "p1 label GHOST_BOOT" || bad "p1 label wrong"
[ "$(blkid -s LABEL -o value "$P2" 2>/dev/null)" = "GHOST_ROOT" ] \
  && ok "p2 label GHOST_ROOT" || bad "p2 label wrong"

MNT=$(mktemp -d)
mount -o ro "$P2" "$MNT"
mkdir -p "$MNT/boot/firmware"
mount -o ro "$P1" "$MNT/boot/firmware"

[ -f "$MNT/boot/firmware/config.txt" ] && ok "config.txt" || bad "config.txt missing"
[ -f "$MNT/boot/firmware/cmdline.txt" ] && ok "cmdline.txt" || bad "cmdline.txt missing"
grep -q 'dtoverlay=clockworkpi-uconsole' "$MNT/boot/firmware/config.txt" 2>/dev/null \
  && ok "uConsole overlay in config.txt" || bad "uConsole overlay missing from config.txt"
if compgen -G "$MNT/boot/firmware/kernel*.img" > /dev/null \
  || compgen -G "$MNT/boot/firmware/vmlinuz*" > /dev/null; then
  ok "kernel in FAT view ($(compgen -G "$MNT/boot/firmware/kernel*.img" | head -1))"
else
  bad "no kernel in /boot/firmware"
fi
if grep -q 'ROOTDEV' "$MNT/boot/firmware/cmdline.txt" 2>/dev/null; then
  bad "cmdline still has ROOTDEV placeholder"
else
  grep -q 'root=PARTUUID=' "$MNT/boot/firmware/cmdline.txt" 2>/dev/null \
    && ok "cmdline root=PARTUUID wired" || bad "cmdline root device wrong"
fi
grep -q 'console=tty1' "$MNT/boot/firmware/cmdline.txt" 2>/dev/null \
  && ok "cmdline console=tty1" || bad "cmdline console missing"
if grep -qE 'BOOT_UUID|ROOT_UUID|SWAP_UUID' "$MNT/etc/fstab" 2>/dev/null; then
  bad "fstab still has UUID placeholders"
else
  grep -q 'GHOST_ROOT' "$MNT/etc/fstab" 2>/dev/null \
    && ok "fstab UUIDs filled" || bad "fstab wrong"
fi
[ -f "$MNT/etc/hostname" ] && ok "hostname: $(tr -d '\n' < "$MNT/etc/hostname")" || bad "hostname missing"
{ [ -f "$MNT/sbin/init" ] || [ -L "$MNT/sbin/init" ] || [ -f "$MNT/lib/systemd/systemd" ]; } \
  && ok "init/systemd present" || bad "/sbin/init missing"

if command -v qemu-aarch64-static >/dev/null 2>&1; then
  cp "$(command -v qemu-aarch64-static)" "$MNT/usr/bin/" 2>/dev/null || true
  for m in proc sys dev; do mount --bind /$m "$MNT/$m" 2>/dev/null || true; done
  chroot "$MNT" /bin/bash -c "id ghost" >/dev/null 2>&1 \
    && ok "user ghost exists" || bad "user ghost missing"
  chroot "$MNT" /bin/bash -c "test -f /etc/systemd/system/ghost-expand-fs.service" >/dev/null 2>&1 \
    && ok "ghost-expand-fs.service" || bad "expand service missing"
  chroot "$MNT" /bin/bash -c "test -f /etc/systemd/system/firstboot.service" >/dev/null 2>&1 \
    && ok "firstboot.service" || bad "firstboot service missing"
  chroot "$MNT" /bin/bash -c "test -f /etc/systemd/system/ghost-gui.service" >/dev/null 2>&1 \
    && ok "ghost-gui.service" || bad "ghost-gui service missing"
  chroot "$MNT" /bin/bash -c "python3 -m py_compile /opt/ghost/launcher/launcher.py" >/dev/null 2>&1 \
    && ok "launcher.py compiles" || bad "launcher.py broken"
  for m in dev sys proc; do umount -l "$MNT/$m" 2>/dev/null || true; done
  rm -f "$MNT/usr/bin/qemu-aarch64-static"
else
  echo "[smoke] qemu-aarch64-static missing, skipping chroot checks"
fi

umount "$MNT/boot/firmware" 2>/dev/null || true
umount "$MNT" 2>/dev/null || true
rmdir "$MNT"
losetup -d "$LOOP"; trap - EXIT

echo "[smoke] pass=$pass fail=$fail"
[ "$fail" = 0 ]
