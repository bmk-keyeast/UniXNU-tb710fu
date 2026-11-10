#!/usr/bin/env bash
# Sign the UniXNU boot images for slot b of a locked TB710FU (LTBox testkey path).
#   boot        : chained in vbmeta (rollback location 3) -> testkey hash footer
#   vendor_boot : hash descriptor inside vbmeta -> recompute it, re-sign vbmeta with the testkey
# usage: scripts/sign-images.sh [DUMP_DIR=firmware-dump] [IMAGES_DIR=images]
#   DUMP_DIR holds the stock slot-b dumps: vbmeta_b.img, boot_b.img (scripts/dump-firmware.sh b)
#   IMAGES_DIR holds boot.img and vendor_boot.img built from vendor_boot_b.img
set -euo pipefail
cd "$(dirname "$0")/.."
DUMP=${1:-firmware-dump} IMG=${2:-images}
AVB=scripts/avb KEY=scripts/avb/testkey_rsa4096.pem
TESTKEY_SHA1=2597c218aae470a130f61162feaae70afd97f011   # AOSP testkey_rsa4096
py="python3 -I"
for f in "$DUMP/vbmeta_b.img" "$DUMP/boot_b.img" "$IMG/boot.img" "$IMG/vendor_boot.img"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

read -r vb_key boot_chain ri < <($py -c '
import sys; sys.path.insert(0, sys.argv[1]); import avbinfo
info = lambda p: avbinfo.parse(avbinfo.vbmeta_blob(open(p, "rb").read())[0])
v, b = info(sys.argv[2]), info(sys.argv[3])
c = [d["pubkey_sha1"] for d in v["descriptors"] if d["type"] == "chain" and d["partition"] == "boot"]
print(v["pubkey_sha1"], c[0] if c else "none", b["rollback_index"])' "$AVB" "$DUMP/vbmeta_b.img" "$DUMP/boot_b.img")
[ "$vb_key" = "$TESTKEY_SHA1" ] || { echo "vbmeta_b signed by $vb_key, not the testkey" >&2; exit 1; }
[ "$boot_chain" != none ] || { echo "vbmeta_b has no boot chain descriptor" >&2; exit 1; }

cp "$IMG/boot.img" "$IMG/boot-signed.img"
$py $AVB/avbsign.py footer "$IMG/boot-signed.img" "$(stat -c %s "$DUMP/boot_b.img")" "$ri" "$KEY"

vb_in="$DUMP/vbmeta_b.img"
if [ "$boot_chain" != "$TESTKEY_SHA1" ]; then
  $py $AVB/avbsign.py rekey "$vb_in" "$IMG/vbmeta-rekeyed.img" "$KEY" boot
  vb_in="$IMG/vbmeta-rekeyed.img"
fi
$py $AVB/avbsign.py rehash "$vb_in" "$IMG/vbmeta-signed.img" "$KEY" "vendor_boot=$IMG/vendor_boot.img"
rm -f "$IMG/vbmeta-rekeyed.img"

for f in boot-signed vbmeta-signed; do
  [ "$($py $AVB/avbsign.py verify "$IMG/$f.img" "$KEY")" = OK ] || { echo "$f.img verify failed" >&2; exit 1; }
done
[ "$(stat -c %s "$IMG/vbmeta-signed.img")" = "$(stat -c %s "$DUMP/vbmeta_b.img")" ]
(cd "$IMG" && sha256sum boot-signed.img vendor_boot.img vbmeta-signed.img > SIGNED.SHA256SUMS)
echo "signed: $IMG/boot-signed.img (rollback index $ri), $IMG/vbmeta-signed.img (vendor_boot rehashed); vendor_boot.img unchanged"
