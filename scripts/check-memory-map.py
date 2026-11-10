#!/usr/bin/env python3
"""Flag UEFI memory-map regions that hand out RAM the board DTS reserves.

A region the UEFI map marks Conv (free for UEFI/OS allocations) must not overlap a
no-map reserved-memory node of dts/tb710fu.dts: firmware or the modem owns it.

usage: check-memory-map.py [MemoryMapLib.c] [board.dts]   (exit 1 on overlap)
       check-memory-map.py --selftest
"""
import re
import sys

UEFI_RE = re.compile(r'\{"(\w+)",\s*(0x[0-9A-Fa-f]+),\s*(0x[0-9A-Fa-f]+),\s*\w+,\s*\w+,\s*\w+,\s*(\w+),')
DTS_RE = re.compile(r"^\s*([\w,.+-]+)@[0-9a-f]+ \{ reg = <0 (0x[0-9a-f]+) 0 (0x[0-9a-f]+)>;( no-map;)? \};", re.M)


def uefi_regions(text):
    return [(n, int(a, 16), int(s, 16), t) for n, a, s, t in UEFI_RE.findall(text)]


def dts_reserved(text):
    return [(n, int(a, 16), int(s, 16)) for n, a, s, nomap in DTS_RE.findall(text) if nomap]


def conflicts(uefi, reserved):
    out = []
    for un, ua, us, typ in uefi:
        if typ != "Conv":
            continue
        for rn, ra, rs in reserved:
            if ua < ra + rs and ra < ua + us:
                out.append(f"{un} [{ua:#x}-{ua + us:#x}) Conv overlaps {rn} [{ra:#x}-{ra + rs:#x}) no-map")
    return out


def selftest():
    uefi = uefi_regions('{"DXE_Heap", 0xB8000000, 0x1BA00000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv, WRITE_BACK_XN},\n'
                        '{"Kernel", 0xA8000000, 0x10000000, AddMem, SYS_MEM, SYS_MEM_CAP, Reserv, WRITE_BACK_XN},')
    dts = dts_reserved("        rmtfs@d3000000 { reg = <0 0xd3000000 0 0x400000>; no-map; };\n"
                       "        ramoops@ac300000 { reg = <0 0xac300000 0 0x100000>; };\n"
                       "        tz-merged@d8000000 { reg = <0 0xd8000000 0 0x800000>; no-map; };\n")
    assert dts == [("rmtfs", 0xD3000000, 0x400000), ("tz-merged", 0xD8000000, 0x800000)], dts
    got = conflicts(uefi, dts)
    assert len(got) == 1 and got[0].startswith("DXE_Heap") and "rmtfs" in got[0], got
    print("selftest ok")


def main(argv):
    if argv[1:] == ["--selftest"]:
        return selftest()
    mm = argv[1] if len(argv) > 1 else "uefi/Platforms/Lenovo/tb710fuPkg/Library/MemoryMapLib/MemoryMapLib.c"
    dts = argv[2] if len(argv) > 2 else "dts/tb710fu.dts"
    found = conflicts(uefi_regions(open(mm).read()), dts_reserved(open(dts).read()))
    print("\n".join(found) or "no overlaps")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
