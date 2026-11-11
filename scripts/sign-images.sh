#!/usr/bin/env bash
# Sign the UniXNU boot images for slot b of a locked TB710FU (LTBox testkey path).
# Slot b = slot a's AVB chain + these three files; scripts/flash-slot-b.sh copies the rest of the
# chain (vbmeta_system, dtbo, init_boot, recovery) from slot a. The stock slot-b chain is mixed
# firmware whose dtbo/vendor_boot hashes do not match vbmeta_b, so it is not used as a template.
#   boot        : chained in vbmeta_a (rollback location 3) -> testkey hash footer carrying boot_a's
#                 os_version/security_patch properties (ABL refuses a boot without them)
#   vendor_boot : hash descriptor inside vbmeta_a -> recompute it, re-sign vbmeta with the testkey
# usage: scripts/sign-images.sh [DUMP_DIR=firmware-dump] [IMAGES_DIR=images]
#   DUMP_DIR holds the stock slot-a dumps: vbmeta_a.img, boot_a.img (scripts/dump-firmware.sh)
#   IMAGES_DIR holds boot.img and vendor_boot.img built from vendor_boot_a.img
# output: IMAGES_DIR/slot-b/{boot_b,vendor_boot_b,vbmeta_b}.img + SHA256SUMS
set -euo pipefail
cd "$(dirname "$0")/.."
DUMP=${1:-firmware-dump} IMG=${2:-images}
AVB=scripts/avb KEY=scripts/avb/testkey_rsa4096.pem OUT=$IMG/slot-b
TESTKEY_SHA1=2597c218aae470a130f61162feaae70afd97f011   # AOSP testkey_rsa4096
py="python3 -I"
for f in "$DUMP/vbmeta_a.img" "$DUMP/boot_a.img" "$IMG/boot.img" "$IMG/vendor_boot.img"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

read -r vb_key boot_chain ri < <($py -c '
import sys; sys.path.insert(0, sys.argv[1]); import avbinfo
info = lambda p: avbinfo.parse(avbinfo.vbmeta_blob(open(p, "rb").read())[0])
v, b = info(sys.argv[2]), info(sys.argv[3])
c = [d["pubkey_sha1"] for d in v["descriptors"] if d["type"] == "chain" and d["partition"] == "boot"]
print(v["pubkey_sha1"], c[0] if c else "none", b["rollback_index"])' "$AVB" "$DUMP/vbmeta_a.img" "$DUMP/boot_a.img")
[ "$vb_key" = "$TESTKEY_SHA1" ] || { echo "vbmeta_a signed by $vb_key, not the testkey" >&2; exit 1; }
[ "$boot_chain" != none ] || { echo "vbmeta_a has no boot chain descriptor" >&2; exit 1; }

mkdir -p "$OUT"
cp "$IMG/boot.img" "$OUT/boot_b.img"
$py $AVB/avbsign.py footer "$OUT/boot_b.img" "$(stat -c %s "$DUMP/boot_a.img")" "$ri" "$KEY" boot --props-from "$DUMP/boot_a.img"
cp "$IMG/vendor_boot.img" "$OUT/vendor_boot_b.img"

vb_in="$DUMP/vbmeta_a.img"
if [ "$boot_chain" != "$TESTKEY_SHA1" ]; then
  $py $AVB/avbsign.py rekey "$vb_in" "$OUT/vbmeta-rekeyed.img" "$KEY" boot
  vb_in="$OUT/vbmeta-rekeyed.img"
fi
$py $AVB/avbsign.py rehash "$vb_in" "$OUT/vbmeta_b.img" "$KEY" "vendor_boot=$OUT/vendor_boot_b.img"
rm -f "$OUT/vbmeta-rekeyed.img"

for f in boot_b vbmeta_b; do
  [ "$($py $AVB/avbsign.py verify "$OUT/$f.img" "$KEY")" = OK ] || { echo "$f.img verify failed" >&2; exit 1; }
done
[ "$(stat -c %s "$OUT/vbmeta_b.img")" = "$(stat -c %s "$DUMP/vbmeta_a.img")" ]
$py $AVB/avbinfo.py "$OUT/boot_b.img" | grep -q "key=com.android.build.boot.os_version value=[1-9]" ||
  { echo "boot_b.img has no boot os_version property: ABL would refuse it" >&2; exit 1; }
(cd "$OUT" && sha256sum boot_b.img vendor_boot_b.img vbmeta_b.img > SHA256SUMS)
echo "signed: $OUT (boot rollback index $ri, vendor_boot rehashed in vbmeta_a)"
