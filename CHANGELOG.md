# Changelog

## v1.0

First release.

- Action button reapplies the SUSFS profile live (sus paths, app-only umount,
  mount hiding off, verifiedbootstate patched to green).
- Verifies the PIF profile is Pixel 6a / bluejay beta with the ROM's patch date,
  repairing only what drifted.
- Keeps Tricky Store's security patch in step with the ROM and makes sure GMS,
  Vending and Wallet are attested.
- Late-boot service restores the SUSFS config and module.prop when a boot leaves
  them zero-filled, and enforces the hiding without a button press.
