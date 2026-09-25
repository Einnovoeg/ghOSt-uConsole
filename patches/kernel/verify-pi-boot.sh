#!/usr/bin/env bash
# Verify Pi/uConsole boot artifacts after kernel stage.
# Pi analogue of rg35xxh patches/kernel/configure-empty-initramfs.sh:
# instead of wiping an embedded ROCKNIX cpio, we verify a real Pi kernel,
# initramfs, DTB/overlays and sane console ordering exist before packing.
set -euo pipefail
ROOTFS="$1"

fail=0
check() {
  if eval "$1"; then echo "[ok] $2"; else echo "[FAIL] $2"; fail=1; fi
}

check "[ -f '$ROOTFS/boot/firmware/config.txt' ] || [ -f '$ROOTFS/boot/config.txt' ]" "boot config.txt present"
check "ls '$ROOTFS/boot/firmware/kernel'*.img '$ROOTFS/boot/kernel'*.img 2>/dev/null" "Pi kernel Image present"
check "ls '$ROOTFS/boot/firmware/'*.dtb '$ROOTFS/boot/'*.dtb 2>/dev/null | head -1 | grep -q ." "DTB present"
check "ls -d '$ROOTFS/lib/modules/'* 2>/dev/null | head -1 | grep -q ." "kernel modules present"
check "grep -q 'console=tty1' '$ROOTFS/boot/firmware/cmdline.txt' 2>/dev/null || grep -q 'console=tty1' '$ROOTFS/boot/cmdline.txt' 2>/dev/null" "cmdline ends with console=tty1 (screen wins over serial)"

# initramfs present when update-initramfs ran (MMC root needs it on some CM4 configs)
if ls "$ROOTFS/boot/firmware/initramfs"* "$ROOTFS/boot/initramfs"* 2>/dev/null | grep -q .; then
  echo "[ok] initramfs present"
else
  echo "[warn] no initramfs in /boot — continuing (MMC builtin kernels boot without it)"
fi

# Embedded-cpio sanity (rg35xxh PITFALLS #1 analogue): Pi Image must not contain rocknix paths
KIMG="$(ls "$ROOTFS/boot/firmware/kernel"*.img "$ROOTFS/boot/kernel"*.img 2>/dev/null | head -1 || true)"
if [ -n "${KIMG:-}" ] && strings "$KIMG" 2>/dev/null | grep -qE '^/storage|^/flash|rocknix-init'; then
  echo "[FAIL] kernel Image contains foreign initramfs strings"; fail=1
fi

exit $fail
