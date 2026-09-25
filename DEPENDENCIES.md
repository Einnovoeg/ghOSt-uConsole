# Dependencies

This project has two dependency layers: host build dependencies and image build sources.

## Host Build Dependencies

The native build expects these Ubuntu packages:

```text
debootstrap
qemu-user-static
binfmt-support
parted
kpartx
rsync
git
wget
curl
python3
python3-pip
make
gcc
flex
bison
bc
libssl-dev
libelf-dev
lzop
u-boot-tools
crossbuild-essential-arm64
gcc-aarch64-linux-gnu
zip
unzip
xz-utils
lz4
zstd
pv
```

## Package Feeds

The image build pulls packages from these repositories:

- Debian Bookworm
- Raspberry Pi Bookworm archive
- ClockworkPi community apt repository maintained by `ak-rex`
- Kali rolling, pinned to explicit installs only

## Major Upstream Source Builds and Downloads

The rootfs build also clones or downloads software directly from upstream when packages are unavailable, outdated, or incompatible with current Bookworm:

- `steve-m/kalibrate-rtl`
- `cropinghigh/SDRPlusPlus`
- `smittix/intercept`
- `laramies/theHarvester`
- `smicallef/spiderfoot`
- `kismetwireless/kismet`
- `ggerganov/whisper.cpp`
- `rhasspy/piper`
- `gchq/CyberChef`
- `mgba-emu/mGBA`
- `PortsMaster/PortMaster-New`
- `ptitSeb/box64`
- `FEX-Emu/FEX`

## Runtime Assumptions

- ClockworkPi uConsole hardware
- Raspberry Pi CM4 or CM5
- microSD storage
- Internet access during build
- Additional storage and USB peripherals as needed for SDR, serial, Wi-Fi, LTE, GPS, or Android workflows
