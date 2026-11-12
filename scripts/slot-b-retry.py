#!/usr/bin/env python3
"""Set the ABL retry count of slot b (boot_b's GPT attributes) so a failed slot-b boot falls back
to slot a after N tries instead of the 7 the boot HAL sets. Activate slot b yourself first; this
never activates or deactivates a slot.

  scripts/slot-b-retry.py                  show boot_b/boot_a slot attributes (read-only)
  scripts/slot-b-retry.py --write [N]      set boot_b's retry count to N (1..7, default 1)
  scripts/slot-b-retry.py --restore DIR    write back the GPT copies saved by --write
  scripts/slot-b-retry.py --selftest

Before writing, both GPT copies (header + entry array) of boot_b's LUN are checked (signature,
CRCs, entry name) and saved to firmware-dump/gpt-<disk>-<time>/. The primary copy is written and
read back before the backup copy is touched. ADB=path/to/adb overrides the adb binary.
"""
import json
import os
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from pathlib import Path

ADB = os.environ.get('ADB', 'adb')
TMP = '/data/local/tmp/unixnu-gpt.bin'
# Qualcomm slot bits in the upper attribute bytes (attribute byte 6 = bits 48..55):
# priority 48-49, active 50, retry count 51-53, successful 54, unbootable 55.
ATTR_BYTE = 48 + 6


def sh(cmd):
    return subprocess.run([ADB, 'exec-out', f"su -c '{cmd}'"], capture_output=True, check=True).stdout


def text(cmd):
    return sh(cmd).decode().strip()


def read(dev, ss, lba, count):
    data = sh(f'dd if={dev} bs={ss} skip={lba} count={count} 2>/dev/null')
    if len(data) != ss * count:
        raise SystemExit(f'short read at LBA {lba}: {len(data)} bytes')
    return data


def write(dev, ss, lba, data):
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(data)
    try:
        subprocess.run([ADB, 'push', f.name, TMP], capture_output=True, check=True)
    finally:
        os.unlink(f.name)
    sh(f'dd if={TMP} of={dev} bs={ss} seek={lba} conv=notrunc,fsync 2>/dev/null; rm -f {TMP}; sync')
    if read(dev, ss, lba, len(data) // ss) != data:
        raise SystemExit(f'read-back mismatch at LBA {lba} of {dev}')


def parse(header):
    """Header fields this tool needs, after checking signature and header CRC."""
    if header[:8] != b'EFI PART':
        raise SystemExit('no GPT signature')
    size, = struct.unpack_from('<I', header, 12)
    blank = bytearray(header[:size])
    blank[16:20] = bytes(4)
    if zlib.crc32(blank) != struct.unpack_from('<I', header, 16)[0]:
        raise SystemExit('GPT header CRC mismatch')
    current, alternate = struct.unpack_from('<QQ', header, 24)
    entries_lba, = struct.unpack_from('<Q', header, 72)
    count, entry_size, entries_crc = struct.unpack_from('<III', header, 80)
    return dict(size=size, current=current, alternate=alternate, entries_lba=entries_lba,
                count=count, entry_size=entry_size, entries_crc=entries_crc)


def entries_bytes(h):
    return h['count'] * h['entry_size']


def name(entries, h, index):
    raw = entries[index * h['entry_size'] + 56:index * h['entry_size'] + 128]
    return raw.decode('utf-16-le').split('\0')[0]


def slot_bits(entries, h, index):
    b = entries[index * h['entry_size'] + ATTR_BYTE]
    return dict(priority=b & 3, active=b >> 2 & 1, retry=b >> 3 & 7, successful=b >> 6 & 1,
                unbootable=b >> 7 & 1)


def patched(header, entries, h, index, retry):
    """Copies of header and entries with the retry count of entry INDEX set, CRCs recomputed."""
    entries = bytearray(entries)
    at = index * h['entry_size'] + ATTR_BYTE
    entries[at] = (entries[at] & ~0x38) | (retry << 3)
    header = bytearray(header)
    struct.pack_into('<I', header, 88, zlib.crc32(entries[:entries_bytes(h)]))
    struct.pack_into('<I', header, 16, 0)
    struct.pack_into('<I', header, 16, zlib.crc32(header[:h['size']]))
    return bytes(header), bytes(entries)


def load(dev, ss, lba):
    header = read(dev, ss, lba, 1)
    h = parse(header)
    if h['current'] != lba:
        raise SystemExit(f'GPT header at LBA {lba} names itself LBA {h["current"]}')
    blocks = -(-entries_bytes(h) // ss)
    entries = read(dev, ss, h['entries_lba'], blocks)
    if zlib.crc32(entries[:entries_bytes(h)]) != h['entries_crc']:
        raise SystemExit(f'GPT entry array CRC mismatch (header at LBA {lba})')
    return header, entries, h


def locate():
    path = text('readlink -f /dev/block/by-name/boot_b')
    disk = path.rstrip('0123456789')
    index = int(path[len(disk):]) - 1
    ss = int(text(f'cat /sys/block/{Path(disk).name}/queue/logical_block_size'))
    return disk, index, ss


def show(disk, entries, h):
    for i in range(h['count']):
        n = name(entries, h, i)
        if n in ('boot_a', 'boot_b'):
            print(f'{disk} #{i + 1} {n}: {slot_bits(entries, h, i)}')


def main(argv):
    if argv[:1] == ['--selftest']:
        return selftest()
    disk, index, ss = locate()
    if argv[:1] == ['--restore']:
        saved = Path(argv[1])
        meta = json.loads((saved / 'meta.json').read_text())
        if meta['disk'] != disk:
            raise SystemExit(f'saved copies are for {meta["disk"]}, boot_b is on {disk}')
        for part in ('primary', 'backup'):
            write(disk, ss, meta[part]['header_lba'], (saved / f'{part}-header.bin').read_bytes())
            write(disk, ss, meta[part]['entries_lba'], (saved / f'{part}-entries.bin').read_bytes())
        print(f'restored both GPT copies of {disk} from {saved}')
        return 0
    primary = load(disk, ss, 1)
    backup = load(disk, ss, primary[2]['alternate'])
    for header, entries, h in (primary, backup):
        if name(entries, h, index) != 'boot_b':
            raise SystemExit(f'entry {index + 1} of {disk} is {name(entries, h, index)!r}, not boot_b')
    show(disk, primary[1], primary[2])
    if argv[:1] != ['--write']:
        return 0
    retry = int(argv[1]) if len(argv) > 1 else 1
    if not 1 <= retry <= 7:
        raise SystemExit('retry count must be 1..7')
    if not slot_bits(primary[1], primary[2], index)['active']:
        raise SystemExit('boot_b is not the active slot: activate slot b first')
    saved = Path('firmware-dump') / f'gpt-{Path(disk).name}-{time.strftime("%Y%m%d-%H%M%S")}'
    saved.mkdir(parents=True)
    meta = {'disk': disk, 'sector_size': ss}
    for part, (header, entries, h) in (('primary', primary), ('backup', backup)):
        (saved / f'{part}-header.bin').write_bytes(header)
        (saved / f'{part}-entries.bin').write_bytes(entries)
        meta[part] = {'header_lba': h['current'], 'entries_lba': h['entries_lba']}
    (saved / 'meta.json').write_text(json.dumps(meta, indent=2))
    print(f'saved both GPT copies to {saved}')
    for header, entries, h in (primary, backup):
        new_header, new_entries = patched(header, entries, h, index, retry)
        write(disk, ss, h['entries_lba'], new_entries)
        write(disk, ss, h['current'], new_header)
    show(disk, load(disk, ss, 1)[1], primary[2])
    print(f'boot_b retry count set to {retry} in both GPT copies; restore: {sys.argv[0]} --restore {saved}')
    return 0


def selftest():
    ss, count, size = 4096, 4, 128
    entries = bytearray(count * size)
    for i, n in enumerate(('abl_b', 'boot_a', 'boot_b', 'dtbo_b')):
        entries[i * size + 56:i * size + 56 + 2 * len(n)] = n.encode('utf-16-le')
    entries[2 * size + ATTR_BYTE] = 0b00111111   # active, priority 3, retry 7
    entries = bytes(entries) + bytes(ss - len(entries))
    header = bytearray(ss)
    header[:8] = b'EFI PART'
    struct.pack_into('<IIIIQQ', header, 8, 0x10000, 92, 0, 0, 1, 99)
    struct.pack_into('<QIII', header, 72, 2, count, size, zlib.crc32(entries[:count * size]))
    struct.pack_into('<I', header, 16, zlib.crc32(header[:92]))
    h = parse(bytes(header))
    assert name(entries, h, 2) == 'boot_b'
    assert slot_bits(entries, h, 2) == dict(priority=3, active=1, retry=7, successful=0, unbootable=0)
    new_header, new_entries = patched(bytes(header), entries, h, 2, 1)
    h2 = parse(new_header)
    assert zlib.crc32(new_entries[:count * size]) == h2['entries_crc']
    assert slot_bits(new_entries, h2, 2) == dict(priority=3, active=1, retry=1, successful=0, unbootable=0)
    assert new_entries[:2 * size] == entries[:2 * size] and new_entries[3 * size:] == entries[3 * size:]
    print('selftest ok')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
