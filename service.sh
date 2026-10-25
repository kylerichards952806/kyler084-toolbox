#!/system/bin/sh
# Late-boot enforcement. The SUSFS module's boot-completed script returns early
# on kernels that have AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT (ours does), which
# skips its sus_path pass. Apply the profile here instead, and put the config
# back if a boot-time write left it empty.
MODDIR=$(cd "$(dirname "$0")" && pwd)
. "$MODDIR/common.sh"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done
sleep 30

[ -d "$SUSFS_DIR" ] || exit 0

# Restore the profile if boot ate it.
if file_blank "$SUSFS_DIR/config.sh"; then
    cp "$MODDIR/profile.sh" "$SUSFS_DIR/config.sh"
fi

[ -x "$SUSFS_BIN" ] || exit 0

"$SUSFS_BIN" enable_log 1 >/dev/null 2>&1

for p in /data/adb/ksu /data/adb/ksud /data/adb/susfs4ksu; do
    "$SUSFS_BIN" add_sus_path "$p" >/dev/null 2>&1
done

"$SUSFS_BIN" add_try_umount /debug_ramdisk 1 >/dev/null 2>&1
"$SUSFS_BIN" hide_sus_mnts_for_non_su_procs 0 >/dev/null 2>&1

# The SUSFS module rewrites its own module.prop with a status line late in
# boot; on this device that write has come back as zeroes, which makes the
# manager show a broken module. Put the metadata back.
mp=/data/adb/modules/susfs4ksu/module.prop
if [ -f "$mp" ] && file_blank "$mp" && [ -s "$MODDIR/susfs-module.prop" ]; then
    cat "$MODDIR/susfs-module.prop" > "$mp"
fi

sync
