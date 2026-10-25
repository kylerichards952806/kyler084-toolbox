#!/system/bin/sh
# Shared paths and helpers. Sourced by action.sh and service.sh.

PATH=/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH:/system/bin:/system/xbin

SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
SUSFS_DIR=/data/adb/susfs4ksu
PIF_DIR=/data/adb/modules/playintegrityfix
TS_DIR=/data/adb/tricky_store
TOOLBOX_DIR=/data/adb/kyler084-toolbox

# Print a section header.
section() {
    printf '\n== %s ==\n' "$*"
}

ok() { printf '  [ok]   %s\n' "$*"; }
fix() { printf '  [fix]  %s\n' "$*"; }
warn() { printf '  [warn] %s\n' "$*"; }

# suspend/resume style test for a non-empty file that is not all zero bytes
file_blank() {
    [ -s "$1" ] || return 0
    # tr -d '\0' leaves nothing behind for a zero-filled file
    [ -z "$(tr -d '\000' < "$1")" ]
}

# Read a key from a KEY=value file, last occurrence wins.
prop_get() {
    sed -n "s/^$2=//p" "$1" 2>/dev/null | tail -1
}

# Replace KEY=value in place without sed -i: on this device an in-place edit
# during early boot could leave the file zero-filled, so write through a temp.
prop_set() {
    file=$1 key=$2 val=$3
    tmp="$file.tmp.$$"
    sed "s|^${key}=.*|${key}=${val}|" "$file" > "$tmp" 2>/dev/null && cat "$tmp" > "$file"
    rm -f "$tmp"
    if ! grep -q "^${key}=" "$file" 2>/dev/null; then
        printf '%s=%s\n' "$key" "$val" >> "$file"
    fi
}

# ROM's own security patch, e.g. 2026-10-05.
rom_patch() {
    getprop ro.build.version.security_patch
}
