# LBM — Loopback Mount Manager

LBM is a Magisk module that mounts ext4 or f2fs filesystem images from a removable SD card into Android app paths using loopback and bind mounts. It offloads app data from internal storage to SD-backed images while preserving compatibility and SELinux contexts.

## Quick Start

1. Install the module in Magisk and reboot the device.
2. Copy a sample `.conf` file from [configs/](configs/) to `/storage/XXXX-XXXX/lbm/configs/` on your SD card and adjust the fields for your target.
3. Open Magisk, find LBM in the module list, and press the action button.
4. Wait for image creation and data population to finish. Reboot.

## Tutorial

### 1. Identify the target

Find the app's data directory. Common prefixes:

- `/data/data/<package>/`
- `/data/user/0/<package>/`
- `/data/media/0/Android/data/<package>/`

Check its current size:

```sh
du -h /data/data/com.example.app
```

### 2. Create the config

Write a `.conf` file in `/storage/XXXX-XXXX/lbm/configs/` with `SIZE` set well above what `du` reported — account for future growth. See [Configuration](#configuration) for all fields.

### 3. Mount

Open Magisk, find LBM in the module list, and press the action button. Wait for image creation and data population to finish. Reboot.

### 4. Verify the mount

After reboot, confirm the mount is active:

```sh
df -h /path/to/target
```

The output should show a loop device (`/dev/block/loop*`) as the filesystem and a size matching or exceeding the config. The app data should still be accessible.

### 5. Open the app

Launch the app and confirm it works normally.

## Cleanup

1. Disable the LBM module in Magisk.
2. Reboot the device.
3. Clear the app's storage and cache (Android Settings → Apps).
4. Open the app — it should behave as a fresh install.
5. Re-enable the LBM module in Magisk.
6. Press the action button again to recreate and repopulate the image.
7. Reboot and verify the app data is restored.

## Configuration

| Key | Required | Default | Description |
|---|---|---|---|
| `TARGET` | Yes | — | Destination path to bind mount into |
| `FS` | Yes | — | Filesystem type: `ext4` or `f2fs` (experimental) |
| `SIZE` | Yes | — | Image size: `512M`, `8G`, `32G` |
| `FS_FLAGS` | No | *(none)* | Flags for `mkfs.ext4` / `mkfs.f2fs` |
| `MOUNT_FLAGS` | No | `loop` | Mount flags for `mount -o` |

Detailed field documentation in [docs/configuration.md](docs/configuration.md).  
Sample configurations in [configs/](configs/).

## Repository Structure

```
├── module.prop
├── src/
│   ├── action.sh      # Action button entrypoint
│   ├── service.sh     # Boot-time late_start service
│   ├── helpers.sh     # All utility functions
│   └── env.sh         # Paths and configuration
├── skeleton/          # Bootstrapped to SD card on first action
│   └── external/
│       ├── configs/
│       ├── images/
│       └── logs/
└── tools/
    └── build.bat      # Windows-only build script
```

## Build

```bat
tools\build.bat
```

Requires Windows, ADB, and MSYS2 `zip`. Builds `build/lbm.zip`, pushes to device, installs via Magisk CLI, and reboots.

## Reference

Detailed documentation for configuration fields, filesystem options, resizing, SELinux, and runtime structure is in [docs/configuration.md](docs/configuration.md).

## License

Unlicense — see [UNLICENSE](UNLICENSE).
