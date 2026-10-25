#!/system/bin/sh
# Action button. Reapplies the hiding profile and repairs the integrity setup,
# then prints what state the device is actually in.
MODDIR=$(cd "$(dirname "$0")" && pwd)
. "$MODDIR/common.sh"

printf 'kyler084 toolbox\n'
printf 'kernel : %s\n' "$(uname -r)"

if [ -x "$SUSFS_BIN" ]; then
    printf 'susfs  : %s\n' "$($SUSFS_BIN show version 2>/dev/null)"
else
    printf 'susfs  : binary missing (%s)\n' "$SUSFS_BIN"
fi

changed=0

# --------------------------------------------------------------------------
# 1. SUSFS hiding profile
# --------------------------------------------------------------------------
section "SUSFS"

if [ ! -x "$SUSFS_BIN" ] || [ ! -d "$SUSFS_DIR" ]; then
    warn "SUSFS not installed, skipping hiding profile"
else
    mkdir -p "$TOOLBOX_DIR"
    [ -f "$SUSFS_DIR/config.sh" ] && ! file_blank "$SUSFS_DIR/config.sh" \
        && cp "$SUSFS_DIR/config.sh" "$TOOLBOX_DIR/config.sh.orig" 2>/dev/null

    # Same profile the kernel was set up with: hide the root stack from apps,
    # leave module/overlay mounts alone while anything is still writing them.
    # profile.sh is the single copy; service.sh puts it back if boot eats it.
    cp "$MODDIR/profile.sh" "$SUSFS_DIR/config.sh" && ok "profile applied"

    cat > "$SUSFS_DIR/sus_path.txt" <<'EOF'
/data/adb/ksu
/data/adb/ksud
EOF

    cat > "$SUSFS_DIR/try_umount.txt" <<'EOF'
/debug_ramdisk
EOF

    # Apply it now as well, so the button works without a reboot.
    "$SUSFS_BIN" enable_log 1 >/dev/null 2>&1 && ok "susfs logging on"
    while read -r p; do
        case $p in ''|'#'*) continue;; esac
        "$SUSFS_BIN" add_sus_path "$p" >/dev/null 2>&1 && ok "hidden $p"
    done < "$SUSFS_DIR/sus_path.txt"

    while read -r p; do
        case $p in ''|'#'*) continue;; esac
        "$SUSFS_BIN" add_try_umount "$p" 1 >/dev/null 2>&1 && ok "umount in apps $p"
    done < "$SUSFS_DIR/try_umount.txt"

    "$SUSFS_BIN" hide_sus_mnts_for_non_su_procs 0 >/dev/null 2>&1 \
        && ok "global mount hiding off (app-only umount instead)"

    # Verified boot state in the cmdline is the cheapest tell that a device is
    # unlocked; patch it to green like the SUSFS module does.
    if [ "$(prop_get "$SUSFS_DIR/config.sh" spoof_cmdline)" = "1" ]; then
        tmp=/dev/bootconfig-toolbox
        if grep -q verifiedbootstate /proc/bootconfig 2>/dev/null; then
            sed 's|androidboot\.verifiedbootstate[[:space:]]*=[[:space:]]*"orange"|androidboot.verifiedbootstate = "green"|g' \
                /proc/bootconfig > "$tmp" 2>/dev/null \
                && "$SUSFS_BIN" set_cmdline_or_bootconfig "$tmp" >/dev/null 2>&1 \
                && ok "bootconfig verifiedbootstate = green"
        elif grep -q 'verifiedbootstate=orange' /proc/cmdline 2>/dev/null; then
            sed 's|verifiedbootstate=orange|verifiedbootstate=green|' /proc/cmdline > "$tmp" 2>/dev/null \
                && "$SUSFS_BIN" set_cmdline_or_bootconfig "$tmp" >/dev/null 2>&1 \
                && ok "cmdline verifiedbootstate = green"
        fi
        rm -f "$tmp"
    fi

    module_ver=$(prop_get /data/adb/modules/susfs4ksu/module.prop version)
    kernel_ver=$($SUSFS_BIN show version 2>/dev/null)
    [ -n "$module_ver" ] && ok "module $module_ver / kernel $kernel_ver"
fi

# --------------------------------------------------------------------------
# 2. Play Integrity Fix
# --------------------------------------------------------------------------
section "Play Integrity Fix (Pixel 6a)"

PATCH=$(rom_patch)
if [ ! -d "$PIF_DIR" ]; then
    warn "PIF module not installed"
elif file_blank "$PIF_DIR/pif.prop"; then
    warn "pif.prop is unreadable, reinstall the PIF module"
else
    # Keep whatever is working; only repair the fields this device needs to
    # return a strong verdict (Pixel 6a beta print, no provider/signature spoof).
    want_model="Pixel 6a"
    want_mfg="Google"
    want_patch=$PATCH

    cur_model=$(prop_get "$PIF_DIR/pif.prop" MODEL)
    cur_mfg=$(prop_get "$PIF_DIR/pif.prop" MANUFACTURER)
    cur_patch=$(prop_get "$PIF_DIR/pif.prop" SECURITY_PATCH)

    [ "$cur_model" = "$want_model" ] && ok "profile $cur_model" \
        || { prop_set "$PIF_DIR/pif.prop" MODEL "$want_model"; fix "MODEL -> $want_model"; changed=1; }
    [ "$cur_mfg" = "$want_mfg" ] && ok "manufacturer $cur_mfg" \
        || { prop_set "$PIF_DIR/pif.prop" MANUFACTURER "$want_mfg"; fix "MANUFACTURER -> $want_mfg"; changed=1; }
    [ "$cur_patch" = "$want_patch" ] && ok "security patch $cur_patch" \
        || { prop_set "$PIF_DIR/pif.prop" SECURITY_PATCH "$want_patch"; fix "SECURITY_PATCH -> $want_patch"; changed=1; }

    for kv in spoofBuild=true spoofProps=true spoofProvider=false spoofSignature=false spoofVendingBuild=true spoofVendingSdk=false; do
        k=${kv%%=*}; v=${kv#*=}
        cur=$(prop_get "$PIF_DIR/pif.prop" "$k")
        [ "$cur" = "$v" ] || { prop_set "$PIF_DIR/pif.prop" "$k" "$v"; fix "$k -> $v"; changed=1; }
    done
    [ -n "$(prop_get "$PIF_DIR/pif.prop" FINGERPRINT)" ] \
        && ok "fingerprint $(prop_get "$PIF_DIR/pif.prop" FINGERPRINT)" \
        || warn "FINGERPRINT missing, open the PIF WebUI and pick Pixel 6a / GitHub"
fi

# --------------------------------------------------------------------------
# 3. Tricky Store
# --------------------------------------------------------------------------
section "Tricky Store"

if [ ! -d "$TS_DIR" ]; then
    warn "Tricky Store not installed"
else
    if [ -s "$TS_DIR/keybox.xml" ]; then
        ok "keybox present ($(wc -c < "$TS_DIR/keybox.xml") bytes)"
    else
        warn "no keybox.xml, strong integrity needs a valid keybox"
    fi

    # Spoof the patch levels the attestation calls report: system is month
    # granularity, boot/vendor use the ROM's real date.
    want_system=$(echo "$PATCH" | tr -d '-')
    [ ${#want_system} -gt 6 ] && want_system=$(echo "$want_system" | cut -c1-6)
    cur=$(cat "$TS_DIR/security_patch.txt" 2>/dev/null | tr -d ' ')
    new="system=$want_system
boot=$PATCH
vendor=$PATCH"
    if [ "$cur" = "$(printf '%s' "$new" | tr -d ' ')" ]; then
        ok "security patch $want_system / $PATCH"
    else
        printf '%s\n' "$new" > "$TS_DIR/security_patch.txt"
        fix "security_patch.txt -> $want_system / $PATCH"
        changed=1
    fi

    for app in com.google.android.gms com.android.vending com.google.android.apps.walletnfcrel; do
        if grep -qx "$app" "$TS_DIR/target.txt" 2>/dev/null; then
            ok "attested $app"
        else
            echo "$app" >> "$TS_DIR/target.txt"
            fix "added $app to target.txt"
            changed=1
        fi
    done
fi

# --------------------------------------------------------------------------
# 4. Status
# --------------------------------------------------------------------------
section "State"

if [ -f /data/adb/tricky_store/tee_status ]; then
    ok "tee: $(cat /data/adb/tricky_store/tee_status 2>/dev/null)"
fi

for m in meta-overlayfs zygisksu playintegrityfix tricky_store Yurikey TA_utl susfs4ksu; do
    [ -d "/data/adb/modules/$m" ] && ok "module $m"
done

if [ "$changed" = 1 ]; then
    printf '\nchanges applied, reboot or clear GMS to pick them up:\n'
    printf '  am force-stop com.google.android.gms\n'
else
    printf '\nnothing drifted, config already in place\n'
fi
