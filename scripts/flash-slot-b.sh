#!/usr/bin/env bash
# Write the signed UniXNU images to slot b from rooted Android (locked bootloader: no fastboot flash).
# Slot a (Android) is not touched. ABL falls back to slot a after slot b fails to boot a few times;
# scripts/restore-slot-b.sh puts the stock slot-b images back.
#   flash   : back up boot_b/vendor_boot_b/vbmeta_b (once), write the signed images, read them back
#   activate: also mark slot b active and reboot
# usage: scripts/flash-slot-b.sh [--activate] [IMAGES_DIR=images] [BACKUP_DIR=firmware-dump/slot-b-backup]
set -euo pipefail
cd "$(dirname "$0")/.."
ACTIVATE=0; [ "${1:-}" = --activate ] && { ACTIVATE=1; shift; }
IMG=${1:-images} BAK=${2:-firmware-dump/slot-b-backup}
declare -A SRC=([boot_b]=boot-signed.img [vendor_boot_b]=vendor_boot.img [vbmeta_b]=vbmeta-signed.img)

adb get-state >/dev/null
[ "$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')" = _a ] || { echo "Android must be running from slot a" >&2; exit 1; }
(cd "$IMG" && sha256sum -c --quiet SIGNED.SHA256SUMS)

mkdir -p "$BAK"
for p in "${!SRC[@]}"; do
  size=$(adb shell su -c "blockdev --getsize64 /dev/block/by-name/$p" | tr -d '\r')
  [ "$size" = "$(stat -c %s "$IMG/${SRC[$p]}")" ] || { echo "$p: image size != partition $size" >&2; exit 1; }
  if [ ! -s "$BAK/$p.img" ]; then
    adb exec-out su -c "cat /dev/block/by-name/$p" > "$BAK/$p.img"
    [ "$(stat -c %s "$BAK/$p.img")" = "$size" ] || { echo "backup of $p is short" >&2; exit 1; }
    echo "backed up $p"
  fi
done

for p in "${!SRC[@]}"; do
  adb exec-in su -c "dd of=/dev/block/by-name/$p bs=4M 2>/dev/null; sync" < "$IMG/${SRC[$p]}"
  want=$(sha256sum "$IMG/${SRC[$p]}" | cut -d' ' -f1)
  # exec-in can return before the device-side dd finishes, so re-read a few times
  for try in 1 2 3 4 5; do
    sleep 3
    dev=$(adb shell "su -c 'sync; sha256sum /dev/block/by-name/$p'" | cut -d' ' -f1)
    [ "$dev" = "$want" ] && break
  done
  [ "$dev" = "$want" ] || { echo "$p: read-back mismatch" >&2; exit 1; }
  echo "wrote $p (${SRC[$p]}), read-back ok"
done

if [ $ACTIVATE = 1 ]; then
  adb shell su -c "bootctl set-active-boot-slot 1" || { echo "bootctl failed; set slot b with qbootctl or the KernelSU module" >&2; exit 1; }
  adb reboot
  echo "rebooting into slot b"
fi
