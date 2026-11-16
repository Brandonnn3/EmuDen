#!/usr/bin/env python3
"""Build an original, freestanding PowerPC DOL without a console SDK or firmware.

This is a VI framebuffer/SI input fixture, not a GX or retail-game benchmark.
Register layouts are checked against the pinned Dolphin hardware implementation.
"""
import argparse
import struct
import math
import importlib.util
from pathlib import Path


def make_dol(audio=False, full_input=False, gx=False, card=False):
    code, labels, fixups = [], {}, []

    def emit(word):
        code.append(word & 0xFFFFFFFF)

    def li(reg, value):
        emit(0x3C000000 | reg << 21 | (value >> 16 & 0xFFFF))
        emit(0x60000000 | reg << 21 | reg << 16 | (value & 0xFFFF))

    def store(reg, base, offset, half=False):
        emit((0xB0000000 if half else 0x90000000) | reg << 21 | base << 16 | offset)

    def branch(label, opcode=0x48000000):
        fixups.append((len(code), label, opcode))
        emit(opcode)

    # Boot's open HLE setup supplies BAT mappings; this code uses no OS calls.
    li(3, 0xCC002000)
    for offset, value, half in [(0x00, (240 << 4) | 6, True),
                                (0x0C, (5 << 16) | 22, False),
                                (0x10, (4 << 16) | 23, False),
                                (0x1C, 0x00100000, False),
                                (0x24, 0x00100000, False),
                                (0x48, 0x1414, True), (0x02, 5, True)]:
        li(4, value)
        store(4, 3, offset, half)
    li(10, 0xCC006400)
    li(4, 0x00400300)  # Standard pad direct-read, analog mode 3.
    store(4, 10, 0)
    li(4, 0x00070180)  # Channel 0 poll enabled, one poll each frame.
    store(4, 10, 0x30)
    li(4, 0x80000000)
    store(4, 10, 0x38)
    tone = b''
    if audio:
        tone = b''.join(struct.pack('>hh', value, value) for value in
                        (int(3000 * math.sin(2 * math.pi * 440 * i / 48000)) for i in range(4800)))
        li(3, 0xCC005000)
        for offset, value in [(0x30, 0x22), (0x32, 0), (0x36, 0x8000 | (len(tone) // 32))]:
            li(4, value); store(4, 3, offset, True)
    gx_stream = b''
    if card:
        # Original raw-card protocol diagnostic, in a fresh QA card's free sector.
        li(14,0xCC006800)
        def exi(value,count=4,read=False):
            li(4,value); store(4,14,0x10)
            li(4,((count-1)<<4)|(0 if read else 4)|1); store(4,14,0x0c)
            label='exi-wait-'+str(len(code));labels[label]=len(code)
            emit(0x80000000|5<<21|14<<16|0x0c)
            emit(0x70000000|5<<21|5<<16|1)
            branch(label,0x40820000)
        li(4,0x80);store(4,14,0)
        exi(0x52005000);exi(0,1);exi(0) # ReadArray, address0xA000 and4 dummy bytes.
        exi(0,read=True)
        emit(0x80000000|17<<21|14<<16|0x10)
        li(4,0);store(4,14,0)
        li(4,0x80);store(4,14,0)
        exi(0xf2005000);exi(0,1);exi(0x454d4338);exi(0xcafebabe)
        li(4,0);store(4,14,0)
    if gx:
        spec=importlib.util.spec_from_file_location('gx_commands',Path(__file__).with_name('gamecube-gx-commands.py'))
        helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
        gx_stream=helper.commands()
        li(3,0xCC003000)
        for off,value in [(12,0x300000),(16,0x31ffe0),(20,0x300000)]:li(4,value);store(4,3,off)
        li(3,0xCC000000)
        for off,value in [(2,0),(32,0),(34,0x30),(36,0xffe0),(38,0x31),
                          (40,0xffe0),(42,1),(44,0),(46,1),(48,0),(50,0),
                          (52,0),(54,0x30),(56,0),(58,0x30),(4,3),(2,0x11)]:
            li(4,value);store(4,3,off,True)
        li(3,0xCC008000);li(4,0x80400000);li(5,len(gx_stream)//4)
        emit(0x7ca903a6) # mtctr r5
        labels['gx-write']=len(code)
        emit(0x80000000|6<<21|4<<16);store(6,3,0)
        emit(0x38000000|4<<21|4<<16|4);branch('gx-write',0x42000000)
    li(11, 0x80010000)
    li(4, 0x454D5544)
    store(4, 11, 0)
    if card: store(17,11,4)
    li(20, 0)
    li(12, 0x80100000)
    labels['loop'] = len(code)
    emit(0x38000000 | 20 << 21 | 20 << 16 | 1)  # addi r20,r20,1
    if not card: store(20, 11, 4)
    emit(0x80000000 | 5 << 21 | 10 << 16 | 4)  # lwz r5,4(r10)
    store(5, 11, 8)
    if full_input:
        emit(0x80000000 | 6 << 21 | 10 << 16 | 8)  # SI mode3 C-stick and trigger bytes.
        store(6, 11, 12)
    emit(0x74000000 | 5 << 21 | 6 << 16 | 0x0100)  # andis. r6,r5,PAD_A
    branch('released', 0x41820000)
    li(7, 0xB060B090)
    branch('paint')
    labels['released'] = len(code)
    li(7, 0x307030A0)
    labels['paint'] = len(code)
    if not gx: store(7, 12, 0)
    branch('loop')
    for index, label, opcode in fixups:
        distance = (labels[label] - index) * 4
        mask = 0x03FFFFFC if opcode == 0x48000000 else 0xFFFC
        assert -(mask // 2) <= distance <= mask // 2
        code[index] = opcode | (distance & mask)
    text = struct.pack('>' + 'I' * len(code), *code)
    text += b'\0' * (-len(text) % 32)
    pixels = bytearray()
    for y in range(240):
        for x in range(0, 320, 2):
            # Original midnight/cyan console test pattern with a bright center.
            panel = 54 < x < 266 and 54 < y < 184
            light = 170 if panel and ((x // 24 + y // 24) % 2) else 48
            pixels.extend((light if panel else 24 + y // 6, 144, light, 112))
    header = bytearray(256)
    for offset, value in [(0x00, 256), (0x1C, 256 + len(text)),
                          (0x48, 0x80003100), (0x64, 0x80100000),
                          (0x90, len(text)), (0xAC, len(pixels)),
                          (0xD8, 0x80010000), (0xDC, 32), (0xE0, 0x80003100)]:
        struct.pack_into('>I', header, offset, value)
    if gx:
        for offset,value in [(0x24,256+len(text)+len(pixels)+len(tone)),(0x6c,0x80400000),(0xb4,len(gx_stream))]:
            struct.pack_into('>I',header,offset,value)
    if audio:
        for offset, value in [(0x20, 256 + len(text) + len(pixels)), (0x68, 0x80220000), (0xB0, len(tone))]:
            struct.pack_into('>I', header, offset, value)
    return bytes(header) + text + pixels + tone + gx_stream


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path,
                        default=Path('build/Build20-Preparation/EmuDen-GC-Demo.dol'))
    parser.add_argument('--full-input', action='store_true', help='Capture the second SI response word for analog-input QA')
    parser.add_argument('--gx', action='store_true')
    parser.add_argument('--native-card',action='store_true')
    parser.add_argument('--audio',action='store_true')
    args = parser.parse_args()
    dol = make_dol(full_input=args.full_input,gx=args.gx,card=args.native_card,audio=args.audio)
    assert struct.unpack_from('>I', dol, 0xE0)[0] == 0x80003100
    data_offset = struct.unpack_from('>I', dol, 0x1C)[0]
    assert data_offset + 320 * 240 * 2 <= len(dol)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(dol)
    print(f'Wrote original {len(dol)}-byte GameCube framebuffer/input fixture: {args.output}')
