#!/usr/bin/env bash
# Copy the TB710FU firmware inputs off the tablet (read-only on the device).
# Needs: Android booted, adb authorized, root (KernelSU/Magisk) for `su`.
# usage: scripts/dump-firmware.sh [OUT_DIR=firmware-dump]
set -euo pipefail
OUT=${1:-firmware-dump}
SLOT_PARTS="uefi xbl xbl_config abl imagefv uefisecapp vendor_boot boot dtbo"
mkdir -p "$OUT"

adb get-state >/dev/null
slot=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')
echo "active slot: ${slot:-none}"

for p in $SLOT_PARTS; do
  name="$p$slot"
  if ! adb shell su -c "test -e /dev/block/by-name/$name" 2>/dev/null; then
    name=$p  # non-A/B partition
    adb shell su -c "test -e /dev/block/by-name/$name" 2>/dev/null || { echo "skip $p (absent)"; continue; }
  fi
  # Stream straight to the host: no temp file on the device (KernelSU blocks chmod in /data/local/tmp).
  adb exec-out su -c "cat /dev/block/by-name/$name" > "$OUT/$name.img"
  size=$(adb shell su -c "blockdev --getsize64 /dev/block/by-name/$name" | tr -d '\r')
  [ "$(wc -c < "$OUT/$name.img")" -eq "$size" ] || { echo "short read: $name"; exit 1; }
  echo "dumped $name ($size bytes)"
done

{
  echo "# device facts ($(date -u +%FT%TZ))"
  adb shell getprop ro.product.model
  adb shell getprop ro.boot.hardware.sku
  adb shell su -c "cat /sys/devices/soc0/soc_id /sys/devices/soc0/revision /sys/devices/soc0/serial_number"
  adb shell grep MemTotal /proc/meminfo
  adb shell su -c "ls -l /dev/block/by-name/"
  adb shell su -c "cat /proc/partitions"
} | tr -d '\r' > "$OUT/device-facts.txt"

(cd "$OUT" && sha256sum *.img > SHA256SUMS)
echo "done: $OUT (do not commit it; the serial number in device-facts.txt is the ADT seed)"
