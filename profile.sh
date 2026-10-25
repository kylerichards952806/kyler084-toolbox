# susfs4ksu config written by kyler084 toolbox. One key per line.
susfs_log=1

# KSU root is enough; sus_su adds another root path apps can probe for.
sus_su=0
sus_su_active=0

# Lineage props, vendor sepolicy and the vendor compat matrix are what apps
# read to spot a custom ROM.
hide_cusrom=1
hide_vendor_sepolicy=1
hide_compat_matrix=1
hide_gapps=0
hide_revanced=0
force_hide_lsposed=0

spoof_cmdline=1
hide_loops=1

# uname stays real: the ROM reports this kernel and a fake release would
# disagree with the props PIF already sets.
spoof_uname=0

# App-only umount instead of hiding the whole mount table from every
# non-su process: hiding mounts while files are being written is what left
# the SUSFS config and module.prop full of zero bytes.
hide_sus_mnts_for_all_or_non_su_procs=0
umount_for_zygote_iso_service=0
auto_try_umount=1
skip_legit_mounts=0

avc_log_spoofing=0
emulate_vold_app_data=0
disable_webui_bin_update=1

kernel_version='default'
kernel_build='default'
vbmeta_size=9600
