# kyler084 toolbox

A KernelSU-Next module for the POCO X3 Pro (vayu) that reapplies my hiding and
integrity setup from a single button press, and keeps it applied across reboots.

It does not replace any of the modules it works with — SUSFS, Play Integrity Fix
and Tricky Store still own their own jobs. This just stops their settings from
quietly drifting, and reports what state the phone is actually in.

## What the Action button does

Pressing **Action** in the KernelSU-Next manager runs `action.sh`, which:

1. **SUSFS** — rewrites `susfs4ksu/config.sh` with my profile and applies it live:
   hides `/data/adb/ksu`, `/data/adb/ksud` and `/data/adb/susfs4ksu` from apps,
   adds the app-only umount for `/debug_ramdisk`, turns the global mount hiding off
   in favour of per-app umount, and patches `verifiedbootstate` to green in the
   bootconfig. `sus_su` and uname spoofing stay off on purpose: this ROM reports
   the kernel it is running, and a fake uname would disagree with what PIF sets.
2. **Play Integrity Fix** — checks `pif.prop` is on the Pixel 6a / bluejay beta
   print with the right spoof flags and the ROM's real security patch, and repairs
   only the fields that drifted.
3. **Tricky Store** — keeps `security_patch.txt` in step with
   `ro.build.version.security_patch` and makes sure GMS, Vending and Wallet are in
   `target.txt`.
4. **Status** — prints kernel, SUSFS, keybox, tee state and the module list, then
   says whether anything changed.

`service.sh` runs the same profile enforcement once the boot has settled, so the
hiding is in place without pressing anything.

## Install

Download the zip from [Releases](../../releases) and install it in the
KernelSU-Next manager, or from a shell:

```sh
ksud module install kyler084-toolbox-v1.0.zip
```

The module carries `updateJson=`, so the manager offers new versions itself.

## Requirements

- A kernel with SUSFS 2.x (this was built against v2.3.0).
- KernelSU-Next with `ksu_susfs` in `/data/adb/ksu/bin`.
- Optional, but the whole point: `playintegrityfix` and `tricky_store`. Without
  them the matching sections are skipped and the module still applies SUSFS.

## Notes

On this tree the SUSFS module's own boot scripts can leave `config.sh` and its
`module.prop` as zero-filled files — writes from those boot stages come back as
NULs. `service.sh` checks for that and rewrites both, which is why the profile
survives a reboot.

Nothing here touches Play Integrity verdicts directly. If Wallet or a banking app
still complains, look at the keybox and at PIF, not at this module.

## Credits

SUSFS is [simonpunk's](https://gitlab.com/simonpunk/susfs4ksu) work, the module
side is [sidex15's ksu_module_susfs](https://github.com/sidex15/ksu_module_susfs),
Play Integrity Fix is chiteroman/KOWX712, and Tricky Store is 5ec1cff's. This
module only wires their settings together the way I run them.
