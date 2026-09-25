#!/usr/bin/env bash
# =============================================================================
# ghOSt Boot Asset Stager - ClockworkPi uConsole (Raspberry Pi CM4 / CM5)
#
# The uConsole boot path uses Raspberry Pi firmware in /boot/firmware plus the
# ClockworkPi overlays supplied by the community kernel and firmware packages.
# This stage prepares the ghOSt-specific boot configuration that later gets
# copied into the rootfs before image assembly.
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../config.sh"

log()   { echo -e "\033[0;32m[KERNEL]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m  $*"; exit 1; }

BOOT_STAGE_DIR="$KERNEL_BUILD_DIR/boot-firmware"

prepare_stage_dir() {
    mkdir -p "$BOOT_STAGE_DIR"
    find "$BOOT_STAGE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}

stage_boot_templates() {
    local src_dir
    src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/boot" && pwd)"

    [[ -f "$src_dir/config.txt" ]] || error "Missing boot config template"
    [[ -f "$src_dir/cmdline.txt" ]] || error "Missing boot cmdline template"
    [[ -f "$src_dir/cm5-eeprom.conf" ]] || error "Missing CM5 EEPROM template"

    install -m 0644 "$src_dir/config.txt" "$BOOT_STAGE_DIR/config.txt"
    install -m 0644 "$src_dir/cmdline.txt" "$BOOT_STAGE_DIR/cmdline.txt"
    install -m 0644 "$src_dir/cm5-eeprom.conf" "$KERNEL_BUILD_DIR/cm5-eeprom.conf"
}

prepare_stage_dir
stage_boot_templates

# Console-ordering pitfall (rg35xxh PITFALLS #3): Linux uses the LAST console=
# as /dev/console. UART pads aren't usable on handheld, so tty1 must win.
# Portable sed (GNU + BSD macOS): use backup suffix then remove it.
sedi() { sed -i.bak "$@" ; rm -f "$BOOT_STAGE_DIR"/cmdline.txt.bak; }
if grep -q 'console=' "$BOOT_STAGE_DIR/cmdline.txt"; then
    if ! grep -Eqo 'console=tty1[^ ]* *$' "$BOOT_STAGE_DIR/cmdline.txt"; then
        # Move console=tty1 to the end while preserving other args
        tmp=$(grep -o 'console=tty1[^ ]*' "$BOOT_STAGE_DIR/cmdline.txt" | head -1 || true)
        if [[ -n "${tmp:-}" ]]; then
            sedi 's/ *console=tty1[^ ]*//g' "$BOOT_STAGE_DIR/cmdline.txt"
            sedi "s|$| $tmp|" "$BOOT_STAGE_DIR/cmdline.txt"
        else
            sedi 's|$| console=tty1|' "$BOOT_STAGE_DIR/cmdline.txt"
        fi
        log "Fixed console ordering: tty1 last"
    fi
fi

# Root spec: pack-image.sh normalizes to LABEL=GHOST_ROOT; keep ROOTDEV placeholder here
grep -q 'root=' "$BOOT_STAGE_DIR/cmdline.txt" || \
    sedi 's|$| root=LABEL=GHOST_ROOT|' "$BOOT_STAGE_DIR/cmdline.txt"

log "Staged uConsole boot configuration"
log "  firmware config: $BOOT_STAGE_DIR/config.txt"
log "  kernel cmdline:  $BOOT_STAGE_DIR/cmdline.txt"
log "  CM5 EEPROM hint: $KERNEL_BUILD_DIR/cm5-eeprom.conf"
