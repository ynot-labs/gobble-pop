#!/usr/bin/env python3
"""
Gobble Pop! — Option 2: High-Energy Bright Candy Pop Tabletop Tile Generator
Produces sunny, cheerful pastel tiles inspired by Hole Stars / Royal Match:
  - W1 Sugar Rush Bakery: Sunny pastel mint (#C4F3E5) x warm vanilla cream (#EAFCEE)
  - W2 Gacha Toybox:      Sunny butter-vanilla (#F8E8AE) x soft cream (#FDF6D8)
  - W3 Neon Bento Street: Warm sunny Japanese hinoki wood planks (#EED1AE x #F8E5CC)
  - W4 Cozy Alchemist:    Luminous pastel lilac (#DBD2FA) x soft lavender cream (#F0ECFE)
Strictly keeps inter-tile contrast smooth and soft (no harsh checkerboard flicker)
while keeping the tabletop luminous, appetizing, and high-CTR!
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


def gen_tabletop(path, col_a_hex, col_b_hex, seam_col_hex, style="marble", size=256):
    a = hex_rgb(col_a_hex)
    b = hex_rgb(col_b_hex)
    sc = hex_rgb(seam_col_hex)
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

            seam_w = 0.0
            mod = 0.0

            if style == "hinoki":
                plank = int(y * 4.0) % 2
                grain = math.sin(y * tau * 14.0 + math.sin(x * tau * 2.0) * 0.7) * 0.015
                grain += math.sin(x * tau * 3.0 + y * tau * 5.0) * 0.007
                py_seam = abs(((y * 4.0) % 1.0) - 0.5) * 2.0
                seam_w = max(0.0, (py_seam - 0.945) / 0.055) * 0.52
                t = float(plank)
                mod = grain
            elif style == "playmat":
                t = float((cx + cy) % 2)
                dist2 = (fx - 0.5) ** 2 + (fy - 0.5) ** 2
                dot = -0.028 if dist2 < (0.064 ** 2) else 0.0
                edge = max(dx, dy)
                seam_w = max(0.0, (edge - 0.952) / 0.048) * 0.48
                mod = dot
            elif style == "linen":
                t = float((cx + cy) % 2)
                weave = (math.sin((x + y) * tau * 18.0) + math.cos((x - y) * tau * 18.0)) * 0.008
                edge = max(dx, dy)
                seam_w = max(0.0, (edge - 0.952) / 0.048) * 0.46
                mod = weave
            else:
                # Option 2 Sunny Pastel Mint & Vanilla Glossy Bakery Tiles!
                t = float((cx + cy) % 2)
                vein = math.sin(x * tau * 2.0 + math.sin(y * tau * 2.0) * 1.1) * 0.010
                vein += math.cos(y * tau * 3.0 - x * tau * 1.0) * 0.006
                edge = max(dx, dy)
                seam_w = max(0.0, (edge - 0.952) / 0.048) * 0.50
                mod = vein

            r = a[0] * (1.0 - t) + b[0] * t + mod
            g = a[1] * (1.0 - t) + b[1] * t + mod
            bl = a[2] * (1.0 - t) + b[2] * t + mod

            # Blend crisp pastel tile grout
            r = r * (1.0 - seam_w) + sc[0] * seam_w
            g = g * (1.0 - seam_w) + sc[1] * seam_w
            bl = bl * (1.0 - seam_w) + sc[2] * seam_w

            idx = px * 3
            row[idx] = clamp_byte(r)
            row[idx + 1] = clamp_byte(g)
            row[idx + 2] = clamp_byte(bl)

        rows.append(bytes(row))

    write_png_rgb(path, size, size, rows)
    kb = os.path.getsize(path) / 1024.0
    print(f"Generated {os.path.basename(path)} ({style}, {size}x{size}, {kb:.1f} KB)")


def main():
    gen_tabletop(os.path.join(TEX_DIR, "w1_01_marble_tile.png"), "#B0EBDC", "#D7F5E8", "#7CCCB6", style="marble")
    gen_tabletop(os.path.join(TEX_DIR, "w2_01_playmat_tile.png"), "#EED794", "#F9ECC2", "#CFAF60", style="playmat")
    gen_tabletop(os.path.join(TEX_DIR, "w3_01_table_tile.png"), "#E2BE95", "#F1D8B8", "#C29668", style="hinoki")
    gen_tabletop(os.path.join(TEX_DIR, "w4_01_desk_tile.png"), "#C8BDF0", "#E2DBFB", "#9E8ED4", style="linen")


if __name__ == "__main__":
    main()
