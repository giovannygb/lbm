# LBM — Loopback Mount Manager

LBM (Loopback Mount Manager) is a Magisk module that allows mounting filesystem images stored on a removable SD card directly into Android application paths using loopback and bind mounts.

The primary goal is to offload selected application data from internal storage to SD-backed filesystem images while preserving Android compatibility and SELinux contexts.

---

# Features

* Mount ext4 or f2fs images from removable SD storage
* Automatic image creation and resizing
* Automatic filesystem initialization
* Offline ext4 filesystem resizing
* First-run data population
* SELinux context restoration
* Runtime bind mounts
* Automatic SD card bootstrap
* Fully configuration-driven
* Magisk-native boot integration

---

# Repository Structure

```text
.
├── module.prop
├── src/
│   ├── action.sh
│   ├── service.sh
│   ├── helpers.sh
│   └── env.sh
├── skeleton/
│   └── external/
│       ├── configs/
│       ├── images/
│       └── logs/
└── tools/
    └── build.bat
```

---

# How It Works

LBM creates loopback filesystem images on the removable SD card and mounts them into Android paths using bind mounts.

Mount flow:

```text
SD Image (.img)
    ↓
Loop Mount
    ↓
Runtime Mountpoint
    ↓
Bind Mount
    ↓
Android App/Data Path
```

---

# External SD Structure

LBM automatically bootstraps the following structure on the removable SD card:

```text
/storage/XXXX-XXXX/lbm/
├── configs/
├── images/
└── logs/
```

---

# Configuration Guide

Each mount configuration is stored as:

```text
/storage/XXXX-XXXX/lbm/configs/<name>.conf
```

The configuration filename is used as the internal mount identifier.

Example:

```text
/storage/XXXX-XXXX/lbm/configs/vita3k.conf
```

Will automatically create:

```text
/storage/XXXX-XXXX/lbm/images/vita3k.img
```

And mount internally at:

```text
/data/adb/modules/lbm/runtime/mounts/vita3k
```

---

# Configuration Fields

> The image filename is derived automatically from the `.conf` filename.

---

## TARGET

Destination path to bind mount into.

Example:

```ini
TARGET=/data/data/app.gamenative
```

LBM will:

1. Mount the image internally
2. Bind the mounted image to this path

---

## FS

Filesystem type.

Supported:

* `ext4`
* `f2fs` (HIGHLY EXPERIMENTAL)

Example:

```ini
FS=ext4
```

---

## SIZE

Desired image size.

Supported suffixes:

* `M`
* `G`

Examples:

```ini
SIZE=512M
SIZE=32G
```

Behavior:

* Creates image if missing
* Grows image if larger than current
* Resizes filesystem automatically

---

## FS_FLAGS

Filesystem creation flags.

Passed directly to the filesystem creation utility.

Example:

```ini
FS_FLAGS=-O ^has_journal
```

### Recommended ext4 flags for SD cards

```ini
FS_FLAGS=-O ^has_journal
```

Disables journaling to reduce SD card write amplification.

### Recommended f2fs flags

```ini
FS_FLAGS=-O extra_attr
```

---

## MOUNT_FLAGS

Mount-time filesystem flags.

Passed directly to `mount -o`.

Example:

```ini
MOUNT_FLAGS=loop,noatime,nodiratime
```

### Recommended flags for SD cards

```ini
MOUNT_FLAGS=loop,noatime,nodiratime
```

Optional:

```ini
discard
```

Only recommended if the SD card firmware handles TRIM correctly.

---

# Example Configurations

## Vita3K (Recommended)

```ini
TARGET=/data/media/0/Android/data/org.vita3k.emulator
FS=ext4
SIZE=8G
FS_FLAGS=-b 4096 -i 16384 -T small -O ^has_journal,dir_index,filetype,extent,uninit_bg -E stride=512,stripe-width=512
MOUNT_FLAGS=loop,noatime,nodiratime
```

Recommended for:

* Emulator data
* Moderate write workloads
* Portable storage-heavy applications

---

## Large GameNative Data

```ini
TARGET=/data/data/app.gamenative
FS=ext4
SIZE=32G
FS_FLAGS=-b 4096 -i 16384 -T small -O ^has_journal,dir_index,filetype,extent,uninit_bg -E stride=512,stripe-width=512
MOUNT_FLAGS=loop,noatime,nodiratime
```

Recommended for:

* Large games
* Asset-heavy applications
* High-capacity storage migration

---

# Runtime Structure

LBM uses the following runtime directory:

```text
/data/adb/modules/lbm/runtime/
├── logs/
│   └── module.log
└── mounts/
```

---

# Runtime Mountpoints

Mounted images are attached under:

```text
/data/adb/modules/lbm/runtime/mounts/<name>
```

Example:

```text
/data/adb/modules/lbm/runtime/mounts/vita3k
```

---

# First Run Population

On first mount:

1. The image is mounted
2. Existing contents from `TARGET` are copied into the image
3. A marker file is created:

```text
.lbm_populated
```

Future boots skip population.

---

# Filesystem Resizing

## ext4

Performed offline:

1. Unbind target
2. Unmount image
3. Run `e2fsck`
4. Run `resize2fs`
5. Remount and rebind

## f2fs

Performed using `resize.f2fs`.

---

# Resize Limitations

Large image creation and resizing operations are slow on Android devices, especially on removable SD cards.

Practical recommendations:

* Avoid resizing images by more than 32GB in a single operation
* Large resize operations may trigger Android watchdog reboots
* ext4 offline resizing is CPU and I/O intensive
* SD card speed heavily impacts resize time

Approximate timings:

| Operation          | Estimated Time  |
| ------------------ | --------------- |
| 4GB image creation | ~1 minute       |
| 8GB image creation | ~2 minutes      |
| 32GB resize        | Several minutes |

These values vary significantly depending on:

* SD card speed
* Filesystem type
* Device storage controller
* Android kernel behavior

For best stability:

* Grow images incrementally
* Avoid resizing during low battery
* Prefer A2-rated SD cards

---

# Logging

LBM logs to:

```text
/data/adb/modules/lbm/runtime/logs/module.log
```

On failure, logs may also be copied to:

```text
/ storage/XXXX-XXXX/lbm/logs/
```

---

# Build Instructions

Requirements:

* Windows
* ADB
* MSYS2 `zip`

Build:

```bat
tools\build.bat
```

The script will:

1. Build the Magisk ZIP
2. Push it to the connected device
3. Attempt installation through Magisk CLI
4. Reboot the device

---

# Installation

## Automatic

Use:

```bat
tools\build.bat
```

## Manual

1. Build ZIP
2. Open Magisk
3. Modules
4. Install from storage
5. Reboot

---

# Manual Installation (Magisk App)

1. Download or build the latest LBM release ZIP
2. Copy the ZIP file to the removable SD card or internal storage
3. Open the Magisk app
4. Go to:

   * Modules
   * Install from storage
5. Select the LBM ZIP file
6. Wait for installation to complete
7. Reboot the device

After reboot:

1. Open the removable SD card:

   ```text id="jlwm96"
   /storage/XXXX-XXXX/lbm/
   ```

2. Create a configuration file inside:

   ```text id="jlwm97"
   /storage/XXXX-XXXX/lbm/configs/
   ```

Example:

```text id="jlwm98"
vita3k.conf
```

3. Edit the configuration file with the desired mount settings

Example:

```ini id="jlwm99"
TARGET=/data/media/0/Android/data/org.vita3k.emulator
FS=ext4
SIZE=8G
FS_FLAGS=-b 4096 -i 16384 -T small -O ^has_journal,dir_index,filetype,extent,uninit_bg -E stride=512,stripe-width=512
MOUNT_FLAGS=loop,noatime,nodiratime
```

4. Return to the Magisk module list
5. Locate the LBM module
6. Press the module action button
7. Wait for image creation and initialization to complete

The first initialization may take several minutes depending on:

* Image size
* SD card speed
* Filesystem type

After completion, rebooting the device is recommended.

---

# Important Notes

## SD Card Performance

Recommended:

* A2-rated SD cards
* High endurance cards

Avoid:

* Slow generic SD cards
* USB storage adapters

---

## Filesystem Choice

### ext4

Pros:

* Stable
* Mature
* Reliable resizing

Cons:

* Higher write amplification

### f2fs

Pros:

* Flash optimized
* Lower write amplification

Cons:

* Less mature tooling on Android
* Experimental support in LBM

---

# Safety Notes

LBM performs:

* loop mounts
* bind mounts
* filesystem resizing

Incorrect configurations may:

* Break application storage
* Cause boot loops
* Corrupt data

Always:

* Keep backups
* Test incrementally
* Avoid moving critical system apps first

---

# Recommended Usage

Good candidates:

* Games
* Large app caches
* Emulator data
* Download-heavy applications

Avoid:

* Core system apps
* Encryption-sensitive apps
* Credential storage

---

# Disclaimers

LBM is an independent project and is not affiliated with, endorsed by, sponsored by, or officially associated with any third-party projects, applications, organizations, or trademarks referenced in this repository or documentation.

Projects mentioned throughout the documentation — including, but not limited to:

- Magisk
- GameNative
- Vita3K

are referenced exclusively for:
- compatibility information
- technical examples
- real-world configuration demonstrations

All trademarks, product names, and project names belong to their respective owners.

LBM is provided as-is, without warranty of any kind. Use at your own risk.

---

# License

This project is provided as-is without warranty under the Unlicense.
