#!/usr/bin/env python3
"""Reproducible abstract PNG fixtures, no third-party images or network required."""
from pathlib import Path
import struct
import zlib
import colorsys

root = Path(__file__).resolve().parents[1] / 'Packages/StreamLabUI/Sources/StreamLabDesignSystem/Resources'
root.mkdir(parents=True, exist_ok=True)
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
for seed in range(6):
    w, h = 240, 360
    color = colorsys.hsv_to_rgb(seed / 6, .65, .65)
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            glow = max(0, 1 - ((x - 120)**2 + (y - 110)**2)**.5 / 220)
            stripe = .12 if (x + y // 2 + seed * 20) % 80 < 12 else 0
            shade = .12 + .65 * glow + stripe
            rows.extend(min(255, int(c * shade * 255)) for c in color)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')
    (root / f'poster-{seed}.png').write_bytes(png)
