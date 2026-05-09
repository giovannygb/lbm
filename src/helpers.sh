#!/system/bin/sh

# =========================
# SYSTEM HELPERS
# =========================

log() {
    msg="$1"
    echo "[LBM] $msg" | tee -a "$RUNTIME_LOG"
}

require_tool() {
    command -v "$1" >/dev/null 2>&1
}

detect_external_storage() {
    for path in /storage/*; do
        [ ! -d "$path" ] && continue

        case "$path" in
            */emulated|*/self)
                continue
                ;;
        esac

        echo "$path"
        return 0
    done

    return 1
}

# =========================
# CONFIG HELPERS
# =========================

read_configs() {
    for f in "$CONFIG_DIR"/*.conf; do
        [ ! -f "$f" ] && continue
        [ "$(basename "$f")" = "default.conf" ] && continue
        echo "$f"
    done
}

# =========================
# IMAGE HELPERS
# =========================

size_to_bytes() {
    size="$1"

    case "$size" in
        *G|*g)
            val=$(echo "$size" | sed 's/[Gg]//')
            echo $((val * 1024 * 1024 * 1024))
            ;;
        *M|*m)
            val=$(echo "$size" | sed 's/[Mm]//')
            echo $((val * 1024 * 1024))
            ;;
        *)
            return 1
            ;;
    esac
}

image_exists() {
    [ -f "$IMAGE_DIR/$1.img" ]
}

write_chunks() {
    img="$1"
    start_mb="$2"
    total_mb="$3"

    chunk_mb=1024
    written_mb=0

    while [ "$written_mb" -lt "$total_mb" ]; do
        remaining=$((total_mb - written_mb))

        if [ "$remaining" -ge "$chunk_mb" ]; then
            write_now=$chunk_mb
        else
            write_now=$remaining
        fi

        current_offset=$((start_mb + written_mb))
        progress=$((written_mb * 100 / total_mb))

        log "Progress: ${progress}% (+${written_mb}/${total_mb} MB)"

        dd if=/dev/zero of="$img" \
            bs=1M count="$write_now" seek="$current_offset" \
            conv=notrunc 2>/dev/null || {
            log "dd failed at ${current_offset}MB"
            return 1
        }

        written_mb=$((written_mb + write_now))
    done

    return 0
}

image_create() {
    id="$1"
    size="$2"

    img="$IMAGE_DIR/$id.img"

    image_exists "$id" && return 0

    total_bytes=$(size_to_bytes "$size") || {
        log "Invalid size format: $size"
        return 1
    }

    total_mb=$((total_bytes / 1024 / 1024))

    mkdir -p "$IMAGE_DIR" || return 1

    rm -f "$img"

    log "Creating image: $img ($total_mb MB)"

    write_chunks "$img" 0 "$total_mb" || return 1

    log "Image creation complete: $img"

    return 0
}

image_grow() {
    id="$1"
    size="$2"

    img="$IMAGE_DIR/$id.img"

    image_exists "$id" || return 1

    target_bytes=$(size_to_bytes "$size") || {
        log "Invalid size format: $size"
        return 1
    }

    current_bytes=$(stat -c%s "$img") || return 1

    if [ "$target_bytes" -le "$current_bytes" ]; then
        log "No growth needed for $img"
        return 0
    fi

    current_mb=$((current_bytes / 1024 / 1024))
    target_mb=$((target_bytes / 1024 / 1024))
    grow_mb=$((target_mb - current_mb))

    log "Growing image: $img (+$grow_mb MB)"

    write_chunks "$img" "$current_mb" "$grow_mb" || return 1

    log "Image grow complete: $img"

    return 0
}

# =========================
# FILESYSTEM HELPERS
# =========================

is_fs_initialized() {
    id="$1"
    fs="$2"

    img="$IMAGE_DIR/$id.img"

    fs_detected=$(
        blkid "$img" 2>/dev/null | \
        sed -n 's/.*TYPE="\([^"]*\)".*/\1/p'
    )

    [ "$fs_detected" = "$fs" ]
}

image_fs_create() {
    id="$1"
    fs="$2"
    fs_flags="$3"

    img="$IMAGE_DIR/$id.img"

    is_fs_initialized "$id" "$fs" && {
        log "Filesystem already initialized for $id"
        return 0
    }

    log "Creating filesystem ($fs) on $img (flags=$fs_flags)"

    case "$fs" in
        ext4)
            require_tool mkfs.ext4 || {
                log "mkfs.ext4 not available"
                return 1
            }

            mkfs.ext4 -F -t ext4 $fs_flags "$img" >> "$RUNTIME_LOG" 2>&1 || {
                log "ext4 creation failed for $id"
                return 1
            }
            ;;

        f2fs)
            require_tool mkfs.f2fs || {
                log "mkfs.f2fs not available"
                return 1
            }

            mkfs.f2fs $fs_flags "$img" >/dev/null 2>&1 || {
                log "f2fs creation failed for $id"
                return 1
            }
            ;;

        *)
            log "Unsupported filesystem: $fs"
            return 1
            ;;
    esac

    log "Filesystem created for $id"

    return 0
}

image_unbind() {
    target="$1"

    mountpoint -q "$target" || return 0

    umount "$target" || {
        log "Failed to unbind $target"
        return 1
    }

    return 0
}

image_unmount() {
    id="$1"

    mountpoint="$MOUNT_DIR/$id"

    is_mounted "$mountpoint" || return 0

    umount "$mountpoint" || {
        log "Failed to unmount $mountpoint"
        return 1
    }

    return 0
}

image_get_loop() {
    id="$1"

    img="$IMAGE_DIR/$id.img"

    losetup -j "$img" 2>/dev/null | cut -d: -f1
}

image_loop_detach() {
    id="$1"

    loopdev=$(image_get_loop "$id")

    [ -z "$loopdev" ] && return 0

    losetup -d "$loopdev" || {
        log "Failed to detach loop device: $loopdev"
        return 1
    }

    return 0
}

image_fs_resize() {
    id="$1"
    fs="$2"

    img="$IMAGE_DIR/$id.img"

    image_exists "$id" || {
        log "Resize failed: image not found ($img)"
        return 1
    }

    case "$fs" in
        ext4)
            require_tool e2fsck || {
                log "e2fsck not available"
                return 1
            }

            require_tool resize2fs || {
                log "resize2fs not available"
                return 1
            }

            log "Running e2fsck on $img"

            e2fsck -fy "$img" >/dev/null 2>&1 || {
                log "e2fsck failed for $id"
                return 1
            }

            log "Running resize2fs on $img"

            resize2fs "$img" >/dev/null 2>&1 || {
                log "resize2fs failed for $id"
                return 1
            }

            log "ext4 resize completed for $id"
            ;;

        f2fs)
            require_tool resize.f2fs || {
                log "resize.f2fs not available"
                return 1
            }

            log "Running resize.f2fs on $img"

            resize.f2fs "$img" >/dev/null 2>&1 || {
                log "resize.f2fs failed for $id"
                return 1
            }

            log "f2fs resize completed for $id"
            ;;

        *)
            log "Unsupported filesystem: $fs"
            return 1
            ;;
    esac

    return 0
}

# =========================
# MOUNT HELPERS
# =========================

is_mounted() {
    mountpoint="$1"
    mount | grep -q " $mountpoint "
}

image_mount() {
    id="$1"
    mount_flags="$2"

    img="$IMAGE_DIR/$id.img"
    mountpoint="$MOUNT_DIR/$id"

    mkdir -p "$mountpoint"

    is_mounted "$mountpoint" && return 0

    if [ -n "$mount_flags" ]; then
        opts="loop,$mount_flags"
    else
        opts="loop"
    fi

    log "Mounting $img → $mountpoint (opts=$opts)"

    mount -o "$opts" "$img" "$mountpoint" || {
        log "Mount failed for $img"
        dmesg | tail -20 >> "$RUNTIME_LOG" 2>/dev/null
        return 1
    }

    is_mounted "$mountpoint" || {
        log "Mount verification failed for $mountpoint"
        return 1
    }

    return 0
}

image_bind() {
    id="$1"
    target="$2"

    src="$MOUNT_DIR/$id"

    mkdir -p "$target"

    mountpoint -q "$target" && return 0

    mount --bind "$src" "$target" || {
        log "Bind mount failed: $src → $target"
        return 1
    }

    restorecon -R "$target" 2>/dev/null

    return 0
}

image_populate() {
    id="$1"
    target="$2"

    marker="$MOUNT_DIR/$id/.lbm_populated"

    [ -f "$marker" ] && return 0

    log "Populating image $id from $target"

    cp -a "$target"/. "$MOUNT_DIR/$id"/ 2>/dev/null || {
        log "Populate copy failed for $id"
        return 1
    }

    touch "$marker"

    return 0
}