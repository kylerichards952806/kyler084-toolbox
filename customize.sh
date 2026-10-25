#!/system/bin/sh
# Runs from the installer. Nothing to patch at install time; just make the
# scripts executable and keep a copy of the profile the button applies.
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755

mkdir -p /data/adb/kyler084-toolbox
cp "$MODPATH/profile.sh" /data/adb/kyler084-toolbox/config.sh.orig 2>/dev/null

ui_print "- kyler084 toolbox installed"
ui_print "- press Action in KernelSU-Next to reapply hiding and integrity"
