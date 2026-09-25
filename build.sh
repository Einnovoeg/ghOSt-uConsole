#!/usr/bin/env bash
# =============================================================================
#  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
# ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
# ██║  ███╗███████║██║   ██║███████╗   ██║
# ██║   ██║██╔══██║██║   ██║╚════██║   ██║
# ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║
#  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝
#
# Handheld Security and Signal Terminal
# Build Script v1.0
# Target: ClockworkPi uConsole (Raspberry Pi CM4 / CM5)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Export config vars so chroot children (configure.sh) inherit them.
# Without this, GHOST_USER etc. are shell-only and appear empty inside chroot.
set -a
source "$SCRIPT_DIR/config.sh"
set +a

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[ghOSt]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $* ━━━${NC}\n"; }

is_enabled() {
    case "${1:-false}" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================
preflight() {
    section "Preflight Checks"

    [[ "$(id -u)" == "0" ]] || error "Must run as root (sudo ./build.sh)"

    local required_tools=(
        debootstrap qemu-user-static binfmt-support
        parted kpartx rsync git wget curl
        python3 python3-pip make gcc flex bison bc
        libssl-dev libelf-dev lzop u-boot-tools
        crossbuild-essential-arm64 gcc-aarch64-linux-gnu
        zip unzip xz-utils lz4 zstd pv
    )

    log "Checking required host tools..."
    local missing=()
    for tool in "${required_tools[@]}"; do
        if ! dpkg -l "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Installing missing tools: ${missing[*]}"
        apt-get update -qq
        apt-get install -y "${missing[@]}"
    fi

    log "Checking disk space (need ~${MIN_DISK_GB}GB free)..."
    local free_gb
    free_gb=$(df -BG "$BUILD_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    [[ "$free_gb" -ge "$MIN_DISK_GB" ]] || \
        error "Need ${MIN_DISK_GB}GB free, only ${free_gb}GB available in $BUILD_DIR"

    log "Checking RAM (need ~${MIN_RAM_GB}GB for build)..."
    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    [[ "$ram_gb" -ge "$MIN_RAM_GB" ]] || \
        warn "Low RAM (${ram_gb}GB), build may be slow"

    # Register ARM64 binfmt
    update-binfmts --enable qemu-aarch64 2>/dev/null || true
    cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/" 2>/dev/null || true

    # Network check — needed for upstream package repositories and source clones
    log "Checking network access to package and source mirrors..."
    for url in \
        "https://github.com" \
        "${RPI_MIRROR}" \
        "${CLOCKWORKPI_APT_URL}"; do
        if ! curl -sfI --max-time 10 "$url" >/dev/null 2>&1; then
            warn "Cannot reach $url — build may fail later if caches are missing"
        fi
    done

    log "Preflight OK"
}

# =============================================================================
# STEP 1: KERNEL BUILD
# =============================================================================
build_kernel() {
    section "Staging uConsole Boot Configuration"
    bash "$SCRIPT_DIR/kernel/build-kernel.sh"
    log "Boot configuration stage complete"
}

# =============================================================================
# STEP 2: ROOTFS BOOTSTRAP
# =============================================================================
build_rootfs() {
    section "Bootstrapping Debian Bookworm ARM64 Rootfs"
    bash "$SCRIPT_DIR/rootfs/build-rootfs.sh"
    log "Rootfs build complete"
}

# =============================================================================
# STEP 3: APPLY OVERLAY
# =============================================================================
apply_overlay() {
    section "Applying ghOSt Overlay"

    log "Copying overlay files..."
    rsync -av --chown=root:root "$SCRIPT_DIR/overlay/" "$ROOTFS_DIR/"

    if [[ -d "$KERNEL_BUILD_DIR/boot-firmware" ]]; then
        log "Installing staged Raspberry Pi boot firmware configuration..."
        mkdir -p "$ROOTFS_DIR$BOOT_FIRMWARE_DIR"
        rsync -av --chown=root:root "$KERNEL_BUILD_DIR/boot-firmware/" \
            "$ROOTFS_DIR$BOOT_FIRMWARE_DIR/"
    fi

    if [[ -f "$KERNEL_BUILD_DIR/cm5-eeprom.conf" ]]; then
        log "Installing CM5 EEPROM template..."
        install -D -m 0644 "$KERNEL_BUILD_DIR/cm5-eeprom.conf" \
            "$ROOTFS_DIR$CM5_EEPROM_TEMPLATE_PATH"
    fi

    log "Installing launcher..."
    cp -r "$SCRIPT_DIR/launcher/" "$ROOTFS_DIR/opt/ghost/launcher/"
    chmod +x "$ROOTFS_DIR/opt/ghost/launcher/launcher.py"

    log "Installing stealthd..."
    cp -r "$SCRIPT_DIR/stealthd/" "$ROOTFS_DIR/opt/ghost/stealthd/"
    chmod +x "$ROOTFS_DIR/opt/ghost/stealthd/stealthd.py"
    cp "$SCRIPT_DIR/stealthd/stealthd.service" \
       "$ROOTFS_DIR/etc/systemd/system/"

    log "Installing hey AI CLI..."
    cp -r "$SCRIPT_DIR/hey/" "$ROOTFS_DIR/opt/ghost/hey/"
    chmod +x "$ROOTFS_DIR/opt/ghost/hey/hey.py"
    ln -sf /opt/ghost/hey/hey.py "$ROOTFS_DIR/usr/local/bin/hey"

    log "Installing firstboot script..."
    cp "$SCRIPT_DIR/firstboot/firstboot.sh" "$ROOTFS_DIR/usr/local/bin/"
    cp "$SCRIPT_DIR/firstboot/firstboot.service" \
       "$ROOTFS_DIR/etc/systemd/system/"
    chmod +x "$ROOTFS_DIR/usr/local/bin/firstboot.sh"

    log "Overlay applied"
}

# =============================================================================
# STEP 4: IN-CHROOT CONFIGURATION
# =============================================================================
configure_chroot() {
    section "Configuring System (chroot)"

    # Mount necessary filesystems
    mount --bind /dev  "$ROOTFS_DIR/dev"
    mount --bind /proc "$ROOTFS_DIR/proc"
    mount --bind /sys  "$ROOTFS_DIR/sys"
    mount -t tmpfs tmpfs "$ROOTFS_DIR/tmp"

    # Run chroot configuration script
    chroot "$ROOTFS_DIR" /bin/bash /opt/ghost/scripts/configure.sh

    # Cleanup mounts
    umount "$ROOTFS_DIR/tmp"  || true
    umount "$ROOTFS_DIR/sys"  || true
    umount "$ROOTFS_DIR/proc" || true
    umount "$ROOTFS_DIR/dev"  || true

    log "Chroot configuration complete"
}

# =============================================================================
# STEP 5: ASSEMBLE IMAGE
# =============================================================================
assemble_image() {
    section "Assembling Flash Image"

    local img="$OUTPUT_DIR/${GHOST_FULL_NAME}-${GHOST_VERSION}.img"
    local img_size_mb=$(( BOOT_SIZE_MB + ROOT_SIZE_MB + SWAP_SIZE_MB + 64 ))
    local boot_cfg="$ROOTFS_DIR$BOOT_FIRMWARE_DIR/config.txt"
    local cmdline_cfg="$ROOTFS_DIR$BOOT_FIRMWARE_DIR/cmdline.txt"

    [[ -f "$boot_cfg" ]] || error "Missing Raspberry Pi boot config: $boot_cfg"
    [[ -f "$cmdline_cfg" ]] || error "Missing Raspberry Pi cmdline: $cmdline_cfg"

    log "Creating image file: $(( img_size_mb / 1024 ))GB..."
    dd if=/dev/null of="$img" bs=1M seek="$img_size_mb" status=progress

    log "Partitioning image for Raspberry Pi firmware + rootfs + swap..."
    parted -s "$img" \
        unit MiB \
        mklabel gpt \
        mkpart primary fat32 1MiB "$(( 1 + BOOT_SIZE_MB ))MiB" \
        mkpart primary ext4 "$(( 1 + BOOT_SIZE_MB ))MiB" "$(( 1 + BOOT_SIZE_MB + ROOT_SIZE_MB ))MiB" \
        mkpart primary linux-swap "$(( 1 + BOOT_SIZE_MB + ROOT_SIZE_MB ))MiB" 100% \
        set 1 boot on

    # Attach loop device
    local lodev
    lodev=$(losetup -f --show -P "$img")
    kpartx -av "$lodev"

    local boot_dev="/dev/mapper/$(basename ${lodev})p1"
    local root_dev="/dev/mapper/$(basename ${lodev})p2"
    local swap_dev="/dev/mapper/$(basename ${lodev})p3"

    log "Formatting partitions..."
    mkfs.vfat -F 32 -n GHOST_BOOT "$boot_dev"
    mkfs.ext4 -L "GHOST_ROOT" -O "^has_journal" \
              -E "lazy_itable_init=0,lazy_journal_init=0" \
              -m 1 "$root_dev"
    mkswap -L "GHOST_SWAP" "$swap_dev"

    log "Writing root filesystem..."
    local root_mnt
    root_mnt=$(mktemp -d)
    mount -o noatime "$root_dev" "$root_mnt"
    mkdir -p "$root_mnt$BOOT_FIRMWARE_DIR"
    mount "$boot_dev" "$root_mnt$BOOT_FIRMWARE_DIR"
    rsync -aHAX --info=progress2 "$ROOTFS_DIR/" "$root_mnt/"

    # Write fstab with correct UUIDs
    local boot_uuid root_uuid swap_uuid root_partuuid
    boot_uuid=$(blkid -s UUID -o value "$boot_dev")
    root_uuid=$(blkid -s UUID -o value "$root_dev")
    root_partuuid=$(blkid -s PARTUUID -o value "$root_dev")
    swap_uuid=$(blkid -s UUID -o value "$swap_dev")
    sed -i "s/BOOT_UUID/$boot_uuid/g; s/ROOT_UUID/$root_uuid/g; s/SWAP_UUID/$swap_uuid/g" \
        "$root_mnt/etc/fstab"
    sed -i "s|ROOTDEV|PARTUUID=$root_partuuid|g" \
        "$root_mnt$BOOT_FIRMWARE_DIR/cmdline.txt"

    umount "$root_mnt$BOOT_FIRMWARE_DIR"
    umount "$root_mnt"
    rmdir "$root_mnt"

    # Detach loop device
    kpartx -dv "$lodev"
    losetup -d "$lodev"

    if is_enabled "${COMPRESS_IMAGE:-true}"; then
        log "Compressing image..."
        pv "$img" | gzip -9 > "${img}.gz"
        local size
        size=$(du -h "${img}.gz" | cut -f1)
        rm "$img"
        log "Image created: ${img}.gz (${size})"
    else
        local size
        size=$(du -h "$img" | cut -f1)
        log "Image created: ${img} (${size})"
    fi
    log ""
    log "Recommended flashing:"
    log "  Linux: ./flash_dd_with_gpt.sh"
    log "  macOS: ./flash_dd_with_gpt.MacOS.sh"
    log "Raw dd still works, but the helper scripts also repair GPT after writing."
}

# =============================================================================
# STAGED BUILD (rg35xxh-cyberdeck pattern: idempotent, CI-friendly)
# New minimal bootable path: rootfs/stages/* + image/pack-image.sh.
# Legacy monolithic path (rootfs/build-rootfs.sh + assemble_image) is kept
# for the large toolset when USE_STAGED_ROOTFS=false.
# =============================================================================
build_rootfs_staged() {
    section "Staged Rootfs (bootable minimal, like rg35xxh)"
    local st="$SCRIPT_DIR/rootfs/stages"
    if [[ -d "$ROOTFS_DIR/etc" && -f "$ROOTFS_DIR/etc/debian_version" ]] && ! is_enabled "${GHOST_FORCE_ROOTFS:-false}"; then
        log "rootfs present, skipping (GHOST_FORCE_ROOTFS=1 to override)"
        return 0
    fi
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
    bash "$st/00-debootstrap.sh" "$ROOTFS_DIR"
    bash "$st/10-base-pkgs.sh" "$ROOTFS_DIR"
    bash "$st/20-desktop.sh" "$ROOTFS_DIR"
    bash "$st/30-handheld.sh" "$ROOTFS_DIR"
    bash "$st/40-network.sh" "$ROOTFS_DIR"
    bash "$st/50-overlay.sh" "$ROOTFS_DIR" "$SCRIPT_DIR/overlay"
    # ghOSt extras on top of minimal bootable base
    apply_overlay
    configure_chroot
    bash "$SCRIPT_DIR/patches/kernel/verify-pi-boot.sh" "$ROOTFS_DIR" || \
        warn "boot verification warnings (see above)"
    bash "$st/99-cleanup.sh" "$ROOTFS_DIR"
    log "Staged rootfs complete"
}

pack_image_staged() {
    section "Packing Image (bmap+xz, like rg35xxh)"
    local work dist
    # image/pack-image.sh expects WORK with rootfs/ + kernel/boot-firmware/
    work=$(mktemp -d)
    dist="$OUTPUT_DIR"
    mkdir -p "$dist"
    rm -rf "$work/rootfs" "$work/kernel"
    cp -a "$ROOTFS_DIR" "$work/rootfs"
    mkdir -p "$work/kernel"
    if [[ -d "$KERNEL_BUILD_DIR/boot-firmware" ]]; then
        mkdir -p "$work/kernel/boot-firmware"
        cp -a "$KERNEL_BUILD_DIR/boot-firmware/"* "$work/kernel/boot-firmware/" 2>/dev/null || true
    fi
    bash "$SCRIPT_DIR/image/pack-image.sh" "$work" "$dist"
    rm -rf "$work"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo -e "${CYAN}"
    cat << 'EOF'
  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
 ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
 ██║  ███╗███████║██║   ██║███████╗   ██║
 ██║   ██║██╔══██║██║   ██║╚════██║   ██║
 ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝
  Handheld Security and Signal Terminal
EOF
    echo -e "${NC}"
    echo -e "  Device:  ${BOLD}${DEVICE_TARGET}${NC}"
    echo -e "  Modules: ${BOLD}${DEVICE_PROFILE}${NC}"
    echo -e "  Version: ${BOLD}${GHOST_VERSION}${NC}"
    echo -e "  Toolset: ${BOLD}${TOOLSET_SIZE}${NC}"
    echo -e "  Extras:  ${BOLD}${GAMES_PROFILE}${NC}"
    echo ""

    local start_time=$SECONDS

    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR" "$ROOTFS_DIR" \
             "$KERNEL_BUILD_DIR" "$UBOOT_BUILD_DIR"

    preflight

    # Staged CI path (default when rootfs/stages exists and not explicitly disabled).
    # Set USE_STAGED_ROOTFS=false to force the legacy monolithic build.
    if [[ -d "$SCRIPT_DIR/rootfs/stages" && "${USE_STAGED_ROOTFS:-true}" == "true" && "${1:-all}" == "all" ]]; then
        if is_enabled "${SKIP_KERNEL:-false}"; then
            warn "SKIP_KERNEL — reusing staged kernel assets"
        else
            build_kernel
        fi
        if is_enabled "${SKIP_ROOTFS:-false}"; then
            warn "SKIP_ROOTFS — reusing rootfs"
        else
            build_rootfs_staged
        fi
        if is_enabled "${SKIP_IMAGE:-false}"; then
            warn "SKIP_IMAGE — skipping pack"
        else
            pack_image_staged
        fi
    else
        if is_enabled "${SKIP_KERNEL:-false}"; then
            warn "SKIP_KERNEL is enabled — reusing existing staged kernel assets"
        else
            build_kernel
        fi

        if is_enabled "${SKIP_ROOTFS:-false}"; then
            warn "SKIP_ROOTFS is enabled — reusing existing rootfs"
        else
            build_rootfs
        fi

        if is_enabled "${SKIP_OVERLAY:-false}"; then
            warn "SKIP_OVERLAY is enabled — skipping overlay application"
        else
            apply_overlay
        fi

        if is_enabled "${SKIP_CONFIGURE:-false}"; then
            warn "SKIP_CONFIGURE is enabled — skipping in-chroot configuration"
        else
            configure_chroot
        fi

        if is_enabled "${SKIP_IMAGE:-false}"; then
            warn "SKIP_IMAGE is enabled — skipping image assembly"
        else
            assemble_image
        fi
    fi

    local elapsed=$(( SECONDS - start_time ))
    local elapsed_fmt
    elapsed_fmt=$(printf '%02d:%02d:%02d' \
        $(( elapsed/3600 )) $(( elapsed%3600/60 )) $(( elapsed%60 )))

    section "Build Complete"
    echo -e "${GREEN}${BOLD}ghOSt build finished in ${elapsed_fmt}${NC}"
    echo -e "Output: ${BOLD}${OUTPUT_DIR}/${NC}"
}

main "$@"
