# ghOSt-uConsole Agent Handoff

## 1. Point Of This Project

ghOSt-uConsole is a distinct Debian-based distribution for the ClockworkPi uConsole on Raspberry Pi CM4 and CM5 hardware.

The point of the project is to produce a handheld Debian Bookworm ARM64 system with:

- working uConsole platform support
- a launcher and UI tuned for the internal display, keyboard, and trackball
- selected security, privacy, reverse-engineering, and RF/SDR tooling
- first-boot provisioning that is practical on real handheld hardware

This repository should be treated as its own distribution for this hardware target. It is not documented as a port.

## 2. What Has Been Done

The major structural work already completed in this workspace:

- Replaced the old boot/image assumptions with a Raspberry Pi-style `/boot/firmware` layout for uConsole CM4 and CM5.
- Added ClockworkPi and Raspberry Pi package feeds and moved the image assembly flow to a Pi/uConsole-oriented partition layout.
- Added CM5 EEPROM guidance and a first-boot helper for CM5 SD boot reliability.
- Reworked the launcher for the larger uConsole display and added hover tooltips plus keyboard/trackball-friendly layout behavior.
- Reworked power and battery scripts so they target Raspberry Pi CM4/CM5 behavior instead of fixed handheld assumptions.
- Cleaned up naming so the repo is documented as ghOSt-uConsole and not as another device project.
- Expanded the top-level documentation and added wiki pages for build flow, package provenance, troubleshooting, credits, and compliance.
- Added third-party attribution and project-credit documentation.
- Added retry and timeout protection to the shared `clone_repo_clean()` helper in `rootfs/build-rootfs.sh` so slow GitHub clones do not silently appear frozen forever.
- Updated the PS3 controller helper builds (`sixpair` and `sixad`) to use the guarded clone helper instead of raw `git clone` calls.

## 3. Current State

What is known right now:

- The repository has been reshaped into a uConsole-specific Debian distribution.
- The docs now state clearly that this is a Debian-based distribution and not a port.
- Static verification has been run repeatedly with `bash -n` and `python3 -m py_compile` on the main edited scripts.
- The build still depends on many upstream network fetches and source clones, so the main remaining risk is end-to-end build reliability and real hardware validation.

## 4. Important Files

- `build.sh`: top-level build orchestration
- `config.sh`: versioning, package feeds, image sizing, and build options
- `kernel/build-kernel.sh`: stages `config.txt`, `cmdline.txt`, and CM5 EEPROM guidance
- `rootfs/build-rootfs.sh`: debootstrap plus package install stages
- `overlay/opt/ghost/scripts/configure.sh`: in-chroot system configuration
- `firstboot/firstboot-interactive.sh`: interactive first-boot setup
- `launcher/launcher.py`: SDL2 launcher for the uConsole UI
- `README.md`: user-facing overview
- `THIRD_PARTY_NOTICES.md`: attribution and redistribution notes
- `wiki/`: extended documentation and handoff context

## 5. Known Risks And Gaps

- A full native or Docker build has not been exhaustively validated from start to finish after every change in this branch.
- Real hardware validation is still required on both uConsole CM4 and CM5.
- Some source-build and clone paths still use direct `git clone` or raw upstream downloads outside the shared guarded clone helper. They should be reviewed and normalized over time.
- The exact final package manifest for release distribution still needs to be generated from a completed image build.

## 6. Next Steps

The next agent should work in this order:

1. Run a full build and confirm where the current pipeline succeeds or fails end-to-end.
2. If the build stalls on another upstream clone or download, convert that step to the guarded helper pattern used by `clone_repo_clean()`.
3. Boot-test the image on actual uConsole CM4 and CM5 hardware.
4. Validate internal display, keyboard, trackball, audio, Wi-Fi, Bluetooth, suspend/resume behavior, battery reporting, and CM5 EEPROM flow.
5. Generate a concrete package manifest or SBOM from the finished image so release provenance is exact rather than summary-level.
6. Review remaining comments, scripts, and docs for any stale assumptions that still reflect generic handheld behavior instead of real uConsole behavior.

## 7. Immediate Build Clue

If a build log appears to freeze at a line like:

```text
Cloning into '/tmp/sixpair'...
```

that was previously caused by an unguarded raw clone in the controller-support stage. That specific path has now been switched to the guarded clone helper. If a future build hangs on a different repository, search `rootfs/build-rootfs.sh` for raw `git clone` calls and convert the failing step in the same way.
