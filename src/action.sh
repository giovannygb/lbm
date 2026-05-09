#!/system/bin/sh
set -ex
trap 'echo "[LBM] Script interrupted on line $LINENO" >> /tmp/magisk.log' EXIT

# Load environment + helpers
MODDIR="${0%/*}"
. "$MODDIR/env.sh"
. "$MODDIR/helpers.sh"

# Init runtime log
mkdir -p "$RUNTIME/logs"
: > "$RUNTIME_LOG"

log "Starting action.sh execution"

SDCARD_ROOT="$(detect_external_storage)"

EXTERNAL_BASE="$SDCARD_ROOT/lbm"

CONFIG_DIR="$EXTERNAL_BASE/configs"
IMAGE_DIR="$EXTERNAL_BASE/images"
LOG_DIR="$EXTERNAL_BASE/logs"

# Bootstrap SD structure if missing
if [ ! -e "$CONFIG_DIR/default.conf" ]; then
    log "Bootstrapping external structure"

    mkdir -p "$EXTERNAL_BASE" || exit 1

    cp -r "$MODDIR/external/." "$EXTERNAL_BASE/" || {
        log "Bootstrap copy failed"
        exit 1
    }
fi

# Process each config
read_configs | while IFS= read -r cfg; do
    log "Processing config: $cfg"

    # Reset variables
    ID="$(basename "$cfg" .conf)"
    TARGET=""
    FS=""
    SIZE=""
    FS_FLAGS=""
    MOUNT_FLAGS=""

    # Safe parse (no eval)
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove CR (Windows line endings)
        line=$(echo "$line" | tr -d '\r')

        # Skip empty lines and comments
        case "$line" in
            ""|\#*) continue ;;
        esac

        # Split only on first '='
        key="${line%%=*}"
        value="${line#*=}"

        # Trim whitespace
        key="$(echo "$key" | sed 's/^[ \t]*//;s/[ \t]*$//')"
        value="$(echo "$value" | sed 's/^[ \t]*//;s/[ \t]*$//')"

        case "$key" in
            TARGET) TARGET="$value" ;;
            FS) FS="$value" ;;
            SIZE) SIZE="$value" ;;
            FS_FLAGS) FS_FLAGS="$value" ;;
            MOUNT_FLAGS) MOUNT_FLAGS="$value" ;;
        esac
    done < "$cfg"

    # Validate required fields
    if [ -z "$ID" ] || [ -z "$TARGET" ] || [ -z "$FS" ] || [ -z "$SIZE" ]; then
        log "ID: $ID TARGET: $TARGET FS: $FS SIZE: $SIZE"
        log "Invalid config: $cfg (missing required fields)"
        continue
    fi

    log "ID=$ID TARGET=$TARGET FS=$FS SIZE=$SIZE"

    # Ensure mount dir exists
    mkdir -p "$MOUNT_DIR/$ID"

    # --- PREPARE OFFLINE RESIZE ---
    if mountpoint -q "$TARGET"; then
        log "Unbinding $TARGET"

        umount "$TARGET" || {
            log "Failed to unbind $TARGET"
            continue
        }
    fi

    if is_mounted "$MOUNT_DIR/$ID"; then
        log "Unmounting $ID"

        umount "$MOUNT_DIR/$ID" || {
            log "Failed to unmount $ID"
            continue
        }
    fi

    # --- IMAGE MANAGEMENT ---

    image_create "$ID" "$SIZE" || {
        log "Failed to create image for $ID"
        continue
    }

    image_fs_create "$ID" "$FS" "$FS_FLAGS" || {
        log "Failed to create filesystem for $ID"
        continue
    }

    image_grow "$ID" "$SIZE" "$FS_FLAGS" || {
        log "Failed to grow image for $ID"
        continue
    }

    # Resize BEFORE mount for ext4
    image_fs_resize "$ID" "$FS" || {
        log "Resize failed for $ID"
    }

    # --- MOUNT IMAGE ---
    image_mount "$ID" "$MOUNT_FLAGS" || {
        log "Mount failed for $ID"
        continue
    }

    # --- POPULATE FIRST RUN ---

    image_populate "$ID" "$TARGET" || {
        log "Populate failed for $ID"
    }

    # --- PERMISSION FIX (SAFE) ---

    chmod 0755 "$MOUNT_DIR/$ID" 2>/dev/null || true

    # --- BIND MOUNT ---

    image_bind "$ID" "$TARGET" || {
        log "Bind mount failed for $ID"
        continue
    }

    log "Completed setup for $ID"
done

log "action.sh completed successfully"
exit 0
