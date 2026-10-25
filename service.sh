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

for p in /data/adb/ksu /data/adb/ksud; do
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

# The SDE debug block ships armed to panic() on the first display error
# (panic_on_err defaults to 1). A recoverable DPU fault then reboots the phone
# with no log anyone can read afterwards. Keep the register dump, drop the
# panic: errors still land in dmesg, the phone stays up.
for d in /sys/kernel/debug/dri/0/debug/panic /sys/kernel/debug/sde_rotator0/evtlog/panic; do
    [ -w "$d" ] && echo 0 > "$d" 2>/dev/null
done

# Keep the panel at 120 Hz. 60 Hz stays advertised for video apps that ask for
# it, but leaving the minimum at 0 lets Android drop an idle screen to 60 and
# pull it straight back, which on this panel is a visible re-timing.
settings put system min_refresh_rate 120
settings put system peak_refresh_rate 120

# Record every boot in /data/local/tmp/bootlog so an unexplained restart can be
# explained from the next boot (a soft reboot leaves no last_kmsg).
if [ -x "$MODDIR/bootlog.sh" ]; then
    "$MODDIR/bootlog.sh" >/dev/null 2>&1 &
fi

sync
