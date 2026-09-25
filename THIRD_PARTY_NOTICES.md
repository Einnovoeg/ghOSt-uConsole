# Third-Party Notices

ghOSt-uConsole builds a redistributable Debian image that aggregates many upstream packages, source trees, binaries, firmware blobs, configuration overlays, and community-maintained packaging work. This repository does not replace any upstream license.

## Core Platform Credits

- Debian Project: base operating system, package archive, and core userland
- Raspberry Pi Ltd: Raspberry Pi Bookworm packages, EEPROM tooling, firmware, and platform integration
- ClockworkPi: uConsole hardware platform, official images, schematics, and reference documentation
- `ak-rex`: community ClockworkPi apt repository and current uConsole CM4/CM5 kernel and firmware packaging

## Distribution Inspiration And Provenance Notes

This is a Debian-based distribution for the uConsole. It is not a port. It does not redistribute other complete distributions as distributions. Instead, it selects tools, workflows, and packaging ideas from several upstream ecosystems and integrates them into a Debian Bookworm ARM64 system for this hardware target.

- Kali Linux: security and offensive tooling direction, package metadata, and packaging availability for selected tools
- Parrot Security: privacy, portable operator workflow, and security-desktop crossover ideas
- BlackArch: breadth of offensive and reverse-engineering tooling coverage
- DragonOS: SDR and RF workflow direction
- Bazzite: handheld UX, power-management, and controller-oriented polish

Exact package origin for a given tool can vary. Depending on package availability and compatibility on Debian Bookworm ARM64, a tool may come from Debian, Raspberry Pi, ClockworkPi, a pinned external security repository, or an upstream source/release build.

## Named Teams And Individuals Referenced In Project Documentation

The documentation in this repository references the following upstream teams and public maintainers because their work directly informed the build or the provenance notes:

- Debian Project
- Raspberry Pi Ltd
- ClockworkPi
- `ak-rex`
- Kali Linux contributors including Mati Aharoni, Devon Kearns, Jim O'Gorman, Arnaud Rebillout, Ben Wilson, and Raphaël Hertzog
- Parrot Security contributors including Lorenzo Faletra and the Parrot team
- BlackArch contributors and guide authors including Tyler Bennnett, `fnord0`, Ellis Kenyo, Johannes Löthberg, Valentin Churavy, and Francesco Piccinno
- Bazzite and Universal Blue maintainers and contributors
- DragonOS maintainer `justin-malonson`

## Major Upstream Projects Brought Into The Image

- `smittix/intercept`
- `ggerganov/whisper.cpp`
- `rhasspy/piper`
- `gchq/CyberChef`
- `steve-m/kalibrate-rtl`
- `cropinghigh/SDRPlusPlus`
- `kismetwireless/kismet`
- `smicallef/spiderfoot`
- `laramies/theHarvester`
- `v1s1t0r1sh3r3/airgeddon`
- `nismara/wifi-honey`
- `digitalmunition/blueranger`
- `zenware/bluesnarfer`
- `threat9/routersploit`
- `cddmp/enum4linux-ng`
- `mgba-emu/mGBA`
- `ptitSeb/box64`
- `FEX-Emu/FEX`
- `AdnanHodzic/auto-cpufreq`
- `AdnanHodzic/displaylink-debian`

## Redistribution Notes

- Debian, Raspberry Pi, ClockworkPi, and other package repositories used by the build remain under their own licenses and archive policies.
- Source-built components retain the licenses published by their upstream repositories.
- Firmware packages may include redistributable blobs with vendor-specific terms.
- If you redistribute a built image, you are responsible for carrying forward any source-offer, notice, attribution, and license requirements attached to the included components.

## Practical Compliance Guidance

- Preserve this notice file, the repository [LICENSE](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/LICENSE), and upstream package metadata.
- Keep package manager metadata in the image so downstream users can inspect package provenance.
- When shipping binaries or prebuilt images publicly, provide a software bill of materials or package manifest generated from the final image.
- Review every directly cloned upstream project before commercial redistribution.
- Use the wiki pages in [wiki/Home.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/wiki/Home.md) for the human-readable provenance summary, but rely on the final built image manifest for exact package-by-package source tracking.
