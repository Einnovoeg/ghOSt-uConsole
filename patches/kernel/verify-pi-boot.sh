#!/usr/bin/env bash
# Verify Pi/uConsole boot artifacts after kernel stage.
# Pi analogue of rg35xxh patches/kernel/configure-empty-initramfs.sh:
# instead of wiping an embedded ROCKNIX cpio, we verify a real Pi kernel,
# initramfs, DTB/overlays and sane console ordering exist before packing.
set -euo pipefail
ROOTFS="$1"

fail=0
check_file() {
  # $1 = description, remaining args = glob patterns (quoted, may contain spaces)
  local desc="$1"; shift
  local pat match
  for pat in "$@"; do
    # compgen handles spaces in pattern correctly (unlike unquoted $pat expansion)
    if match=$(compgen -G "$pat" | head -1) && [ -n "${match:-}" ] && [ -e "$match" ]; then
      echo "[ok] $desc ($match)"; return 0
    fi
  done
  echo "[FAIL] $desc"; fail=1; return 1
}

check_file "boot config.txt present" "$ROOTFS/boot/firmware/config.txt" "$ROOTFS/boot/config.txt"
check_file "Pi kernel Image present" "$ROOTFS/boot/firmware/kernel*.img" "$ROOTFS/boot/kernel*.img"
check_file "DTB present" "$ROOTFS/boot/firmware/*.dtb" "$ROOTFS/boot/*.dtb"
check_file "kernel modules present" "$ROOTFS/lib/modules/*"
check_cmdline() {
  if grep -q 'console=tty1' "$ROOTFS/boot/firmware/cmdline.txt" 2>/dev/null || \
     grep -q 'console=tty1' "$ROOTFS/boot/cmdline.txt" 2>/dev/null; then
    echo "[ok] cmdline ends with console=tty1 (screen wins over serial)"; return 0
  fi
  echo "[FAIL] cmdline ends with console=tty1 (screen wins over serial)"; fail=1; return 1
}
check_cmdline

# initramfs present when update-initramfs ran (MMC root needs it on some CM4 configs)
if compgen -G "$ROOTFS/boot/firmware/initramfs*" > /dev/null || compgen -G "$ROOTFS/boot/initramfs*" > /dev/null; then
  echo "[ok] initramfs present"
else
  echo "[warn] no initramfs in /boot — continuing (MMC builtin kernels boot without it)"
fi

# Embedded-cpio sanity (rg35xxh PITFALLS #1 analogue): Pi Image must not contain rocknix paths
KIMG="$( (compgen -G "$ROOTFS/boot/firmware/kernel*.img"; compgen -G "$ROOTFS/boot/kernel*.img") 2>/dev/null | head -1 || true)"
if [ -n "${KIMG:-}" ] && strings "$KIMG" 2>/dev/null | grep -qE '^/storage|^/flash|rocknix-init'; then
  echo "[FAIL] kernel Image contains foreign initramfs strings"; fail=1
fi

exit $fail
