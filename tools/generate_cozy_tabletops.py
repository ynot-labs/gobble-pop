#!/usr/bin/env python3
"""
Gobble Pop! — Grounded Mid-Light Morandi Tabletop Texture Generator
Uses mid-light restful tones (L ~ 70%-78%) with gentle 5-6% tile contrast and subtle organic texture
so that under lit WebGL2 shading (total diffuse ~ 0.90), textures NEVER blow out to white and
light-colored props (whipped cream, sushi rice, white unicorn, target rings) pop clearly with zero glare.
"""
import math
import os
import struct
import zlib

TEX_DIR = "/Users/unmercy/Documents/antig/hole/assets/textures"
os.makedirs(TEX_DIR, exist_ok=True)


def hex_rgb(hx):
    hx = hx.lstrip("#")
    return (int(hx[0:2], 16) / 255.0, int(hx[2:4], 16) / 255.0, int(hx[4:6], 16) / 255.0)


def write_png_rgb(path, width, height, rows_bytes):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + r for r in rows_bytes)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def clamp_byte(v):
    iv = int(v * 255.0 + 0.5)
    return 0 if iv < 0 else (255 if iv > 255 else iv)


def gen_tabletop(path, col_a_hex, col_b_hex, style="marble", size=256):
    a = hex_rgb(col_a_hex)
    b = hex_rgb(col_b_hex)
    rows = []
    tau = math.tau

    for py in range(size):
        y = py / size
        cy = int(y * 4.0) % 2
        fy = (y * 4.0) % 1.0
        dy = abs(fy - 0.5) * 2.0
        row = bytearray(size * 3)

        for px in range(size):
            x = px / size
            cx = int(x * 4.0) % 2
            fx = (x * 4.0) % 1.0
            dx = abs(fx - 0.5) * 2.0

            if style == "hinoki":
                # Warm Japanese hinoki wood planks (gentle grain + plank seam, zero square flicker!)
                plank = int(y * 4.0) % 2
                grain = math.sin(y * tau * 14.0 + math.sin(x * tau * 2.0) * 0.7) * 0.016
                grain += math.sin(x * tau * 3.0 + y * tau * 5.0) * 0.008
                py_seam = abs(((y * 4.0) % 1.0) - 0.5) * 2.0
                seam = max(0.0, (py_seam - 0.94) / 0.06) * 0.055
                t = float(plank)
                mod = grain - seam
            elif style == "playmat":
                # Warm oatmeal cork playmat with subtle tile shift & soft center dimple
                t = float((cx + cy) % 2)
                dist2 = (fx - 0.5) ** 2 + (fy - 0.5) ** 2
                dot = -0.032 if dist2 < (0.068 ** 2) else 0.0
                edge = max(dx, dy)
                seam = max(0.0, (edge - 0.95) / 0.05) * 0.045
                speck = math.sin(x * tau * 14.0 + y * tau * 11.0) * 0.007
                mod = dot - seam + speck
            elif style == "linen":
                # Misty slate-lavender woven alchemist desk mat
                t = float((cx + cy) % 2)
                weave = (math.sin((x + y) * tau * 18.0) + math.cos((x - y) * tau * 18.0)) * 0.010
                edge = max(dx, dy)
                seam = max(0.0, (edge - 0.95) / 0.05) * 0.042
                mod = weave - seam
            else:
                # Soft sage-mint bakery ceramic tiles with delicate warm stone vein
                t = float((cx + cy) % 2)
                vein = math.sin(x * tau * 2.0 + math.sin(y * tau * 2.0) * 1.1) * 0.014
                vein += math.cos(y * tau * 3.0 - x * tau * 1.0) * 0.009
                edge = max(dx, dy)
                seam = max(0.0, (edge - 0.95) / 0.05) * 0.042
                mod = vein - seam

            r = a[0] * (1.0 - t) + b[0] * t + mod
            g = a[1] * (1.0 - t) + b[1] * t + mod
            bl = a[2] * (1.0 - t) + b[2] * t + mod
            idx = px * 3
            row[idx] = clamp_byte(r)
            row[idx + 1] = clamp_byte(g)
            row[idx + 2] = clamp_byte(bl)

        rows.append(bytes(row))

    write_png_rgb(path, size, size, rows)
    kb = os.path.getsize(path) / 1024.0
    print(f"Generated {os.path.basename(path)} ({style}, {size}x{size}, {kb:.1f} KB)")


def main():
    gen_tabletop(os.path.join(TEX_DIR, "w1_01_marble_tile.png"), "#C6DBD1", "#B7CFC4", style="marble")
    gen_tabletop(os.path.join(TEX_DIR, "w2_01_playmat_tile.png"), "#D9CEB8", "#CCC0A8", style="playmat")
    gen_tabletop(os.path.join(TEX_DIR, "w3_01_table_tile.png"), "#CFAF8B", "#C2A07B", style="hinoki")
    gen_tabletop(os.path.join(TEX_DIR, "w4_01_desk_tile.png"), "#B8B3CA", "#AAA4BE", style="linen")


if __name__ == "__main__":
    main()
