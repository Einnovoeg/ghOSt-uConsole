#!/usr/bin/env bash
# Compose final uConsole SD image: MBR, FAT boot p1 (/boot/firmware), ext4 root p2.
# Ported from rg35xxh-cyberdeck/image/pack-image.sh, adapted for Raspberry Pi
# firmware boot (no SPL @8KB; Pi ROM reads FAT directly).
#
# Usage: sudo image/pack-image.sh <WORKDIR> <DISTDIR>
#   WORKDIR contains: rootfs/ kernel/boot-firmware/
#   DISTDIR receives: ghOSt-uConsole-<rev>.img + .bmap + .img.xz + SHA256SUMS
set -euo pipefail
WORK="$1"
DIST="$2"
. "$(dirname "$0")/../VERSIONS"

[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }

REV="$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d)"
IMG="$DIST/ghOSt-uConsole-${REV}.img"
SIZE_BYTES=$(( IMAGE_SIZE_GB * 1024 * 1024 * 1024 ))

echo "[pack] creating $IMG (${IMAGE_SIZE_GB} GB)"
mkdir -p "$DIST"
rm -f "$IMG"
truncate -s "$SIZE_BYTES" "$IMG"

# MBR layout (like reference; avoids GPT-header quirks, Pi firmware happy with MBR):
#   p1 FAT 256MB @16MiB -> /boot/firmware, p2 ext4 rest -> /
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 16MiB 272MiB
parted -s "$IMG" mkpart primary ext4  272MiB 100%
parted -s "$IMG" set 1 boot on

LOOP=$(losetup --find --show "$IMG")
KPMAP=$(basename "$LOOP")
trap 'kpartx -d "$LOOP" 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true' EXIT
kpartx -a -s "$LOOP"
udevadm settle || true
P1=/dev/mapper/${KPMAP}p1
P2=/dev/mapper/${KPMAP}p2
for i in 1 2 3 4 5; do
  [ -b "$P2" ] && break
  sleep 1
  udevadm settle || true
done
[ -b "$P2" ] || { echo "kpartx failed to create $P2"; ls -la /dev/mapper/; exit 1; }

echo "[pack] formatting (GHOST_BOOT / GHOST_ROOT labels match fstab)"
mkfs.vfat -F 32 -n GHOST_BOOT "$P1"
mkfs.ext4 -F -L GHOST_ROOT "$P2"

MNT=$(mktemp -d)
mount "$P2" "$MNT"
mkdir -p "$MNT/boot/firmware"
mount "$P1" "$MNT/boot/firmware"

# Staged Pi boot config (config.txt/cmdline.txt from kernel stage)
if [ -d "$WORK/kernel/boot-firmware" ]; then
  cp -a "$WORK/kernel/boot-firmware/"* "$MNT/boot/firmware/" 2>/dev/null || true
fi
# Kernel + DTB + overlays already live under rootfs /boot/firmware via apt;
# copy them into the FAT partition view (same files, bind-equivalent for first boot)
if [ -d "$WORK/rootfs/boot/firmware" ]; then
  rsync -a "$WORK/rootfs/boot/firmware/" "$MNT/boot/firmware/" || true
fi

# Rootfs (exclude the FAT-mounted boot view to avoid duplication)
rsync -aHAX "$WORK/rootfs/" "$MNT/" --exclude=/boot/firmware/\* --exclude=/boot/\*

# Ensure cmdline uses LABEL root (robust across SD readers; PARTUUID varies)
if [ -f "$MNT/boot/firmware/cmdline.txt" ]; then
  sed -i 's|root=[^ ]*|root=LABEL=GHOST_ROOT|' "$MNT/boot/firmware/cmdline.txt"
  # console ordering pitfall (rg35xxh PITFALLS #3): screen must be last
  if ! grep -q 'console=tty1' "$MNT/boot/firmware/cmdline.txt"; then
    sed -i 's|$| console=tty1|' "$MNT/boot/firmware/cmdline.txt"
  fi
fi

sync
umount "$MNT/boot/firmware"
umount "$MNT"
rmdir "$MNT"
kpartx -d "$LOOP" 2>/dev/null || true
losetup -d "$LOOP"; trap - EXIT

echo "[pack] creating bmap"
bmaptool create -o "$IMG.bmap" "$IMG" || echo "[warn] bmaptool failed, continuing"

echo "[pack] compressing -> ${IMG}.xz"
xz -T 0 -6 -k "$IMG"
ls -lh "$IMG"*
(cd "$DIST" && sha256sum "$(basename "$IMG").xz" "$(basename "$IMG").bmap" > SHA256SUMS 2>/dev/null || true)
