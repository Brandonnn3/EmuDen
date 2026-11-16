#!/usr/bin/env python3
"""Original compact GameCube test disc/apploader, without SDK, firmware or retail data.

The boot protocol follows the pinned Dolphin Boot_BS2Emu.cpp RunApploader.
The payload is our existing freestanding VI/SI homebrew, not a GX benchmark.
"""
import argparse
import struct
from pathlib import Path
import importlib.util
_spec = importlib.util.spec_from_file_location("emuden_gc_homebrew", Path(__file__).with_name("make-gamecube-homebrew.py"))
_module = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_module)
make_dol = _module.make_dol


def make_disc():
    dol = make_dol(audio=True)
    sections = []
    for i in range(18):
        offset, address, size = [struct.unpack_from('>I', dol, n + 4 * i)[0] for n in (0, 0x48, 0x90)]
        if size:
            sections.append((address, size, 0x5000 + offset))
    sections.append((0x81700000, 32, 0x4000))
    code, labels, fixups = [], {}, []

    def emit(word): code.append(word & 0xffffffff)
    def li(reg, value):
        emit(0x3c000000 | reg << 21 | (value >> 16 & 0xffff))
        emit(0x60000000 | reg << 21 | reg << 16 | (value & 0xffff))
    def store(reg, base, offset): emit(0x90000000 | reg << 21 | base << 16 | offset)
    def load(reg, base, offset): emit(0x80000000 | reg << 21 | base << 16 | offset)
    def target(label, reg):
        fixups.append((len(code), label, reg)); li(reg, 0)

    for label, destination in [('init', 3), ('main', 4), ('close', 5)]:
        target(label, 6); store(6, destination, 0)
    emit(0x4e800020)
    labels['init'] = len(code)
    li(7, 0x81201000); li(6, 0); store(6, 7, 0)
    li(7, 0x80000000); li(6, 0x81700000); store(6, 7, 0x38)
    li(6, 32); store(6, 7, 0x3c); emit(0x4e800020)
    labels['main'] = len(code)
    li(7, 0x81201000); load(6, 7, 0)
    emit(0x2c000000 | 6 << 16 | len(sections))  # cmpwi r6,number of loads
    done = len(code); emit(0)
    li(8, 0x81201100)
    emit(0x1c000000 | 9 << 21 | 6 << 16 | 12)  # mulli r9,r6,12
    emit(0x7c000214 | 8 << 21 | 8 << 16 | 9 << 11)  # add r8,r8,r9
    for offset, destination in [(0, 3), (4, 4), (8, 5)]:
        load(10, 8, offset); store(10, destination, 0)
    emit(0x38000000 | 6 << 21 | 6 << 16 | 1); store(6, 7, 0)
    li(3, 1); emit(0x4e800020)
    end = len(code); li(3, 0); emit(0x4e800020)
    code[done] = 0x40800000 | ((end - done) * 4 & 0xfffc)  # bge done
    labels['close'] = len(code)
    li(3, struct.unpack_from('>I', dol, 0xe0)[0]); emit(0x4e800020)
    for at, label, reg in fixups:
        address = 0x81200000 + labels[label] * 4
        code[at:at+2] = [0x3c000000 | reg << 21 | address >> 16,
                        0x60000000 | reg << 21 | reg << 16 | (address & 0xffff)]
    loader = bytearray(0x1200)
    loader[:len(code)*4] = struct.pack('>' + 'I'*len(code), *code)
    for i, section in enumerate(sections): struct.pack_into('>III', loader, 0x1100 + i*12, *section)
    disc = bytearray((0x5000 + len(dol) + 0x7fff) & ~0x7fff)
    disc[:6] = b'EDNEHB'  # Original, synthetic homebrew ID.
    title = b'EmuDen Original Disc Test\0'
    disc[0x20:0x20+len(title)] = title
    for offset, value in [(0x1c, 0xc2339f3d), (0x420, 0x5000), (0x424, 0x4000),
                          (0x428, 32), (0x42c, 32), (0x458, 1),
                          (0x2450, 0x81200000), (0x2454, len(loader)), (0x2458, 0)]:
        struct.pack_into('>I', disc, offset, value)
    disc[0x2440:0x244a] = b'2026/11/13'
    disc[0x2460:0x2460+len(loader)] = loader
    struct.pack_into('>III', disc, 0x4000, 0x01000000, 0, 1)
    disc[0x5000:0x5000+len(dol)] = dol
    assert len(disc) % 0x8000 == 0 and disc[0x5000:0x5008] == dol[:8]
    return bytes(disc)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    data = make_disc(); args.output.write_bytes(data)
    print(f'Wrote original {len(data)}-byte disc/apploader fixture: {args.output}')
