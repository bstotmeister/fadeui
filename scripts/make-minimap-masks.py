#!/usr/bin/env python3
"""Writes the small minimap's round masks: FadeUI/Media/MinimapMask<size>.tga.

The minimap only shows where its mask is white, and the mask is stretched over
the whole minimap. A circle <size>% as wide as the texture therefore crops the
map to the middle <size>% at the same zoom. Keep SIZES in step with Minimap.lua.
"""
import os
import struct

SIZES = range(30, 100, 5)  # 100% uses the minimap's own mask
DIM = 128  # pixels per side; WoW textures must be a power of two

out = os.path.join(os.path.dirname(__file__), "..", "FadeUI", "Media")
os.makedirs(out, exist_ok=True)

for size in SIZES:
    radius = DIM / 2 * size / 100
    pixels = bytearray()
    for y in range(DIM):
        for x in range(DIM):
            d = ((x + 0.5 - DIM / 2) ** 2 + (y + 0.5 - DIM / 2) ** 2) ** 0.5
            v = round(255 * min(1, max(0, radius - d + 0.5)))  # 1px soft edge
            pixels += bytes((v, v, v, v))  # BGRA: white and opaque inside
    # Uncompressed 32-bit TGA, 8 alpha bits, top-left origin.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, DIM, DIM, 32, 0x28)
    with open(os.path.join(out, f"MinimapMask{size}.tga"), "wb") as f:
        f.write(header + pixels)
