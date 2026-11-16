#!/usr/bin/env python3
"""Original, redistributable PS-X EXE: GPU shapes, controller colors and a looping SPU tone.

Copyright 2026 EmuDen contributors. GPL-3.0-or-later. Contains no Sony code/data.
An intentionally tiny MIPS emitter keeps the test reproducible without a PS1 SDK.
"""
import argparse
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
BASE = 0x80010000
code, labels, branches = [], {}, []
R = {'zero': 0, 'v0': 2, 'a0': 4, 'a1': 5, 'a2': 6, 'a3': 7,
     't0': 8, 't1': 9, 't2': 10, 's0': 16, 's1': 17, 's2': 18, 's3': 19,
     'sp': 29, 'ra': 31}
def op(word): code.append(word)
def i(opcode, rt, rs, value): op((opcode << 26) | (R[rs] << 21) | (R[rt] << 16) | (value & 65535))
def li(reg, value):
    i(15, reg, 'zero', value >> 16)
    i(13, reg, reg, value)
def store(reg, offset=0, base='s0'): i(43, reg, base, offset)
def sh(reg, offset, base='s3'): i(41, reg, base, offset)
def jump(label): branches.append((len(code), label, 'j')); op(0); op(0)
def branch(opcode, rt, rs, label): branches.append((len(code), label, (opcode, rt, rs))); op(0); op(0)
def label(name): labels[name] = len(code)
def gpu(value, control=False): li('t0', value); store('t0', 4 if control else 0)
def reg16(offset, value): li('t0', value); sh('t0', offset)
def rect(color, x, y, width, height):
    gpu(0x02000000 | color); gpu((y << 16) | x); gpu((height << 16) | width)

li('sp', 0x801fff00)
li('s0', 0x1f801810)
li('s2', 0x80020000)
li('s3', 0x1f801c00)
# HLE implements the documented PAD BIOS API; the fixture itself contains no firmware.
li('a0', 0x80020000); li('a1', 34); li('a2', 0x80020040); li('a3', 34)
li('t1', 0x12); op((3 << 26) | (0xb0 >> 2)); op(0)
li('t1', 0x13); op((3 << 26) | (0xb0 >> 2)); op(0)
for value in [0x00000000, 0x05000000, 0x06c60260, 0x07042018, 0x08000001, 0x03000000]: gpu(value, True)
for value in [0xe1000400, 0xe3000000, 0xe403bd3f, 0xe5000000]: gpu(value)
# One original ADPCM loop, uploaded through the emulated SPU FIFO.
reg16(0x1a6, 0x200)
for word in [0x070c, 0x7777, 0x3333, 0xffff, 0x9999, 0xdddd, 0x1111, 0x5555]: reg16(0x1a8, word)
for offset, value in [(0x180, 0x3fff), (0x182, 0x3fff), (0, 0x1fff), (2, 0x1fff),
                      (4, 0x0800), (6, 0x0200), (8, 0x00ff), (10, 0),
                      (14, 0x0200), (0x1aa, 0xc000), (0x188, 1)]: reg16(offset, value)
# A real emulated BIOS file write checks native card persistence independently of states.
li('a0', 1); li('t1', 0x4a); op((3 << 26) | (0xb0 >> 2)); op(0)
li('t1', 0x4b); op((3 << 26) | (0xb0 >> 2)); op(0)
name_pointer = len(code); li('a0', 0)
li('a1', 0x10200); li('t1', 0x32); op((3 << 26) | (0xb0 >> 2)); op(0)
i(9, 'a0', 'v0', 0)
data_pointer = len(code); li('a1', 0)
li('a2', 128); li('t1', 0x35); op((3 << 26) | (0xb0 >> 2)); op(0)
label('draw')
rect(0x22160e, 0, 0, 320, 240)
rect(0x543728, 32, 32, 256, 176)
# Cross changes the center panel from amber to cyan.
i(37, 't2', 's2', 2); op(0)
i(12, 't2', 't2', 0x4000)
branch(4, 't2', 'zero', 'pressed')
li('s1', 0x0248b8ef)
jump('panel')
label('pressed'); li('s1', 0x02dfd04c)
label('panel')
store('s1'); gpu((64 << 16) | 64); gpu((112 << 16) | 192)
# A triangle and four small control lights exercise primitive drawing.
for value in [0x30ffffff, (77 << 16) | 160, 0x0070d0ff, (157 << 16) | 112,
              0x00ffe070, (157 << 16) | 208]: gpu(value)
i(37, 't2', 's2', 2); op(0); i(12, 't2', 't2', 0x10)
branch(4, 't2', 'zero', 'dpad_on')
li('s1', 0x02d1e8ee); jump('dpad_light')
label('dpad_on'); li('s1', 0x024ce07a)
label('dpad_light'); store('s1'); gpu((188 << 16) | 112); gpu((8 << 16) | 16)
for x in [144, 176, 208]: rect(0xd1e8ee, x, 188, 16, 8)
li('t2', 12000)
label('delay'); i(9, 't2', 't2', -1); branch(5, 't2', 'zero', 'delay')
jump('draw')
for index, name, kind in branches:
    if kind == 'j': code[index] = (2 << 26) | (((BASE + labels[name] * 4) >> 2) & 0x3ffffff)
    else:
        opcode, rt, rs = kind
        delta = labels[name] - index - 1
        assert -32768 <= delta <= 32767
        code[index] = (opcode << 26) | (R[rs] << 21) | (R[rt] << 16) | (delta & 65535)
strings = b'bu00:EMUDEN-QA\0'.ljust(32, b'\0') + b'EMUDEN-PERSIST-01\0'.ljust(128, b'\0')
for index, reg, address in [(name_pointer, 'a0', BASE + len(code) * 4), (data_pointer, 'a1', BASE + len(code) * 4 + 32)]:
    code[index] = (15 << 26) | (R[reg] << 16) | (address >> 16)
    code[index + 1] = (13 << 26) | (R[reg] << 21) | (R[reg] << 16) | (address & 65535)
payload = struct.pack('<' + 'I' * len(code), *code) + strings
payload += bytes((-len(payload)) % 2048)
header = bytearray(2048); header[:8] = b'PS-X EXE'
for offset, value in [(0x10, BASE), (0x18, BASE), (0x1c, len(payload)), (0x30, 0x801fff00)]: struct.pack_into('<I', header, offset, value)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT / 'Tests/Fixtures/EmuDen-PS1-Demo.exe')
parser.add_argument('--disc-folder', type=Path, help='Also create an original ISO9660 CUE/BIN fixture here')
args = parser.parse_args(); output = args.output
output.write_bytes(header + payload)
print(f'Wrote original homebrew: {output.name}, {output.stat().st_size} bytes')
if args.disc_folder:
    folder = args.disc_folder; folder.mkdir(parents=True, exist_ok=True)
    exe = bytes(header) + payload
    system = b'BOOT = cdrom:\\EMUDEN.EXE;1\r\nTCB = 4\r\nEVENT = 16\r\nSTACK = 801fff00\r\n'
    count = 32
    sectors = [bytearray(2048) for _ in range(count)]
    def both(value, bits=32): return value.to_bytes(bits // 8, 'little') + value.to_bytes(bits // 8, 'big')
    def entry(name, block, length, directory=False):
        size = 33 + len(name) + (len(name) % 2 == 0)
        record = bytearray(size); record[0] = size; record[2:10] = both(block); record[10:18] = both(length)
        record[18:25] = bytes([126, 1, 1, 0, 0, 0, 0]); record[25] = 2 if directory else 0
        record[28:32] = both(1, 16); record[32] = len(name); record[33:33 + len(name)] = name
        return record
    pvd = sectors[16]; pvd[0:7] = b'\x01CD001\x01'; pvd[8:40] = b'PLAYSTATION'.ljust(32, b' ')
    pvd[40:72] = b'EMUDEN ORIGINAL DEMO'.ljust(32, b' '); pvd[80:88] = both(count)
    pvd[120:124] = both(1, 16); pvd[124:128] = both(1, 16); pvd[128:132] = both(2048, 16)
    pvd[132:140] = both(10); pvd[140:144] = (18).to_bytes(4, 'little'); pvd[148:152] = (19).to_bytes(4, 'big')
    pvd[156:190] = entry(b'\0', 20, 2048, True); pvd[881] = 1
    sectors[17][:7] = b'\xffCD001\x01'
    sectors[18][:10] = bytes([1, 0]) + (20).to_bytes(4, 'little') + (1).to_bytes(2, 'little') + bytes(2)
    sectors[19][:10] = bytes([1, 0]) + (20).to_bytes(4, 'big') + (1).to_bytes(2, 'big') + bytes(2)
    directory = b''.join([entry(b'\0', 20, 2048, True), entry(b'\x01', 20, 2048, True),
                          entry(b'SYSTEM.CNF;1', 21, len(system)), entry(b'EMUDEN.EXE;1', 22, len(exe))])
    sectors[20][:len(directory)] = directory; sectors[21][:len(system)] = system
    for index in range(0, len(exe), 2048): sectors[22 + index // 2048][:len(exe[index:index + 2048])] = exe[index:index + 2048]
    def bcd(n): return (n // 10) * 16 + n % 10
    raw = bytearray()
    for index, sector in enumerate(sectors):
        frame = index + 150
        raw += b'\0' + b'\xff' * 10 + b'\0' + bytes([bcd(frame // 4500), bcd(frame // 75 % 60), bcd(frame % 75), 2])
        raw += bytes([0, 0, 8, 0]) * 2 + sector + bytes(280)
    assert len(raw) == count * 2352
    (folder / 'EmuDen Demo.bin').write_bytes(raw)
    (folder / 'EmuDen Demo.cue').write_text('FILE "EmuDen Demo.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n')
    print('Wrote original CUE/BIN disc fixture:', folder)
