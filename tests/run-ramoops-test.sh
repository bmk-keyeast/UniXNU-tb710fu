#!/usr/bin/env bash
# Host test of the ramoops console writer: extract tb710fu_ramoops.c from the XNU patch,
# build the harness with sanitizers, write zone images, read them back the way Linux does.
set -euo pipefail
cd "$(dirname "$0")"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
awk '/^\+\+\+ b\/osfmk\/kern\/tb710fu_ramoops.c$/{f=1; next} f && /^diff --git/{f=0} f && /^@@/{next} f{print substr($0, 2)}' \
  ../patches/xnu/tb710fu-ramoops-console.patch > "$T/tb710fu_ramoops.c"
cp test_ramoops.c "$T/"
cc -std=c11 -Wall -O1 -fsanitize=address,undefined -o "$T/t" "$T/test_ramoops.c"
ASAN_OPTIONS=detect_leaks=0 "$T/t" "$T"
python3 -I verify_ramoops.py "$T"
