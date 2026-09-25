# Build internals (ported from rg35xxh-cyberdeck/docs/BUILD.md)

## Pipeline

```
./build.sh (staged, default)
├── kernel   stage boot templates (config.txt/cmdline.txt) + console-order fix
├── rootfs   00-debootstrap → 10-base → 20-desktop → 30-handheld → 40-network → 50-overlay → 99-cleanup
│             + ghOSt overlay + configure.sh + patches/kernel/verify-pi-boot.sh
└── image    image/pack-image.sh → MBR + FAT GHOST_BOOT + ext4 GHOST_ROOT → .img + .bmap + .img.xz + SHA256SUMS
```

Legacy monolithic path (`USE_STAGED_ROOTFS=false ./build.sh`) still runs
`rootfs/build-rootfs.sh` + `assemble_image` (GPT + swap + gzip) for the full
security toolset. CI uses the staged path.

## Iterating fast

| Change | Re-run |
|---|---|
| Tweak overlay file | `GHOST_FORCE_ROOTFS=1 sudo ./build.sh` (staged) |
| Change a rootfs stage | same as above |
| Just repack image | `sudo image/pack-image.sh work dist` (or `SKIP_KERNEL=1 SKIP_ROOTFS=1 sudo ./build.sh`) |
| Full toolset | `USE_STAGED_ROOTFS=false sudo ./build.sh` |

Mount the `.img` to inspect without flashing:
```bash
LOOP=$(sudo losetup -fP --show dist/ghOSt-uConsole-*.img)
sudo mount ${LOOP}p2 /mnt
sudo mount ${LOOP}p1 /mnt/boot/firmware
sudo umount /mnt/boot/firmware /mnt && sudo losetup -d $LOOP
```

## Why verify the Pi kernel?

rg35xxh taught us embedded-initramfs kernels silently drop to busybox.
Pi analogue: a rootfs without `raspberrypi-kernel`/`clockworkpi-kernel`,
DTB/overlays or modules boots to rainbow / firmware panic.
`patches/kernel/verify-pi-boot.sh` fails fast when Image, DTB, modules or
`console=tty1`-last are missing. `30-handheld.sh` always installs the stock
Pi fallback kernel when the ClockworkPi feed is unreachable.

## CI

`.github/workflows/build.yml` runs the staged build on `ubuntu-24.04`,
caches nothing huge (rootfs rebuilt each run for correctness), packs the
image, uploads `.img.xz + .bmap + SHA256SUMS` as artifacts, and releases on
tags `v*`.
