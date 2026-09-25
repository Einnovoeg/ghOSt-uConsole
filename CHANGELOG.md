# Changelog

All notable changes to this project are documented in this file.

## 1.0.0 - 2026-03-29

- Added a uConsole-specific image pipeline for Raspberry Pi CM4 and CM5.
- Standardized the boot path around a Raspberry Pi `/boot/firmware` image layout.
- Added Raspberry Pi and ClockworkPi package feeds for kernel, firmware, audio, and uConsole helpers.
- Added staged `config.txt`, `cmdline.txt`, and a recommended CM5 EEPROM template.
- Updated first boot to audit and optionally apply the CM5 EEPROM settings required for more reliable SD boot.
- Reworked the launcher for keyboard and trackball use, dynamic sizing, and hover tooltips.
- Replaced fixed power tuning with dynamic Raspberry Pi CM4/CM5 power profiles.
- Updated the wallpaper generator for the uConsole display.
- Expanded the README and added a wiki covering build flow, package provenance, troubleshooting, credits, and compliance.
- Added timeout and retry protection around upstream repository clones to reduce build stalls on slow network steps.
- Added dependency, license, attribution, and release documentation for image redistribution.
- Centered the default build around a handheld security and signal-intelligence workflow.
- Set the shipped profile to `GAMES_PROFILE=lean` with PortMaster, DOSBox-X, FEX, and Wine disabled unless explicitly requested.
- Updated the launcher so optional entries only appear when the corresponding binaries or paths are present in the image.
- Isolated Python-heavy security tools such as SpiderFoot and theHarvester in dedicated virtual environments.
- Reworked multiple upstream download and packaging paths to reduce breakage from current Bookworm and GitHub release drift.
- Added an official-source fallback build for Kismet when the Bookworm package path is incompatible.
