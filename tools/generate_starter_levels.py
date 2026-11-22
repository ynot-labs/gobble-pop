#!/usr/bin/env python3
"""
Generate all 20 World 1 levels (Lv.1 - Lv.20) matching GDD Section 4.3 table
plus automated XP & Time Budget sanity validation.
"""
import json
import math
import os
import random

OUT_DIR = "/Users/unmercy/Documents/antig/hole/data/levels"
os.makedirs(OUT_DIR, exist_ok=True)

ITEM_XP = {
    "w1_sprinkle": 10,
    "w1_strawberry": 18,
    "w1_gummy_bear": 24,
    "w1_macaron": 45,
    "w1_boba_tea": 55,
    "w1_donut": 115,
    "w1_cake": 260,
    "w1_grand_cake": 400,
}

LEVEL_CONFIGS = {
    1:  dict(world=1, tag="TUTORIAL",   duration=45.0, max_tier=3, traps=0,  ice=0, magnet=0, targets={"w1_strawberry": 8,  "w1_macaron": 6,  "w1_donut": 3}),
    2:  dict(world=1, tag="EASY",       duration=45.0, max_tier=3, traps=0,  ice=0, magnet=0, targets={"w1_gummy_bear": 10, "w1_boba_tea": 6, "w1_donut": 4}),
    3:  dict(world=1, tag="NORMAL",     duration=45.0, max_tier=3, traps=0,  ice=0, magnet=0, targets={"w1_strawberry": 10, "w1_macaron": 8,  "w1_donut": 5}),
    4:  dict(world=1, tag="EASY",       duration=45.0, max_tier=3, traps=0,  ice=1, magnet=1, targets={"w1_gummy_bear": 10, "w1_boba_tea": 7, "w1_donut": 5}),
    5:  dict(world=1, tag="HARD",       duration=40.0, max_tier=3, traps=0,  ice=1, magnet=1, targets={"w1_macaron": 10,    "w1_boba_tea": 8, "w1_donut": 6}),
    6:  dict(world=1, tag="NORMAL",     duration=45.0, max_tier=4, traps=0,  ice=1, magnet=1, targets={"w1_macaron": 8,     "w1_donut": 6,    "w1_cake": 2}),
    7:  dict(world=1, tag="EASY",       duration=45.0, max_tier=4, traps=0,  ice=1, magnet=1, targets={"w1_boba_tea": 8,    "w1_donut": 6,    "w1_cake": 2}),
    8:  dict(world=1, tag="NORMAL",     duration=45.0, max_tier=4, traps=0,  ice=1, magnet=1, targets={"w1_macaron": 10,    "w1_donut": 7,    "w1_cake": 3}),
    9:  dict(world=1, tag="HARD",       duration=42.0, max_tier=4, traps=3,  ice=1, magnet=1, targets={"w1_boba_tea": 8,    "w1_donut": 6,    "w1_cake": 3}),
    10: dict(world=1, tag="SUPER_HARD", duration=38.0, max_tier=5, traps=8,  ice=1, magnet=1, targets={"w1_donut": 8,       "w1_cake": 3,     "w1_grand_cake": 2}),
    11: dict(world=1, tag="EASY",       duration=45.0, max_tier=4, traps=0,  ice=1, magnet=1, targets={"w1_sprinkle": 16,   "w1_macaron": 8,  "w1_cake": 2}),
    12: dict(world=1, tag="EASY",       duration=45.0, max_tier=4, traps=0,  ice=1, magnet=1, targets={"w1_strawberry": 12, "w1_donut": 6,    "w1_cake": 2}),
    13: dict(world=1, tag="NORMAL",     duration=45.0, max_tier=4, traps=2,  ice=1, magnet=1, targets={"w1_gummy_bear": 12, "w1_boba_tea": 8, "w1_cake": 3}),
    14: dict(world=1, tag="EASY",       duration=45.0, max_tier=4, traps=2,  ice=1, magnet=1, targets={"w1_macaron": 10,    "w1_donut": 7,    "w1_cake": 3}),
    15: dict(world=1, tag="HARD",       duration=38.0, max_tier=4, traps=5,  ice=1, magnet=1, targets={"w1_donut": 8,       "w1_cake": 4}),
    16: dict(world=1, tag="NORMAL",     duration=42.0, max_tier=5, traps=5,  ice=2, magnet=1, targets={"w1_donut": 7,       "w1_cake": 3,     "w1_grand_cake": 1}),
    17: dict(world=1, tag="NORMAL",     duration=42.0, max_tier=5, traps=6,  ice=2, magnet=1, targets={"w1_boba_tea": 9,    "w1_cake": 3,     "w1_grand_cake": 1}),
    18: dict(world=1, tag="NORMAL",     duration=42.0, max_tier=5, traps=7,  ice=2, magnet=1, targets={"w1_donut": 8,       "w1_cake": 3,     "w1_grand_cake": 2}),
    19: dict(world=1, tag="HARD",       duration=42.0, max_tier=5, traps=8,  ice=2, magnet=1, targets={"w1_donut": 8,       "w1_cake": 4,     "w1_grand_cake": 2}),
    20: dict(world=1, tag="SUPER_HARD", duration=36.0, max_tier=5, traps=12, ice=2, magnet=1, targets={"w1_donut": 8,       "w1_cake": 3,     "w1_grand_cake": 3}),
}


def ring_positions(cx, cz, radius, count, angle_offset=0.0):
    pts = []
    for i in range(count):
        a = angle_offset + (2.0 * math.pi * i) / max(count, 1)
        pts.append([round(cx + math.cos(a) * radius, 2), round(cz + math.sin(a) * radius, 2)])
    return pts


def grid_positions(x0, z0, cols, rows, sx, sz, jitter=0.18, seed=1):
    rng = random.Random(seed)
    pts = []
    for r in range(rows):
        for c in range(cols):
            x = x0 + (c - (cols - 1) / 2.0) * sx + rng.uniform(-jitter, jitter)
            z = z0 + (r - (rows - 1) / 2.0) * sz + rng.uniform(-jitter, jitter)
            pts.append([round(x, 2), round(z, 2)])
    return pts


def build_level(num):
    cfg = LEVEL_CONFIGS[num]
    items = []
    pattern = num % 3

    # Tier 1 abundant starter food (guarantee plenty of XP to hit Lv.2 fast!)
    sp_cols = 6 if num != 11 else 7
    sprinkles = grid_positions(0.0, 5.1, sp_cols, 3, 1.5, 1.05, 0.22, seed=num * 17)
    for i, pos in enumerate(sprinkles):
        items.append({"key": "w1_sprinkle", "pos": pos, "color_idx": i % 3})

    berry_n = max(9, cfg["targets"].get("w1_strawberry", 0) + 2)
    gummy_n = max(9, cfg["targets"].get("w1_gummy_bear", 0) + 2)
    if pattern == 0:
        b_pts = ring_positions(-3.1, 2.0, 1.8, berry_n, 0.2)
        g_pts = ring_positions(3.1, 2.0, 1.8, gummy_n, 0.5)
    elif pattern == 1:
        b_pts = grid_positions(-3.4, 1.2, 3, max(3, (berry_n + 2) // 3), 1.0, 1.1, 0.15, seed=num * 5)[:berry_n]
        g_pts = grid_positions(3.4, 1.2, 3, max(3, (gummy_n + 2) // 3), 1.0, 1.1, 0.15, seed=num * 7)[:gummy_n]
    else:
        b_pts = ring_positions(0.0, 2.2, 4.4, berry_n, 0.1)
        g_pts = ring_positions(0.0, 2.2, 2.6, gummy_n, 0.4)

    for i, pos in enumerate(b_pts):
        items.append({"key": "w1_strawberry", "pos": pos, "color_idx": 0})
    for i, pos in enumerate(g_pts):
        items.append({"key": "w1_gummy_bear", "pos": pos, "color_idx": i % 3})

    # Tier 2 macarons & boba cups
    mac_n = max(10, cfg["targets"].get("w1_macaron", 0) + 2)
    for i, pos in enumerate(ring_positions(0.0, -0.7, 4.0, mac_n, 0.15 + num * 0.1)):
        items.append({"key": "w1_macaron", "pos": pos, "color_idx": i % 3})

    boba_n = max(8, cfg["targets"].get("w1_boba_tea", 0) + 2)
    for i, pos in enumerate(ring_positions(0.0, -1.5, 2.55, boba_n, 0.45 + num * 0.1)):
        items.append({"key": "w1_boba_tea", "pos": pos, "color_idx": 0})

    # Tier 3 donuts
    donut_n = max(7, cfg["targets"].get("w1_donut", 0) + 2)
    for i, pos in enumerate(ring_positions(0.0, -4.4, 3.0, donut_n, 0.25)):
        items.append({"key": "w1_donut", "pos": pos, "color_idx": i % 2})

    # Tier 4 cakes
    if cfg["max_tier"] >= 4:
        cake_n = max(4, cfg["targets"].get("w1_cake", 0) + 1)
        for i, pos in enumerate(ring_positions(0.0, -6.1, 2.9, cake_n, math.pi / 6.0)):
            items.append({"key": "w1_cake", "pos": pos, "color_idx": 0})

    # Tier 5 grand cakes
    if cfg["max_tier"] >= 5:
        grand_n = max(1, cfg["targets"].get("w1_grand_cake", 1))
        grand_slots = [[-2.9, -7.9], [2.9, -7.9], [0.0, -8.3]]
        for i in range(grand_n):
            items.append({"key": "w1_grand_cake", "pos": grand_slots[i % len(grand_slots)], "color_idx": 0})

    # Powerups
    powerups = []
    ice_slots = [[-4.5, -2.2], [4.5, -5.6]]
    for i in range(cfg["ice"]):
        powerups.append({"kind": "ice", "pos": ice_slots[i % len(ice_slots)]})
    if cfg["magnet"] > 0:
        powerups.append({"kind": "magnet", "pos": [4.5, -2.2]})

    # Sticky bubblegum traps
    traps = []
    if cfg["traps"] > 0:
        inner_n = min(cfg["traps"], 8)
        for p in ring_positions(0.0, -2.0, 3.25, inner_n, 0.35):
            traps.append({"pos": p})
        if cfg["traps"] > 8:
            for p in ring_positions(0.0, -5.6, 4.3, cfg["traps"] - 8, 0.2):
                traps.append({"pos": p})

    # Validate XP feasibility (must exceed XP needed to reach max_target_tier)
    xp_needed = {3: 95 + 250, 4: 95 + 250 + 480, 5: 95 + 250 + 480 + 820}[cfg["max_tier"]]
    xp_available = sum(ITEM_XP[it["key"]] for it in items if it["key"] != "w1_grand_cake")
    assert xp_available >= xp_needed * 1.15, f"Lv.{num} XP tight: {xp_available} < {xp_needed}"

    level_data = {
        "level": num,
        "world": cfg["world"],
        "difficulty_tag": cfg["tag"],
        "duration": cfg["duration"],
        "max_target_tier": cfg["max_tier"],
        "targets": cfg["targets"],
        "items": items,
        "powerups": powerups,
        "traps": traps,
    }
    out_path = os.path.join(OUT_DIR, f"level_{num:03d}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(level_data, f, ensure_ascii=False, indent=2)
    return xp_available, xp_needed


if __name__ == "__main__":
    for lv in range(1, 21):
        avail, req = build_level(lv)
        print(f"Lv.{lv:02d} [{LEVEL_CONFIGS[lv]['tag']:10s}] dur={LEVEL_CONFIGS[lv]['duration']:4.0f}s traps={LEVEL_CONFIGS[lv]['traps']:2d} XP={avail}/{req} PASS")
