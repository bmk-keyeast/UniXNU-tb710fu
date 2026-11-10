#!/usr/bin/env bash
# Write slot b from rooted Android (locked bootloader: no fastboot). Slot a is never written and the
# active slot is not changed: switch slots yourself.
# Pushes DIR and scripts/android/flash-slot-b.sh (from tb710fu-arch-linux) to the tablet, which
# writes <part>_b.img for every file in DIR and copies the rest of slot a's AVB chain
# (vbmeta vbmeta_system dtbo vendor_boot init_boot recovery boot) to slot b.
# The previous slot b (all seven partitions) is pulled to firmware-dump/slot-b-backup-<time>/.
#   scripts/flash-slot-b.sh [DIR=images/slot-b]            dry run (checks only)
#   scripts/flash-slot-b.sh [DIR=images/slot-b] --write    write
# Restore: scripts/flash-slot-b.sh firmware-dump/slot-b-backup-<time> --write
set -euo pipefail
cd "$(dirname "$0")/.."
DIR=${1:-images/slot-b} WRITE=${2:-}
T=/data/local/tmp/unixnu-slot-b
root() { adb shell "su -c '$1'" | tr -d '\r'; }

[ -f "$DIR/boot_b.img" ] && [ -f "$DIR/SHA256SUMS" ] || { echo "$DIR needs boot_b.img and SHA256SUMS" >&2; exit 1; }
(cd "$DIR" && sha256sum -c --quiet SHA256SUMS)
adb get-state >/dev/null
root "rm -rf $T; mkdir -p $T/img"
adb push scripts/android/flash-slot-b.sh $T/ >/dev/null
for f in "$DIR"/*_b.img "$DIR/SHA256SUMS"; do adb push "$f" $T/img/ >/dev/null; done
root "sh $T/flash-slot-b.sh $T/img $WRITE"

if [ "$WRITE" = --write ]; then
  bak=firmware-dump/slot-b-backup-$(date +%Y%m%d-%H%M%S)
  mkdir -p "$bak"
  for p in vbmeta vbmeta_system dtbo vendor_boot init_boot recovery boot; do
    f=$T/img/backup-slot-b/${p}_b.img
    adb exec-out "su -c 'cat $f'" > "$bak/${p}_b.img"
    [ "$(root "sha256sum $f" | cut -d' ' -f1)" = "$(sha256sum "$bak/${p}_b.img" | cut -d' ' -f1)" ] ||
      { echo "backup pull of ${p}_b failed; it is still on the tablet in $T" >&2; exit 1; }
  done
  (cd "$bak" && sha256sum *_b.img > SHA256SUMS)
  echo "previous slot b saved to $bak"
fi
root "rm -rf $T"
