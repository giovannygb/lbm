# Configuration Reference

## Overview

Each mount configuration is stored as a `.conf` file on the removable SD card:

```
/storage/XXXX-XXXX/lbm/configs/<name>.conf
```

The configuration filename (without `.conf`) is used as the internal mount identifier and determines the image filename.

Example — `/storage/XXXX-XXXX/lbm/configs/vita3k.conf`:

- Creates image: `/storage/XXXX-XXXX/lbm/images/vita3k.img`
- Mounts at: `/data/adb/modules/lbm/runtime/mounts/vita3k`

`default.conf` is reserved and ignored by the module.

## Fields

### TARGET

Destination path to bind mount into.

```
TARGET=/data/data/app.gamenative
```

LBM mounts the image internally, then bind mounts it to this path.

### FS

Filesystem type.

| Value | Support |
|---|---|
| `ext4` | Stable |
| `f2fs` | Highly experimental |

```
FS=ext4
```

### SIZE

Desired image size. Supported suffixes: `M`, `G`.

```
SIZE=512M
SIZE=32G
```

Behavior:

- Creates the image if missing.
- Grows the image if larger than current.
- Resizes the filesystem automatically.

### FS_FLAGS

Filesystem creation flags, passed directly to `mkfs.ext4` or `mkfs.f2fs`.

**Recommended ext4 flags for SD cards:**

```
FS_FLAGS=-O ^has_journal
```

Disables journaling to reduce write amplification.

**Recommended ext4 flags for performance:**

```
FS_FLAGS=-b 4096 -i 16384 -T small -O ^has_journal,dir_index,filetype,extent,uninit_bg -E stride=512,stripe-width=512
```

Recommended for:
- Emulator data
- Moderate write workloads
- Portable storage-heavy applications

**Recommended f2fs flags:**

```
FS_FLAGS=-O extra_attr
```

### MOUNT_FLAGS

Mount-time filesystem flags, passed directly to `mount -o`.

**Recommended:**

```
MOUNT_FLAGS=loop,noatime,nodiratime
```

Optional: add `discard` only if the SD card firmware handles TRIM correctly.

## Example Configurations

### Vita3K

```ini
TARGET=/data/media/0/Android/data/org.vita3k.emulator
FS=ext4
SIZE=8G
FS_FLAGS=-b 4096 -i 16384 -T small -O ^has_journal,dir_index,filetype,extent,uninit_bg -E stride=512,stripe-width=512
MOUNT_FLAGS=loop,noatime,nodiratime
```

Recommended for:
- Emulator data
- Moderate write workloads
- Portable storage-heavy applications

### Large GameNative Data

```ini
TARGET=/data/data/app.gamenative
FS=ext4
SIZE=32G
FS_FLAGS=-b 4096 -i 16384 -T small -O ^has_journal,dir_index,filetype,extent,uninit_bg -E stride=512,stripe-width=512
MOUNT_FLAGS=loop,noatime,nodiratime
```

Recommended for:
- Large games
- Asset-heavy applications
- High-capacity storage migration

## First-Run Population

On first mount:

1. The image is mounted.
2. Existing contents from `TARGET` are copied into the image.
3. A `.lbm_populated` marker is written inside the mounted image.

Future boots skip population.

## Runtime Structure

```
/data/adb/modules/lbm/runtime/
├── logs/
│   └── module.log
└── mounts/
    └── <name>   # Mounted image for each config
```

## Logging

LBM logs to `/data/adb/modules/lbm/runtime/logs/module.log`. On failure, logs may also be copied to `/storage/XXXX-XXXX/lbm/logs/`.

## SELinux Context

After bind mounting, LBM runs `restorecon -RD` on the target path to apply the correct SELinux context. This runs during action button execution only.

## Filesystem Resizing

### ext4

Performed offline:

1. Unbind the target.
2. Unmount the image.
3. Run `e2fsck -fy`.
4. Run `resize2fs`.
5. Remount and rebind.

### f2fs

Performed using `resize.f2fs`.

### Limitations

Large image creation and resizing are slow on Android, especially on removable SD cards.

| Operation | Estimated Time |
|---|---|
| 4GB image creation | ~1 minute |
| 8GB image creation | ~2 minutes |
| 32GB resize | Several minutes |

Actual times vary with SD speed, filesystem type, device controller, and kernel behavior.

Recommendations:
- Avoid resizing by more than 32GB in a single operation.
- Large resizes may trigger Android watchdog reboots.
- Grow images incrementally.
- Avoid resizing during low battery.
- Prefer A2-rated SD cards.

## SD Card Performance

Recommended:
- A2-rated SD cards
- High endurance cards

Avoid:
- Slow generic SD cards
- USB storage adapters

## Filesystem Choice

### ext4

Pros:
- Stable
- Mature
- Reliable resizing

Cons:
- Higher write amplification

### f2fs

Pros:
- Flash optimized
- Lower write amplification

Cons:
- Less mature tooling on Android
- Experimental support in LBM

## Recommended Usage

Good candidates:
- Games
- Large app caches
- Emulator data
- Download-heavy applications

Avoid:
- Core system apps
- Encryption-sensitive apps
- Credential storage

## Safety Notes

LBM performs loop mounts, bind mounts, and filesystem resizing. Incorrect configurations may break application storage, cause boot loops, or corrupt data.

Always:
- Keep backups
- Test incrementally
- Avoid moving critical system apps first
