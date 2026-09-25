# Package Provenance

## Base Statement

This is a Debian-based distribution. It is not a port.

ghOSt-uConsole does not import another distribution wholesale. It builds on Debian Bookworm ARM64 and then layers in platform packages, selected security and RF tooling, and upstream source builds that are compatible with the uConsole target. It should be treated as its own distribution for this hardware platform.

## Real Package Sources Used By The Build

| Source | What comes from it |
|---|---|
| Debian Bookworm | Base system, shell utilities, privacy stack, many security tools, reverse-engineering tools, and general userland |
| Raspberry Pi Bookworm archive | Raspberry Pi firmware and platform integration packages |
| ClockworkPi package feed | uConsole kernel, CM firmware, audio package, and uConsole helper packages |
| Upstream source builds | Tools that are unavailable, outdated, or incompatible on Bookworm ARM64 |
| Upstream release archives | Prebuilt arm64 releases for selected tools where source builds would be fragile or unnecessarily heavy |

## Distro-Inspired Tool Groups In This Release

The table below describes the ecosystems that influenced the tool selection. These are not complete distro imports. They are curated tool groups and workflow influences.

| Inspiration | How it shows up here | Representative tools in this repository |
|---|---|---|
| Kali Linux | Recon, wireless, web, and offensive-security selection | `recon-ng`, `bettercap`, `wifite`, `airgeddon`, `metasploit-framework`, `sqlmap`, `responder`, `ffuf`, `feroxbuster`, `theHarvester`, `SpiderFoot` |
| Parrot Security | Privacy stack and portable daily-driver security workflow | `tor`, `torsocks`, `proxychains4`, `dnscrypt-proxy`, `onionshare`, `wireguard`, `openvpn`, `stormssh` |
| BlackArch | Dense offensive, exploit-development, reverse-engineering, and password-audit coverage | `radare2`, `rizin`, `pwndbg`, `ROPgadget`, `hashcat`, `john`, `binwalk`, `jadx`, `frida-tools`, `objection`, `routersploit` |
| DragonOS | RF and SDR workflow direction | `rtl-sdr`, `rtl-433`, `dump1090-mutability`, `multimon-ng`, `direwolf`, `fldigi`, `kalibrate-rtl`, `kismet`, `inspectrum`, `SDR++ Brown` |
| Bazzite | Handheld ergonomics and device-management polish | `hhd`, optional `gamemode`, handheld-oriented power tuning, and UX decisions around portable use |

## Important Accuracy Note

Exact package origin for an installed tool may vary:

- Some tools come directly from Debian.
- Some are only practical through upstream source builds.
- Some depend on the pinned external security-tool repository for package availability.
- Some are installed from upstream arm64 release artifacts instead of packages.

For a public release, the exact package-by-package source of record should be the manifest generated from the final built image, not this summary page alone.
