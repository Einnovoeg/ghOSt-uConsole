# Build And Flash

## Host Recommendations

- Ubuntu 22.04 or 24.04 x86_64 for native builds
- 8 GB RAM or more preferred
- 100 GB free disk space recommended
- 64 GB or larger target microSD card

## Native Build

```bash
sudo ./build.sh
```

## Docker Build

```bash
docker compose up --build
```

The default compressed output path is:

```text
build/output/ghOSt-uConsole-1.0.0.img.gz
```

## Flashing

Use one of the helper scripts:

```bash
./flash_dd_with_gpt.sh
./flash_dd_with_gpt.MacOS.sh
```

Or use Balena Etcher if you prefer a GUI workflow.

## First Boot

On first boot the image:

1. Prompts for the `ghost` password.
2. Sets the timezone.
3. Generates SSH keys and displays the public key as text and QR.
4. Offers `hey` API key setup.
5. Offers Wi-Fi setup in `nmtui`.
6. Offers a CM5 EEPROM update check on Compute Module 5 hardware.
7. Prepares stealth-mode storage and launcher guidance.

## Notes About Slow Or Stalled Clones

Some upstream GitHub repositories can pause long enough to make the build look frozen, especially inside Docker on slower storage or unstable networks. The build now wraps repository clones with:

- shallow clone mode
- low-speed detection
- a hard timeout
- automatic retries

If the build still stops on a network step, run it again. The build is designed to reuse prior work and continue forward rather than starting from scratch.
