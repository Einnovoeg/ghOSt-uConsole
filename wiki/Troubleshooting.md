# Troubleshooting

## Build Appears Frozen During A Git Clone

If the Docker log stops on a repository fetch such as:

```text
Cloning into '/opt/ghost/wifi-honey'...
```

the build may be waiting on a slow or stalled network transfer rather than being fully dead.

The build helper now uses:

- shallow clones
- low-speed network detection
- a hard timeout
- retry attempts

If the build stops anyway:

1. Wait a few minutes for the current clone attempt to finish or timeout.
2. Re-run the same build command.
3. Verify general GitHub connectivity from the host.
4. Check Docker Desktop disk and memory limits if you are building on macOS or Windows.

## Docker Build Keeps Restarting From The Same Step

Usually that means one of these is true:

- the upstream repository is temporarily unavailable
- the host network is unstable
- Docker storage is full
- the cached rootfs has a broken partial install

In most cases, re-running `docker compose up --build` is enough because the build reuses previously completed stages.

## CM5 Boot Issues After Flashing

If a CM5-based uConsole fails to boot consistently from SD:

- let the first-boot helper inspect the EEPROM settings
- apply the recommended CM5 EEPROM profile when prompted
- reboot after the EEPROM update has been written

## UI Layout Problems

If the launcher or UI feels wrong on the internal panel:

- confirm the image booted with the ClockworkPi uConsole overlay
- check that `/boot/firmware/config.txt` contains the expected uConsole overlay lines
- verify the internal panel is running at the expected 1280x720 geometry
