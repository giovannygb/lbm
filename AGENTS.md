# LBM — Loopback Mount Manager

## Project

Magisk module that mounts ext4/f2fs images from removable SD into Android app paths via loopback + bind mounts.

Module ID: `lbm`, version: `0.1.1`.

## Structure

```
src/           → module scripts (run on device under /system/bin/sh)
  action.sh    → Magisk action button entrypoint: creates images, formats, mounts, populates
  service.sh   → late_start service: waits for SD, mounts existing images at boot
  helpers.sh   → all utility functions
  env.sh       → paths (MODULE_BASE, RUNTIME, MOUNT_DIR, BOOT_TIMEOUT=30)
skeleton/      → bootstrapped to SD card on first action
  external/    → configs/, images/, logs/
  internal/    → runtime/ structure (logs/, mounts/)
tools/
  build.bat    → Windows-only build script
module.prop    → Magisk module metadata
```

## Build & deployment (Windows only)

```
tools\build.bat
```

Stages files from `src/` + `skeleton/`, creates `build/lbm.zip`, ADB-pushes it, runs `magisk --install-module`, reboots.

Requires: ADB, MSYS2 `zip`.

## Key facts

- No tests, no CI, no linters, no formatters, no typecheckers
- `build/` is gitignored — rebuild after clone
- All scripts run in Android shell (`/system/bin/sh`) with `set -e` (service.sh) or `set -ex` (action.sh)
- Config files live at `/storage/XXXX-XXXX/lbm/configs/*.conf` — `default.conf` is skipped, every other `.conf` is a mount target
- Scripts strip `\r` from configs (action.sh) or use simple `IFS='='` parsing (service.sh)
- Image filenames derive from config basename: `vita3k.conf` → `vita3k.img`
- First-run copies existing target contents into image and writes `.lbm_populated` marker
- f2fs support is experimental
- No ADB or USB debugging requirement enforced — build script pushes via ADB but module runs standalone on device
