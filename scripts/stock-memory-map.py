#!/usr/bin/env python3
"""Print the stock UEFI memory map embedded in xbl_config (a DTB with memory@ nodes
carrying MemLabel/BuildHob/ResourceType/ResourceAttribute/MemoryType/CacheAttributes),
and compare it with the Mu-Silicium MemoryMapLib.c table.

usage: stock-memory-map.py XBL_CONFIG_IMG [MemoryMapLib.c]
       stock-memory-map.py --selftest
"""
import re
import struct
import subprocess
import sys

# Silicium names for the stock numeric fields (MemoryType = EFI_MEMORY_TYPE).
MEMTYPE = {0: "Reserv", 3: "BsCode", 4: "BsData", 5: "RtCode", 6: "RtData", 7: "Conv", 11: "MmIO"}

NODE = re.compile(r'memory@[0-9A-Fa-f]+ \{\s*device_type = "memory";\s*reg = <0x00 (0x[0-9a-f]+) 0x00 (0x[0-9a-f]+)>;\s*'
                  r'MemLabel = "([^"]+)";(.*?)\};', re.S)
LIB = re.compile(r'\{"(\w+)",\s*(0x[0-9A-Fa-f]+),\s*(0x[0-9A-Fa-f]+),\s*(\w+),\s*(\w+),\s*(\w+),\s*(\w+),\s*(\w+)\}')


def find_memmap_dtb(img):
    i = 0
    while (i := img.find(b"\xd0\x0d\xfe\xed", i)) >= 0:
        size = struct.unpack(">I", img[i + 4:i + 8])[0]
        blob = img[i:i + size]
        if 0x100 < size <= len(img) - i and b"UEFI_FD" in blob:
            return blob
        i += 4
    sys.exit("no memory-map DTB in the image")


def stock_regions(dts):
    out = []
    for addr, size, label, props in NODE.findall(dts):
        mt = re.search(r"MemoryType = \[([0-9a-f]+)\]", props)
        out.append((label, int(addr, 16), int(size, 16), MEMTYPE.get(int(mt.group(1), 16), mt.group(1)) if mt else "?"))
    return out


def lib_regions(text):
    return {m[0]: (int(m[1], 16), int(m[2], 16), m[6]) for m in LIB.findall(text)}


def compare(stock, lib):
    lines = []
    for label, addr, size, mtype in stock:
        if label not in lib:
            lines.append(f"stock-only  {label:22} {addr:#012x} {size:#012x} {mtype}")
            continue
        la, ls, lt = lib[label]
        if (la, ls, lt) != (addr, size, mtype):
            lines.append(f"differs     {label:22} stock {addr:#x}+{size:#x} {mtype}  lib {la:#x}+{ls:#x} {lt}")
    stock_labels = {s[0] for s in stock}
    lines += [f"lib-only    {k}" for k in lib if k not in stock_labels]
    return lines


def selftest():
    dts = '''memory@B8000000 {
				device_type = "memory";
				reg = <0x00 0xb8000000 0x00 0x1ba00000>;
				MemLabel = "DXE_Heap";
				ResourceAttribute = <0x703c07>;
				MemoryType = [07];
			};'''
    st = stock_regions(dts)
    assert st == [("DXE_Heap", 0xB8000000, 0x1BA00000, "Conv")], st
    lib = lib_regions('{"DXE_Heap", 0xB8000000, 0x1B000000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv, WRITE_BACK_XN},\n'
                      '{"Extra", 0x1000, 0x1000, AddMem, SYS_MEM, SYS_MEM_CAP, Reserv, WRITE_BACK_XN},')
    got = compare(st, lib)
    assert got[0].startswith("differs     DXE_Heap") and got[1] == "lib-only    Extra", got
    print("selftest ok")


def main(argv):
    if argv[1:] == ["--selftest"]:
        return selftest()
    blob = find_memmap_dtb(open(argv[1], "rb").read())
    dts = subprocess.run(["dtc", "-q", "-I", "dtb", "-O", "dts"], input=blob, capture_output=True, check=True).stdout.decode()
    stock = stock_regions(dts)
    for label, addr, size, mtype in sorted(stock, key=lambda r: r[1]):
        print(f"{label:22} {addr:#012x} {size:#012x} {mtype}")
    if len(argv) > 2:
        print("\n".join(["--- vs " + argv[2]] + compare(stock, lib_regions(open(argv[2]).read()))))


if __name__ == "__main__":
    main(sys.argv)
