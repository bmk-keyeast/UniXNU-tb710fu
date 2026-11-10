"""Read a ramoops console zone the way Linux does and check every RS codeword.

The ECC check is independent of the writer: a block plus its parity is a valid codeword
of RS(255) over GF(2^8)/0x11d with roots alpha^0..alpha^(nroots-1) iff all syndromes are 0,
which is what Linux decode_rs8 needs to accept the block without corrections.
"""
import struct
import sys

EXP, LOG = [0] * 512, [0] * 256
x = 1
for i in range(255):
    EXP[i] = x
    LOG[x] = i
    x <<= 1
    if x & 0x100:
        x ^= 0x11D
for i in range(255, 512):
    EXP[i] = EXP[i - 255]


def gmul(a, b):
    return 0 if a == 0 or b == 0 else EXP[LOG[a] + LOG[b]]


def syndromes_zero(codeword, nroots):
    for i in range(nroots):
        root, s = EXP[i], 0
        for c in codeword:              # Horner, highest degree first
            s = gmul(s, root) ^ c
        if s:
            return False
    return True


def read_zone(z, ecc, block=128):
    buf = len(z) - 12
    data_size, ecc_blocks = buf, 0
    if ecc:
        ecc_blocks = -(-(buf - ecc) // (block + ecc))
        data_size = buf - (ecc_blocks + 1) * ecc
    sig, start, size = struct.unpack("<III", z[:12])
    assert sig == 0x43474244, hex(sig)
    assert size <= data_size and start <= size, (start, size, data_size)
    data = z[12:12 + data_size]
    if ecc:
        par = z[12 + data_size:]
        assert syndromes_zero(z[:12] + par[ecc_blocks * ecc:(ecc_blocks + 1) * ecc], ecc), "header ECC"
        for b in range(-(-size // block)):          # Linux checks the blocks under size
            blk = data[b * block:(b + 1) * block]
            assert syndromes_zero(blk + par[b * ecc:(b + 1) * ecc], ecc), f"block {b} ECC"
    return (data[start:size] + data[:start]).decode("latin1")


d = sys.argv[1]
t = read_zone(open(f"{d}/append.bin", "rb").read(), 16)
assert t == "boot one\nline two\nno newline at the end\nboot two\n", repr(t)
t = read_zone(open(f"{d}/wrap.bin", "rb").read(), 16)
lines = [l for l in t.split("\n") if l]
assert lines[-1] == "line 0999" and all(l.startswith("line ") for l in lines[1:]), lines[-3:]
nums = [int(l[5:]) for l in lines[1:]]
assert nums == list(range(nums[0], 1000)), "wrapped text is contiguous"
assert read_zone(open(f"{d}/noecc.bin", "rb").read(), 0) == "plain\n"
print(f"ok: append, wrap ({len(nums)} trailing lines kept), no-ecc")
