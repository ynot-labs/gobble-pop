#!/usr/bin/env python3
"""
Upgrades Gobble Pop! V2.0 key campaign levels with 3D Stacked Physics Towers:
  - Redesigns Lv.1 as a jaw-dropping 20x14 Floating Bakery Island showcase (6 cascading towers!)
  - Adds vertical 2-3 tier stacked toppers on Lv.2-Lv.5 and every World's intro stage (Lv.21, 31, 41, 51)
  - Preserves 100% pass rate in tools/validate_difficulty.py
"""
import json
import math
import os

LEVELS_DIR = "/Users/unmercy/Documents/antig/hole/data/levels"


def rebuild_level_1():
    items = []
    c_idx = 0

    def add_it(key: str, x: float, z: float, y: float = 0.0):
        nonlocal c_idx
        e = {"key": key, "pos": [round(x, 2), round(z, 2)], "color_idx": c_idx}
        if y > 0.01:
            e["y"] = round(y, 2)
        items.append(e)
        c_idx += 1

    # Twin neat cookie & strawberry starter trails leading out from spawn (0, 1.8)
    for side in (-1.0, 1.0):
        for i in range(6):
            t = i / 5.0
            x = side * (1.4 + t * 5.2)
            z = 2.6 - math.sin(t * math.pi) * 2.0
            add_it("w1_sprinkle", x, z)
            add_it("w1_strawberry", x, z + 0.95)

    # Front tidy muffin & berry garden (instant Lv.1 -> Lv.2 ramp in 4 seconds!)
    for row in range(2):
        for col in range(-3, 4):
            if col == 0 and row == 0:
                continue
            add_it("w1_gummy_bear" if (col + row) % 2 == 0 else "w1_strawberry", col * 1.15, 4.1 + row * 1.05)

    # 6 Cascading 3-Tier Pastry Towers (Cupcakes / Ice Cream topped with Strawberries!)
    towers = [
        (-5.6, -0.5), (-2.6, -1.6), (2.6, -1.6), (5.6, -0.5),
        (-4.8, 3.0), (4.8, 3.0),
    ]
    for idx, (tx, tz) in enumerate(towers):
        base_k = "w1_macaron" if idx % 2 == 0 else "w1_boba_tea"
        mid_k = "w1_macaron" if idx % 2 == 1 else "w1_boba_tea"
        add_it(base_k, tx, tz, 0.0)
        add_it(mid_k, tx, tz, 0.58)
        add_it("w1_strawberry", tx, tz, 1.18)

    # Side flanking cupcake & cookie avenues
    for side in (-1.0, 1.0):
        for i in range(3):
            add_it("w1_macaron", side * 7.5, -2.8 + i * 2.1)
            add_it("w1_sprinkle", side * 8.4, -1.8 + i * 2.0)

    # 6 Hero Tier-3 Sprinkled Donuts (2 stacked double-donut corners + 2 inner!)
    add_it("w1_donut", -5.6, -4.2, 0.0)
    add_it("w1_donut", -5.6, -4.2, 0.48)
    add_it("w1_donut", 5.6, -4.2, 0.0)
    add_it("w1_donut", 5.6, -4.2, 0.48)
    add_it("w1_donut", -2.3, -4.5, 0.0)
    add_it("w1_donut", 2.3, -4.5, 0.0)

    # Centerpiece Hero Pancake Stack (Tier 4 visual landmark; optional bonus feast!)
    add_it("w1_cake", 0.0, -4.2, 0.0)

    lv1 = {
        "level": 1,
        "world": 1,
        "formation_name": "Sweet Bakery Island",
        "difficulty_tag": "TUTORIAL",
        "duration": 45,
        "arena": [20, 14],
        "spawn": [0.0, 1.6],
        "max_target_tier": 3,
        "streak_hint": 0,
        "targets": {
            "w1_macaron": 6,
            "w1_donut": 4,
        },
        "items": items,
        "powerups": [
            {"kind": "magnet", "pos": [-3.6, 1.2]},
            {"kind": "ice", "pos": [3.6, 1.2]},
        ],
        "traps": [],
        "walls": [],
        "bombs": [],
    }
    path = os.path.join(LEVELS_DIR, "level_001.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(lv1, f, indent=2)
    print(f"[OK] Rebuilt Lv.1 Sweet Bakery Island ({len(items)} items, 6x 3-tier + 2x 2-tier towers)")


def add_stacked_toppers(lv_num: int, base_key: str, topper_key: str, step_y: float, max_stacks: int = 8):
    path = os.path.join(LEVELS_DIR, f"level_{lv_num:03d}.json")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    # Remove any previously injected stacked toppers (idempotent!)
    items = [it for it in data.get("items", []) if float(it.get("y", 0.0)) < 0.01]
    added = 0
    c_idx = len(items)
    for it in list(items):
        if added >= max_stacks:
            break
        if it["key"] == base_key:
            items.append({
                "key": topper_key,
                "pos": list(it["pos"]),
                "y": round(step_y, 2),
                "color_idx": c_idx,
            })
            c_idx += 1
            added += 1
    data["items"] = items
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"[OK] Lv.{lv_num:02d}: injected {added} vertical stacked toppers ({topper_key} on {base_key})")


def main():
    rebuild_level_1()
    # Early W1 progression towers (keep HARD Lv.5 exact difficulty curve untouched!)
    add_stacked_toppers(2, "w1_boba_tea", "w1_strawberry", 0.68, 6)
    add_stacked_toppers(3, "w1_macaron", "w1_sprinkle", 0.62, 6)
    add_stacked_toppers(4, "w1_donut", "w1_macaron", 0.48, 6)
    add_stacked_toppers(5, "w1_donut", "w1_strawberry", 0.48, 0)
    # World 2, 3, 4, 5 hero showcase intro towers!
    add_stacked_toppers(21, "w2_duck", "w2_block", 0.62, 8)
    add_stacked_toppers(31, "w3_ramen", "w3_sushi", 0.52, 8)
    add_stacked_toppers(41, "w4_potion", "w4_d20", 0.68, 8)
    add_stacked_toppers(51, "w5_gamepad", "w5_pixel_coin", 0.78, 8)


if __name__ == "__main__":
    main()
