#!/system/bin/sh
set -e
trap 'echo "[LBM] service.sh interrupted on line $LINENO" >> /tmp/magisk.log' EXIT

MODDIR="${0%/*}"
. "$MODDIR/env.sh"
. "$MODDIR/helpers.sh"

# Prepare runtime dirs
mkdir -p "$MOUNT_DIR"
mkdir -p "$RUNTIME/logs"

# Reset runtime log each boot
: > "$RUNTIME_LOG"

log "Starting service.sh (late_start)"

# --- WAIT FOR SYSTEM READINESS ---
# Avoid early mount issues (common bootloop cause)

log "Waiting for external storage for $BOOT_TIMEOUT seconds"
i=0

while [ $i -lt $BOOT_TIMEOUT ]; do
    SDCARD_ROOT="$(detect_external_storage || true)"

    if [ -n "$SDCARD_ROOT" ]; then
        log "Detected external storage: $SDCARD_ROOT"
        break
    fi

    sleep 1
    i=$((i + 1))
done

[ -z "$SDCARD_ROOT" ] && {
    log "External SD card not found"
    exit 0
}

EXTERNAL_BASE="$SDCARD_ROOT/lbm"

CONFIG_DIR="$EXTERNAL_BASE/configs"
IMAGE_DIR="$EXTERNAL_BASE/images"
LOG_DIR="$EXTERNAL_BASE/logs"

log "Boot completed detected or timeout reached"

# --- VALIDATE SD CARD ---
if [ ! -d "$CONFIG_DIR" ] || [ ! -d "$IMAGE_DIR" ]; then
    log "External LBM directories not found, skipping"
    exit 0
fi

# --- PROCESS CONFIGS ---
read_configs | while IFS= read -r cfg; do
    log "Processing config: $cfg"

    # Reset variables
    ID="$(basename "$cfg" .conf)"
    TARGET=""
    FS=""
    SIZE=""
    FS_FLAGS=""
    MOUNT_FLAGS=""

    # Safe parsing
    while IFS='=' read -r key value; do
        case "$key" in
            TARGET) TARGET="$value" ;;
            FS) FS="$value" ;;
            SIZE) SIZE="$value" ;;
            FS_FLAGS) FS_FLAGS="$value" ;;
            MOUNT_FLAGS) MOUNT_FLAGS="$value" ;;
        esac
    done < "$cfg"

    # Validate required fields
    if [ -z "$ID" ] || [ -z "$TARGET" ]; then
        log "Invalid config: $cfg (TARGET) $ID $TARGET"
        continue
    fi

    img="$IMAGE_DIR/$ID.img"

    # Skip if image missing (action.sh responsibility)
    if [ ! -f "$img" ]; then
        log "Image missing for $ID, skipping"
        continue
    fi

    # Ensure mount dir exists
    mkdir -p "$MOUNT_DIR/$ID"

    # --- MOUNT IMAGE ---
    if ! image_mount "$ID" "$MOUNT_FLAGS"; then
        log "Mount failed for $ID"
        continue
    fi

    # --- BIND MOUNT ---
    if ! image_bind "$ID" "$TARGET"; then
        log "Bind failed for $ID"
        continue
    fi

    log "Mounted and bound $ID successfully"
done

log "service.sh completed"
exit 0
