#!/usr/bin/env bash
# Put the stock slot-b images back (backups made by flash-slot-b.sh) and keep slot a active.
# usage: scripts/restore-slot-b.sh [BACKUP_DIR=firmware-dump/slot-b-backup]
set -euo pipefail
cd "$(dirname "$0")/.."
BAK=${1:-firmware-dump/slot-b-backup}
adb get-state >/dev/null
for p in boot_b vendor_boot_b vbmeta_b; do
  [ -s "$BAK/$p.img" ] || { echo "no backup $BAK/$p.img" >&2; exit 1; }
  adb exec-in su -c "dd of=/dev/block/by-name/$p bs=4M 2>/dev/null; sync" < "$BAK/$p.img"
  dev=$(adb shell su -c "sha256sum /dev/block/by-name/$p" | cut -d' ' -f1)
  [ "$dev" = "$(sha256sum "$BAK/$p.img" | cut -d' ' -f1)" ] || { echo "$p: read-back mismatch" >&2; exit 1; }
  echo "restored $p"
done
adb shell su -c "bootctl set-active-boot-slot 0" || true
