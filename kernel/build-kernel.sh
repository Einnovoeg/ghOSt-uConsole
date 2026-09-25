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

log "Staged uConsole boot configuration"
log "  firmware config: $BOOT_STAGE_DIR/config.txt"
log "  kernel cmdline:  $BOOT_STAGE_DIR/cmdline.txt"
log "  CM5 EEPROM hint: $KERNEL_BUILD_DIR/cm5-eeprom.conf"
