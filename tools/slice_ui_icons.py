#!/usr/bin/env python3
"""
Gobble Pop! — Commercial 3D UI Icon Slicer & Flood-Fill Background Remover
Decodes the 3 generated 3D candy icon sheets via ffmpeg, performs BFS exterior white flood-fill
(strictly preserving interior white whipped cream, unicorn bodies, and glossy highlights!),
applies soft edge anti-aliasing, centers each icon tightly into a 128x128 transparent RGBA PNG.
"""
import collections
import os
import struct
import subprocess
import zlib

ART_DIR = "/Users/unmercy/.gemini/antigravity/brain/3be651bd-193c-44b0-a17f-2db6960914a9"
OUT_DIR = "/Users/unmercy/Documents/antig/hole/assets/ui/icons"
os.makedirs(OUT_DIR, exist_ok=True)

SHEETS = [
    (
        os.path.join(ART_DIR, "game_ui_icons_4x3_sheet_1795354674714.jpg"),
        4, 3,
        [
            "icon_timer", "icon_flame", "icon_sound_on", "icon_sound_off",
            "icon_magnet", "icon_ice", "icon_play", "icon_restart",
            "icon_ad", "icon_fever", "icon_crown", "icon_check",
        ],
    ),
    (
        os.path.join(ART_DIR, "casual_game_icons_4x2_1795354677746.jpg"),
        4, 2,
        [
            "item_w1_strawberry", "item_w1_macaron", "item_w1_boba_tea", "item_w1_donut",
            "item_w1_cake", "item_w2_duck", "item_w2_figurine", "item_w2_arcade",
        ],
    ),
    (
        os.path.join(ART_DIR, "hole_stars_icons_4x2_sheet_1795354679386.jpg"),
        4, 2,
        [
            "item_w2_unicorn", "item_w2_golden_gacha", "item_w3_ramen", "item_w3_bento",
            "item_w4_potion", "item_w4_spellbook", "item_w4_cauldron", "icon_hole",
        ],
    ),
    (
        os.path.join(ART_DIR, "candy_pop_ui_icons_4x3_clean_1795356039344.jpg"),
        4, 3,
        [
            "icon_coin", "icon_star", "icon_star_empty", "icon_pause",
            "icon_home", "icon_shop", "icon_map", "icon_gear",
            "icon_lock", "icon_chest", "icon_hand", "icon_bgm",
        ],
    ),
    (
        os.path.join(ART_DIR, "candy_pop_game_icons_4x2_1795356019855.jpg"),
        4, 2,
        [
            "icon_arrow", "icon_shard", "skin_classic", "skin_berry",
            "skin_neon", "skin_royal", "skin_mint", "skin_magma",
        ],
    ),
    (
        os.path.join(ART_DIR, "retro_gaming_candy_pop_icons_grid_clean_1795399699847.jpg"),
        4, 2,
        [
            "item_w5_coin", "item_w5_cartridge", "item_w5_gamepad", "item_w5_handheld",
            "item_w5_vr", "item_w5_arcade_boss", "icon_trophy", "skin_pixel",
        ],
    ),
]


def probe_size(path):
    out = subprocess.check_output([
        "/opt/homebrew/bin/ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height", "-of", "csv=s=x:p=0", path
    ]).decode().strip()
    w, h = out.split("x")
    return int(w), int(h)


def decode_rgb(path):
    w, h = probe_size(path)
    raw = subprocess.check_output([
        "/opt/homebrew/bin/ffmpeg", "-v", "error", "-i", path,
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-"
    ])
    return w, h, raw


def write_png_rgba(path, w, h, rgba_bytes):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    stride = w * 4
    rows = [b"\x00" + rgba_bytes[y * stride:(y + 1) * stride] for y in range(h)]
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"".join(rows), 7)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def is_bg_white(r, g, b):
    # Pure or near-white backdrop pixel (low chroma, very high luminance)
    mx = max(r, g, b)
    mn = min(r, g, b)
    return mn >= 234 and (mx - mn) <= 18


def process_cell(raw, img_w, x0, y0, cw, ch, name, target_size=128):
    # Extract cell RGB into flat arrays
    cell_r = bytearray(cw * ch)
    cell_g = bytearray(cw * ch)
    cell_b = bytearray(cw * ch)
    for y in range(ch):
        src_off = ((y0 + y) * img_w + x0) * 3
        dst_off = y * cw
        for x in range(cw):
            i3 = src_off + x * 3
            cell_r[dst_off + x] = raw[i3]
            cell_g[dst_off + x] = raw[i3 + 1]
            cell_b[dst_off + x] = raw[i3 + 2]

    # BFS exterior flood-fill from cell border (also catches donut center hole if seeded on white near center? No, keep interior safe, handle donut hole specifically!)
    bg = bytearray(cw * ch)
    q = collections.deque()

    def try_seed(x, y):
        idx = y * cw + x
        if not bg[idx] and is_bg_white(cell_r[idx], cell_g[idx], cell_b[idx]):
            bg[idx] = 1
            q.append((x, y))

    for x in range(cw):
        try_seed(x, 0)
        try_seed(x, ch - 1)
    for y in range(ch):
        try_seed(0, y)
        try_seed(cw - 1, y)

    # For donut / restart arrow / gear / lock, also seed known pure-white enclosed holes!
    if name in ("item_w1_donut", "icon_restart", "icon_gear"):
        try_seed(cw // 2, ch // 2)
    if name == "icon_lock":
        try_seed(cw // 2, int(ch * 0.28))

    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < cw and 0 <= ny < ch:
                nidx = ny * cw + nx
                if not bg[nidx] and is_bg_white(cell_r[nidx], cell_g[nidx], cell_b[nidx]):
                    bg[nidx] = 1
                    q.append((nx, ny))

    # Build alpha channel with soft 1-pixel fringe feathering & white-halo decontamination
    alpha = bytearray(cw * ch)
    min_x, min_y, max_x, max_y = cw, ch, -1, -1
    for y in range(ch):
        row_off = y * cw
        for x in range(cw):
            idx = row_off + x
            if bg[idx]:
                alpha[idx] = 0
                continue
            # Check if adjacent to background for smooth anti-aliased edge
            near_bg = False
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < cw and 0 <= ny < ch and bg[ny * cw + nx]:
                    near_bg = True
                    break
            r, g, b = cell_r[idx], cell_g[idx], cell_b[idx]
            if near_bg and min(r, g, b) > 210:
                # Feather near-white anti-aliased border pixels smoothly
                lum = (r + g + b) / 3.0
                a = int(max(0.0, min(255.0, (250.0 - lum) / 40.0 * 255.0)))
                alpha[idx] = a
            else:
                alpha[idx] = 255
            if alpha[idx] > 24:
                if x < min_x: min_x = x
                if y < min_y: min_y = y
                if x > max_x: max_x = x
                if y > max_y: max_y = y

    if max_x < min_x or max_y < min_y:
        min_x, min_y, max_x, max_y = 0, 0, cw - 1, ch - 1

    # Square padded crop around tight icon bounding box
    bw = max_x - min_x + 1
    bh = max_y - min_y + 1
    side = int(max(bw, bh) * 1.12)
    cx_f = (min_x + max_x) * 0.5
    cy_f = (min_y + max_y) * 0.5
    crop_x0 = cx_f - side * 0.5
    crop_y0 = cy_f - side * 0.5

    # Area-averaged supersampled resize into target_size x target_size RGBA
    out = bytearray(target_size * target_size * 4)
    scale = side / float(target_size)
    samples = 2

    for ty in range(target_size):
        for tx in range(target_size):
            sr = sg = sb = sa = 0.0
            cnt = samples * samples
            for sy in range(samples):
                py = int(crop_y0 + (ty + (sy + 0.5) / samples) * scale)
                for sx in range(samples):
                    px = int(crop_x0 + (tx + (sx + 0.5) / samples) * scale)
                    if 0 <= px < cw and 0 <= py < ch:
                        idx = py * cw + px
                        a = alpha[idx] / 255.0
                        sr += cell_r[idx] * a
                        sg += cell_g[idx] * a
                        sb += cell_b[idx] * a
                        sa += a
            avg_a = sa / cnt
            oi = (ty * target_size + tx) * 4
            if avg_a > 0.01:
                out[oi] = min(255, int(sr / sa + 0.5))
                out[oi + 1] = min(255, int(sg / sa + 0.5))
                out[oi + 2] = min(255, int(sb / sa + 0.5))
                out[oi + 3] = min(255, int(avg_a * 255.0 + 0.5))
            else:
                out[oi] = out[oi + 1] = out[oi + 2] = out[oi + 3] = 0

    out_path = os.path.join(OUT_DIR, f"{name}.png")
    write_png_rgba(out_path, target_size, target_size, bytes(out))
    return os.path.getsize(out_path) / 1024.0


def main():
    total_kb = 0.0
    count = 0
    for sheet_path, cols, rows, names in SHEETS:
        w, h, raw = decode_rgb(sheet_path)
        cw = w // cols
        ch = h // rows
        for idx, name in enumerate(names):
            r = idx // cols
            c = idx % cols
            kb = process_cell(raw, w, c * cw, r * ch, cw, ch, name, target_size=128)
            total_kb += kb
            count += 1
            print(f"  Sliced {name:24s} -> {kb:5.1f} KB")
    print(f"DONE! Sliced {count} transparent 128x128 candy icons ({total_kb:.1f} KB total) into {OUT_DIR}")


if __name__ == "__main__":
    main()
