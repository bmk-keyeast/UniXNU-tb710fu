#!/usr/bin/env bash
# Read the ramoops/pstore log from stock Android (root), e.g. after an XNU boot on slot b.
#   scripts/read-ramoops.sh             pull /sys/fs/pstore/* into logs/ramoops-<time>/
#   scripts/read-ramoops.sh --check     show the stock ramoops layout the XNU writer assumes
#   scripts/read-ramoops.sh --mark      write a marker to the kernel log and reboot; run the
#                                       plain command afterwards: the marker in
#                                       console-ramoops-0 proves the zone survives a reset
set -euo pipefail
cd "$(dirname "$0")/.."
adb get-state >/dev/null
# adb joins argv with spaces, so the whole command must reach su as one quoted string
sh() { adb exec-out "su -c '${1//\'/\'\\\'\'}'"; }

case "${1:-}" in
--check)
  for p in mem_address mem_size mem_type record_size console_size pmsg_size ftrace_size ecc; do
    printf '%-13s %s\n' "$p" "$(sh "cat /sys/module/ramoops/parameters/$p 2>/dev/null" || true)"
  done
  # 6.1 does not copy mem_type/ecc back into the module parameters; the DT node is the truth
  sh "grep -i ramoops /proc/iomem; ls -l /sys/fs/pstore; cd /proc/device-tree/reserved-memory/ramoops_region && for p in reg console-size ecc-size mem-type; do echo \$p \$(od -An -tx1 \$p); done; tail -c 200 /sys/fs/pstore/console-ramoops-0 | grep ECC"
  echo "expected by the XNU writer: console zone at mem_address + (mem_size - console - pmsg - ftrace) = 0xac340000, size 0x40000, ecc 16"
  ;;
--mark)
  sh "echo TB710FU-PSTORE-MARK-\$(date +%s) > /dev/kmsg"
  adb reboot
  echo "rebooting; then run scripts/read-ramoops.sh and grep TB710FU-PSTORE-MARK"
  ;;
*)
  out="logs/ramoops-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$out"
  for f in $(sh "ls /sys/fs/pstore"); do
    sh "cat /sys/fs/pstore/$f" > "$out/$f"
  done
  ls -l "$out"
  grep -h -A2000 "TB710FU XNU boot" "$out"/console-ramoops* 2>/dev/null | tail -60 || echo "no XNU boot banner in console-ramoops"
  ;;
esac
