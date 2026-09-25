# ghOSt-uConsole Wiki

This wiki collects the operational documentation that does not fit cleanly into the top-level README.

## What This Project Is

ghOSt-uConsole is a distinct Debian-based distribution for the ClockworkPi uConsole on Raspberry Pi CM4 and CM5 hardware. It is not documented as a port. The build produces a Debian Bookworm ARM64 system that combines:

- uConsole hardware support
- handheld-friendly UI and power tuning
- selected security and privacy tooling
- SDR and RF workflows
- offline utilities for field use

## Wiki Pages

- [Build and Flash](Build-and-Flash.md)
- [Package Provenance](Package-Provenance.md)
- [Credits and Compliance](Credits-and-Compliance.md)
- [Troubleshooting](Troubleshooting.md)

## Documentation Map

- Top-level overview: [README.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/README.md)
- Dependencies: [DEPENDENCIES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/DEPENDENCIES.md)
- Third-party notices: [THIRD_PARTY_NOTICES.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/THIRD_PARTY_NOTICES.md)
- Release history: [CHANGELOG.md](/Volumes/Mac%20Stick/Projects/ghOSt-uConsole/CHANGELOG.md)

## Provenance Summary

This is a Debian-based distribution. The system is built from Debian Bookworm and then extended with Raspberry Pi packages, ClockworkPi platform packages, selected upstream source builds, and a curated security/RF toolset inspired by Kali Linux, Parrot Security, BlackArch, DragonOS, and Bazzite.
