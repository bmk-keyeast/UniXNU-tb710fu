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
  adb shell su -c "dd if=/dev/block/by-name/$name of=/data/local/tmp/$name.img bs=4M 2>/dev/null && chmod 644 /data/local/tmp/$name.img"
  adb pull "/data/local/tmp/$name.img" "$OUT/" >/dev/null
  adb shell su -c "rm /data/local/tmp/$name.img"
  echo "dumped $name"
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
