# ghOSt-uConsole

ghOSt-uConsole is a distinct Debian-based distribution for the ClockworkPi uConsole running a Raspberry Pi CM4 or CM5. It builds a Debian Bookworm ARM64 system focused on portable security work, RF and SDR workflows, privacy tooling, offline utilities, and a handheld-friendly interface.

> This is a Debian-based distribution. It is not a port.

The release does not recreate any upstream distribution wholesale. It keeps Debian as the base system and then layers in selected packages, firmware, utilities, and source builds that fit the uConsole hardware and the intended operator workflow. While it shares Debian lineage with other work in this space, it is documented here as its own distribution with its own platform behavior, package mix, and runtime design.

## Default Release Scope

- Debian Bookworm ARM64 root filesystem
- Raspberry Pi and ClockworkPi platform packages for the uConsole panel, keyboard, audio, firmware, and CM4/CM5 boot flow
- Selected security, RF, privacy, reverse-engineering, and field-ops tooling
- SDL2 launcher tuned for the uConsole display, keyboard, trackball, and hover tooltips
- First-boot provisioning for timezone, SSH keys, Wi-Fi, and CM5 EEPROM guidance

## Hardware Support

- ClockworkPi uConsole with Raspberry Pi CM4
- ClockworkPi uConsole with Raspberry Pi CM5
- Internal display, keyboard, trackball, and audio through ClockworkPi overlays and platform packages
- Optional HDMI, USB networking, SDRs, GPS receivers, serial adapters, Wi-Fi adapters, and LTE add-ons

## Tooling Provenance And Distro Inspiration

The release is assembled from several sources:

- Debian packages
- Raspberry Pi Bookworm packages
- ClockworkPi packages and overlays
- Selected upstream release archives and source builds
- A pinned external security-tool repository when a required tool is not available in a usable Bookworm form

The tool selection was influenced by several well-known ecosystems. In this repository, those influences show up as selected tool groups rather than as full distribution imports.

| Inspiration | What it contributes to this release | Representative tools or package groups |
|---|---|---|
| Kali Linux | Recon, wireless, offensive-security, and field enumeration workflows | `recon-ng`, `bettercap`, `wifite`, `airgeddon`, `metasploit-framework`, `sqlmap`, `responder`, `ffuf`, `feroxbuster`, `theHarvester`, `SpiderFoot` |
| Parrot Security | Privacy, portable operator workflows, and daily-driver security utilities | `tor`, `torsocks`, `proxychains4`, `dnscrypt-proxy`, `onionshare`, `wireguard`, `openvpn`, `stormssh`, hardened TUI workflow tooling |
| BlackArch | Dense offensive, reverse-engineering, password-audit, and exploit-development coverage | `radare2`, `rizin`, `pwndbg`, `ROPgadget`, `hashcat`, `john`, `binwalk`, `jadx`, `frida-tools`, `objection`, `routersploit` |
| DragonOS | RF and SDR workflow direction | `rtl-sdr`, `rtl-433`, `dump1090-mutability`, `multimon-ng`, `direwolf`, `fldigi`, `kalibrate-rtl`, `kismet`, `inspectrum`, `SDR++ Brown` |
| Bazzite | Handheld ergonomics, power management, and controller-oriented polish | `hhd`, optional `gamemode`, device power profiles, handheld-oriented UX decisions |

Exact package provenance can vary by package and by build option. A given tool may come from Debian, Raspberry Pi, ClockworkPi, the pinned external security repository, or an upstream source/release build depending on what is currently compatible with Debian Bookworm ARM64.

## Research And Credits

The provenance summary in this README and the wiki was compiled from official project pages, package metadata, and upstream repositories maintained by the people and teams who made this build possible.

- Debian Project
- Raspberry Pi Ltd
- ClockworkPi
- `ak-rex`, who maintains the community ClockworkPi package feed used here
- Kali Linux contributors including Mati Aharoni, Devon Kearns, Jim O'Gorman, Arnaud Rebillout, Ben Wilson, and Raphaël Hertzog
- Parrot Security contributors led by Lorenzo Faletra and the Parrot team
- BlackArch contributors and guide authors including Tyler Bennnett, `fnord0`, Ellis Kenyo, Johannes Löthberg, Valentin Churavy, and Francesco Piccinno
- Bazzite and Universal Blue maintainers and contributors
- DragonOS maintainer `justin-malonson`
- The upstream maintainers of the included tools listed in [THIRD_PARTY_NOTICES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/THIRD_PARTY_NOTICES.md)

Detailed attribution, compliance notes, and source links are collected in the wiki and in [THIRD_PARTY_NOTICES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/THIRD_PARTY_NOTICES.md).

## Build

Native builds are intended for Ubuntu 22.04 or 24.04 x86_64:

```bash
sudo ./build.sh
```

Docker remains available:

```bash
docker compose up --build
```

Default output:

```text
build/output/ghOSt-uConsole-1.0.0.img.gz
```

Flash with one of the helper scripts:

```bash
./flash_dd_with_gpt.sh
./flash_dd_with_gpt.MacOS.sh
```

## Host Requirements

| Requirement | Minimum | Recommended |
|---|---:|---:|
| Host OS | Ubuntu 22.04 x86_64 | Ubuntu 24.04 x86_64 |
| RAM | 4 GB | 8 GB+ |
| Free disk | 60 GB | 100 GB+ |
| Build time | 4-6 hours | 2-4 hours |
| Target SD card | 64 GB | 128 GB |

Detailed host dependencies are listed in [DEPENDENCIES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/DEPENDENCIES.md).

## Default Image Layout

```text
mmcblk0p1   FAT32      256 MB   Raspberry Pi boot firmware
mmcblk0p2   ext4        24 GB   root filesystem
mmcblk0p3   swap         4 GB   swap partition
```

The root partition expands on first boot while preserving the boot and swap partitions.

## First Boot

The first-boot flow does the following:

1. Prompts for the `ghost` password.
2. Sets the timezone.
3. Generates an ed25519 SSH keypair and shows the public key as text and QR.
4. Offers `hey` API key setup.
5. Offers Wi-Fi setup through `nmtui`.
6. On CM5, offers to apply the recommended EEPROM boot settings.
7. Creates the stealth ROM directory and explains how to trigger stealth mode from the launcher.

## Documentation And Wiki

- Project dependencies: [DEPENDENCIES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/DEPENDENCIES.md)
- Third-party attribution and licensing notes: [THIRD_PARTY_NOTICES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/THIRD_PARTY_NOTICES.md)
- Release history: [CHANGELOG.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/CHANGELOG.md)
- Wiki home: [wiki/Home.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/wiki/Home.md)
- Wiki build guide: [wiki/Build-and-Flash.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/wiki/Build-and-Flash.md)
- Wiki package provenance: [wiki/Package-Provenance.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/wiki/Package-Provenance.md)
- Wiki credits and compliance: [wiki/Credits-and-Compliance.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/wiki/Credits-and-Compliance.md)
- Wiki troubleshooting: [wiki/Troubleshooting.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/wiki/Troubleshooting.md)
- Repository license: [LICENSE](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/LICENSE)

## Support

If the project is useful, support it here: [buymeacoffee.com/einnovoeg](https://buymeacoffee.com/einnovoeg)

## Legal

The build scripts in this repository are released under the MIT license. The generated image redistributes third-party packages, source trees, firmware, and tools that retain their own licenses and attribution requirements. Read [THIRD_PARTY_NOTICES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/THIRD_PARTY_NOTICES.md) before redistributing images.

Use ghOSt-uConsole only for authorized security research, lab work, CTFs, education, and defensive testing.
