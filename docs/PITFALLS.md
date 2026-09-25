# Pitfalls (uConsole port of rg35xxh-cyberdeck/docs/PITFALLS.md)

Everything that made previous ghOSt images not boot. Read before "why doesn't it boot."

## 1. No real kernel installed (previous #1 failure)

Old `kernel/build-kernel.sh` only staged `config.txt`/`cmdline.txt` and relied
on the `ak-rex/ClockworkPi-apt` raw feed at image time. CI logs showed
`Cannot reach https://raw.githubusercontent.com/ak-rex/ClockworkPi-apt/...` —
so no `clockworkpi-kernel`, no overlays, no modules. Symptom: rainbow screen /
firmware panic, or boot to initramfs with no root.

Fix: `rootfs/stages/30-handheld.sh` installs ClockworkPi packages when reachable
**and** always installs `raspberrypi-bootloader raspberrypi-kernel raspi-firmware`
fallback. `patches/kernel/verify-pi-boot.sh` fails fast when Image/DTB/modules
are missing.

## 2. console= ordering (no usable UART)

Linux uses the **last** `console=` as `/dev/console`. Old cmdline had
`console=serial0 ... console=tty1 ...` in varying order; if serial wins, first
boot looks hung. Fix: `kernel/build-kernel.sh` moves `console=tty1` last;
`image/pack-image.sh` re-enforces it. (rg35xxh PITFALLS #3.)

## 3. Host /etc/passwd copied into rootfs

Old `build-rootfs.sh` did `cp /etc/passwd /rootfs/etc/passwd`, importing the
Docker host `ubuntu` UID 1000 entry. Later `useradd -m -u 1000 ghost` failed
with `UID 1000 is not unique` + `user 'ghost' does not exist`, and tmux/fish
setup wrote to the wrong home. Fix: never copy host passwd/group; `20-desktop.sh`
removes stale UID entries before creating `ghost`.

## 4. Fragile UUID sed fstab

Legacy `assemble_image` wrote `BOOT_UUID/ROOT_UUID` placeholders and sed-replaced
them after mkfs. Any mount failure left an unbootable fstab. Fix: `50-overlay.sh`
writes `LABEL=GHOST_BOOT / GHOST_ROOT` fstab; `pack-image.sh` labels partitions
to match — same pattern as rg35xxh `LABEL=rootfs / LABEL=BOOT`.

## 5. GPT + separate swap vs Pi firmware expectations

Legacy image used GPT + 3 partitions (boot/root/swap, ~28GB). Some SD readers +
Pi firmware combos prefer MBR for the boot FAT. Fix: staged `pack-image.sh`
uses MBR DOS label, p1 FAT 256MB, p2 ext4 rest (like rg35xxh), no swap partition
(zram + tmpfs instead). Legacy GPT path kept behind `USE_STAGED_ROOTFS=false`.

## 6. Monolithic rootfs (network-flaky, unreproducible)

Old 2400-line `build-rootfs.sh` mixed Kali rolling, dozens of `git clone`,
pip installs and source builds in one run — any mirror hiccup failed the whole
4-6h build. Fix: split `rootfs/stages/` (00→99) like rg35xxh; each stage is
re-runnable, minimal bootable set first, heavy toolset optional.

## 7. Missing cleanup (machine-id, qemu, resolv.conf)

Images shipped with build-time `/etc/machine-id`, `qemu-aarch64-static` and a
static `resolv.conf`, causing duplicate DHCP/hostname and DNS issues on first
boot. Fix: exact port of rg35xxh `99-cleanup.sh` (machine-id reset, qemu removal,
resolv.conf → systemd stub symlink, journal vacuum).

## 8. Debootstrap tar failure = full disk

`E: Tried to extract package, but tar failed` in CI almost always means the
bind-mounted `rootfs/` filled its disk (earlier X21 bind hit 50GB with a 28GB
image + 14GB rootfs + Docker layers). Fix: staged 8GB image, `df` preflight,
and CI `df -h` step before packing.
