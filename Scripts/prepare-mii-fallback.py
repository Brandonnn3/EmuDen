#!/usr/bin/env python3
"""Generate an original three-dimensional guest head in the open-source archive.

Console-imported Mii resources still take precedence. This is not an authentic Mii model.
Archive layout: B3n30/citra_system_archives, mii/mii-archive-format.md (GPL-2.0-or-later).
"""
from pathlib import Path
import argparse
import re
import struct
import math

ROOT = Path(__file__).resolve().parent.parent
HEADER = ROOT / "Vendor/Azahar/Source/externals/open_source_archives/include/mii.app.romfs.h"


def guest_texture():
    # An original, deliberately simple guest avatar, not Nintendo Mii artwork.
    pixels = bytearray(32 * 32 * 2)
    for y in range(32):
        for x in range(32):
            dx, dy = x + 0.5 - 16, y + 0.5 - 16
            rgba = (0, 0, 0, 0)
            if (x - 10.5) ** 2 + (y - 13) ** 2 < 2.0 ** 2 or (x - 21.5) ** 2 + (y - 13) ** 2 < 2.0 ** 2:
                rgba = (3, 2, 2, 15)
            if y > 19 and 6.5 ** 2 < dx * dx + (y - 16) ** 2 < 8.3 ** 2:
                rgba = (6, 2, 3, 15)
            r, g, b, a = rgba
            # PICA's 8x8 Morton texture tiles; RGBA4 components are little endian.
            morton = sum(((x >> bit) & 1) << (bit * 2) | ((y >> bit) & 1) << (bit * 2 + 1) for bit in range(3))
            offset = ((y // 8) * 32 * 8 + (x // 8) * 64 + morton) * 2
            struct.pack_into("<H", pixels, offset, r << 12 | g << 8 | b << 4 | a)
    return bytes(pixels)


def mesh(vertices, normals, uvs, indices, prefix=b""):
    assert 0 < len(vertices) <= 255 and len(normals) == len(vertices) and len(uvs) == len(vertices)
    assert len(indices) % 3 == 0 and all(0 <= i < len(vertices) for i in indices)
    result = bytearray(prefix + struct.pack("<4H", len(vertices), len(normals), len(uvs), 1))
    for position, normal, uv in zip(vertices, normals, uvs):
        result += struct.pack("<8h", *[round(x * 256) for x in position + normal], *[round(x * 8192) for x in uv])
    result += struct.pack("<HH", 4, len(indices)) + bytes(indices)
    result += b"\0" * (-len(result) % 4)
    return bytes(result)


def head(cap=False):
    vertices, normals, uvs, indices = [], [], [], []
    rows, columns = 8, 12
    for row in range(rows + 1):
        theta = row / rows * (1.06 if cap else math.pi)
        for column in range(columns + 1):
            phi = column / columns * 2 * math.pi
            normal = (math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi))
            radii = (24.5, 25.5, 20.5) if cap else (24, 25, 20)
            position = tuple(normal[i] * radii[i] + (25 if i == 1 else 0) for i in range(3))
            vertices.append(position); normals.append(normal); uvs.append((column / columns, row / rows))
    for row in range(rows):
        for column in range(columns):
            a = row * (columns + 1) + column; b = a + columns + 1
            if row > 0: indices += [a, a + 1, b]
            if cap or row < rows - 1: indices += [a + 1, b + 1, b]
    # Face models have three attachment coordinates; hair models have six hat transforms.
    return mesh(vertices, normals, uvs, indices, bytes(72 if cap else 36))


def face_canvas():
    vertices, normals, uvs, indices = [], [], [], []
    for row in range(5):
        for column in range(5):
            x, y = -17 + column * 8.5, 43 - row * 8
            z = math.sqrt(max(0.01, 1 - (x / 24) ** 2 - ((y - 25) / 25) ** 2)) * 20
            vertices.append((x, y, z + 0.35)); uvs.append((column / 4, row / 4))
            n = (x / 576, (y - 25) / 625, z / 400); length = math.sqrt(sum(v * v for v in n))
            normals.append(tuple(v / length for v in n))
    for row in range(4):
        for column in range(4):
            a = row * 5 + column; b = a + 5
            indices += [a, b, a + 1, a + 1, b, b + 1]
    return mesh(vertices, normals, uvs, indices)


def uniform_section(count, item):
    assert len(item) < 65536
    offsets = [0] + [(1 << 22) | len(item)] * (count - 1) + [len(item)]
    return struct.pack("<HH", count, len(item)) + struct.pack(f"<{count + 1}I", *offsets) + item


def update(data):
    header_size, _, _, _, _, _, _, file_meta, _, file_data = struct.unpack_from("<10I", data)
    assert header_size == 0x28, "Unexpected fallback RomFS header"
    _, _, offset, length, _, name_length = struct.unpack_from("<IIQQII", data, file_meta)
    name = data[file_meta + 32:file_meta + 32 + name_length].decode("utf-16le")
    assert name == "CFL_Res.dat" and file_data + offset + length <= len(data)
    resource = file_data + offset
    assert struct.unpack_from("<HH", data, resource) == (20, 0x0509)
    offsets = list(struct.unpack_from("<20I", data, resource + 4)) + [length]
    sections = [data[resource + offsets[i]:resource + offsets[i + 1]] for i in range(20)]
    counts = [struct.unpack_from("<H", section)[0] for section in sections]
    assert counts[2] == 12 and counts[5] == 264 and counts[7] == 18 and counts[19] == 18
    sections[2] = uniform_section(counts[2], head())
    sections[5] = uniform_section(counts[5], head(cap=True))
    sections[7] = uniform_section(counts[7], face_canvas())
    sections[19] = uniform_section(counts[19], struct.pack("<HHBBBB", 32, 32, 1, 10, 0, 0) + guest_texture())
    new_offsets = []; cursor = 84
    for section in sections:
        new_offsets.append(cursor); cursor += len(section)
    payload = struct.pack("<HH20I", 20, 0x0509, *new_offsets) + b"".join(sections)
    output = bytearray(data[:resource] + payload + data[resource + length:])
    struct.pack_into("<Q", output, file_meta + 16, len(payload))
    # All other models, textures and item counts remain those of the open-source archive.
    assert cursor == len(payload)
    return bytes(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source = HEADER.read_text()
    match = re.search(r"unsigned char MII_DATA\[\] = \{(.*?)\};", source, re.S)
    assert match, "Pinned Mii fallback header missing"
    data = bytes(int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", match[1]))
    result = update(data)
    assert update(result) == result, "Fallback generation must be idempotent"
    if args.check:
        assert data == result, "Run Scripts/prepare-mii-fallback.py before building"
    elif data != result:
        lines = [", ".join(f"0x{x:02x}" for x in result[i:i + 12]) for i in range(0, len(result), 12)]
        replacement = "\n  " + ",\n  ".join(lines) + "\n"
        HEADER.write_text(source[:match.start(1)] + replacement + source[match.end(1):])
        print("Generated original 3D guest head; console Mii archives retain precedence")
    print("Mii fallback structure, mesh bounds, indices and repeatability checks passed")


if __name__ == "__main__":
    main()
