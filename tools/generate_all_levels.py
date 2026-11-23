#!/usr/bin/env python3
"""
Gobble Pop! — 50 Handcrafted Hole-Stars-Style Sculptural Levels across ALL 4 Worlds!
  - World 1: Sugar Rush Bakery (Lv.1-20, Lv.10 SUPER_HARD, Lv.20 30x34 MEGA_BOSS)
  - World 2: Gacha Toybox      (Lv.21-30, Lv.29 SUPER_HARD, Lv.30 30x34 MEGA_BOSS, Rubber Walls)
  - World 3: Neon Bento Street (Lv.31-40, Lv.39 SUPER_HARD, Lv.40 30x34 MEGA_BOSS, Cheese + Time Bombs)
  - World 4: Cozy Alchemist    (Lv.41-50, Lv.49 SUPER_HARD, Lv.50 30x34 MEGA_BOSS, Slime + Bombs + Walls)

Implements Scheme A Difficulty Engineering:
  1. Tightened XP redundancy on Hard (<= 1.42x) and SUPER_HARD / MEGA_BOSS (1.14x - 1.24x)
  2. Spatial separation between growth yards and far-corner Lv.5 Boss targets
  3. Staggered guard traps + World 3-4 Time Bombs (-3s) on high-XP lanes
  4. Verified by tools/validate_difficulty.py (50/50 TimeRatio + Lv.5 BFS Reachability PASS)
"""
import json
import math
import os

OUT_DIR = "/Users/unmercy/Documents/antig/hole/data/levels"
os.makedirs(OUT_DIR, exist_ok=True)

CATALOG_PATH = "/Users/unmercy/Documents/antig/hole/data/item_catalog.json"
with open(CATALOG_PATH, "r", encoding="utf-8") as _f:
    CATALOG = json.load(_f)


# ---------------------------------------------------------------------------
# Geometric / sculptural formation generators (Hole Stars style!)
# ---------------------------------------------------------------------------
def pt_heart(count, sx=6.0, sz=5.5, cx=0.0, cz=0.0):
    pts = []
    for i in range(count):
        t = math.tau * i / count
        x = 16.0 * (math.sin(t) ** 3) / 16.0 * sx + cx
        z = -(13.0 * math.cos(t) - 5.0 * math.cos(2 * t) - 2.0 * math.cos(3 * t) - math.cos(4 * t)) / 16.0 * sz + cz
        pts.append([round(x, 2), round(z, 2)])
    return pts


def pt_spiral(count, r_start=1.6, r_end=7.2, turns=2.2, arm_offset=0.0, cx=0.0, cz=0.0):
    pts = []
    for i in range(count):
        u = i / max(1, count - 1)
        ang = arm_offset + u * turns * math.tau
        r = r_start + (r_end - r_start) * u
        pts.append([round(cx + math.cos(ang) * r, 2), round(cz + math.sin(ang) * r, 2)])
    return pts


def pt_star(points_n, r_outer, r_inner, per_edge, cx=0.0, cz=0.0, rot=0.0):
    verts = []
    for i in range(points_n * 2):
        a = rot + math.pi * i / points_n - math.pi / 2.0
        r = r_outer if i % 2 == 0 else r_inner
        verts.append((cx + math.cos(a) * r, cz + math.sin(a) * r))
    pts = []
    for i in range(len(verts)):
        x0, z0 = verts[i]
        x1, z1 = verts[(i + 1) % len(verts)]
        for k in range(per_edge):
            u = k / per_edge
            pts.append([round(x0 + (x1 - x0) * u, 2), round(z0 + (z1 - z0) * u, 2)])
    return pts


def pt_line(x0, z0, x1, z1, count):
    if count <= 1:
        return [[round(x0, 2), round(z0, 2)]]
    return [[round(x0 + (x1 - x0) * i / (count - 1), 2), round(z0 + (z1 - z0) * i / (count - 1), 2)] for i in range(count)]


def pt_arc(cx, cz, rx, rz, a0, a1, count):
    if count <= 1:
        return [[round(cx + math.cos(a0) * rx, 2), round(cz + math.sin(a0) * rz, 2)]]
    return [
        [round(cx + math.cos(a0 + (a1 - a0) * i / (count - 1)) * rx, 2),
         round(cz + math.sin(a0 + (a1 - a0) * i / (count - 1)) * rz, 2)]
        for i in range(count)
    ]


def pt_ring(cx, cz, rx, rz, count, offset=0.0):
    return [
        [round(cx + math.cos(offset + math.tau * i / count) * rx, 2),
         round(cz + math.sin(offset + math.tau * i / count) * rz, 2)]
        for i in range(count)
    ]


def pt_poly(sides, rx, rz, per_side, cx=0.0, cz=0.0, rot=0.0):
    verts = [
        (cx + math.cos(rot + math.tau * i / sides) * rx,
         cz + math.sin(rot + math.tau * i / sides) * rz)
        for i in range(sides)
    ]
    pts = []
    for i in range(sides):
        x0, z0 = verts[i]
        x1, z1 = verts[(i + 1) % sides]
        pts += pt_line(x0, z0, x1, z1, per_side)[:-1]
    return pts


def pt_rect_outline(cx, cz, hw, hh, per_side):
    pts = []
    pts += pt_line(cx - hw, cz - hh, cx + hw, cz - hh, per_side)[:-1]
    pts += pt_line(cx + hw, cz - hh, cx + hw, cz + hh, per_side)[:-1]
    pts += pt_line(cx + hw, cz + hh, cx - hw, cz + hh, per_side)[:-1]
    pts += pt_line(cx - hw, cz + hh, cx - hw, cz - hh, per_side)[:-1]
    return pts


def pt_diamond(cx, cz, rx, rz, per_side):
    verts = [(cx, cz - rz), (cx + rx, cz), (cx, cz + rz), (cx - rx, cz)]
    pts = []
    for i in range(4):
        x0, z0 = verts[i]
        x1, z1 = verts[(i + 1) % 4]
        pts += pt_line(x0, z0, x1, z1, per_side)[:-1]
    return pts


def pt_grid(cx, cz, cols, rows, sx, sz):
    pts = []
    for r in range(rows):
        for c in range(cols):
            pts.append([round(cx + (c - (cols - 1) / 2.0) * sx, 2),
                        round(cz + (r - (rows - 1) / 2.0) * sz, 2)])
    return pts


def pt_figure8(count, rx=6.5, rz=5.2, cx=0.0, cz=0.0):
    pts = []
    for i in range(count):
        t = math.tau * i / count
        x = cx + math.sin(t) * rx
        z = cz + math.sin(t) * math.cos(t) * 2.0 * rz
        pts.append([round(x, 2), round(z, 2)])
    return pts


def pt_wave(count, x0, x1, z_center, amp, cycles):
    pts = []
    for i in range(count):
        u = i / max(1, count - 1)
        x = x0 + (x1 - x0) * u
        z = z_center + math.sin(u * cycles * math.tau) * amp
        pts.append([round(x, 2), round(z, 2)])
    return pts


def add_items(items, key, pts, mod_colors=3, avoid_spawn=None):
    for i, p in enumerate(pts):
        if avoid_spawn is not None:
            if math.hypot(p[0] - avoid_spawn[0], p[1] - avoid_spawn[1]) < 1.9:
                continue
        items.append({"key": key, "pos": [round(p[0], 2), round(p[1], 2)], "color_idx": i % max(1, mod_colors)})


def build_all():
    levels = []

    def emit(num, world, name, tag, duration, arena_w, arena_h, spawn, targets, items,
             powerups, traps, walls=None, bombs=None, streak_hint=0):
        hw, hh = arena_w * 0.5 - 1.15, arena_h * 0.5 - 1.15
        for it in items:
            it["pos"][0] = round(max(-hw, min(hw, it["pos"][0])), 2)
            it["pos"][1] = round(max(-hh, min(hh, it["pos"][1])), 2)
        for tr in traps:
            tr["pos"][0] = round(max(-hw, min(hw, tr["pos"][0])), 2)
            tr["pos"][1] = round(max(-hh, min(hh, tr["pos"][1])), 2)
        for bm in (bombs or []):
            bm["pos"][0] = round(max(-hw, min(hw, bm["pos"][0])), 2)
            bm["pos"][1] = round(max(-hh, min(hh, bm["pos"][1])), 2)

        counts = {}
        for it in items:
            counts[it["key"]] = counts.get(it["key"], 0) + 1
        for k, need in targets.items():
            assert counts.get(k, 0) >= need, f"Lv.{num} {name}: not enough {k}: {counts.get(k, 0)} < {need}"

        max_tier = max(int(CATALOG[k]["tier"]) for k in targets)
        xp_need = {1: 0, 2: 95, 3: 245, 4: 475, 5: 810}[max_tier]
        xp_avail = sum(int(CATALOG[it["key"]]["xp"]) for it in items if int(CATALOG[it["key"]]["tier"]) < max_tier)
        assert xp_avail >= xp_need * 1.08, f"Lv.{num} {name}: XP {xp_avail} < req {xp_need}"

        data = {
            "level": num,
            "world": world,
            "formation_name": name,
            "difficulty_tag": tag,
            "duration": duration,
            "arena": [arena_w, arena_h],
            "spawn": spawn,
            "max_target_tier": max_tier,
            "streak_hint": streak_hint,
            "targets": targets,
            "items": items,
            "powerups": powerups,
            "traps": traps,
            "walls": walls or [],
            "bombs": bombs or [],
        }
        with open(os.path.join(OUT_DIR, f"level_{num:03d}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        levels.append((num, world, name, tag, duration, len(items), len(traps), len(walls or []), len(bombs or []), xp_avail, xp_need))

    # =========================================================================
    # WORLD 1: SUGAR RUSH BAKERY (Lv.1 - Lv.20)
    # =========================================================================

    # Lv.1 — Candy Heart (Tutorial)
    it = []
    add_items(it, "w1_sprinkle", pt_heart(32, 6.4, 6.4, 0, -0.4), 3, [0, 0])
    add_items(it, "w1_strawberry", pt_heart(24, 4.7, 4.7, 0, -0.4), 1, [0, 0])
    add_items(it, "w1_macaron", pt_heart(12, 3.2, 3.2, 0, -0.4), 3, [0, 0])
    add_items(it, "w1_donut", [[-4.8, -5.2], [4.8, -5.2], [-4.8, 4.8], [4.8, 4.8], [0.0, -6.6]], 2)
    emit(1, 1, "Candy Heart", "TUTORIAL", 45, 16, 20, [0, 0.2],
         {"w1_macaron": 6, "w1_donut": 4}, it, [{"kind": "magnet", "pos": [0, 4.2]}], [])

    # Lv.2 — Twin Spiral
    it = []
    add_items(it, "w1_sprinkle", pt_spiral(28, 1.8, 6.5, 1.6, 0.0), 3, [0, 0])
    add_items(it, "w1_gummy_bear", pt_spiral(24, 1.8, 6.5, 1.6, math.pi), 3, [0, 0])
    add_items(it, "w1_boba_tea", pt_ring(0, 0, 4.2, 5.2, 10, 0.2), 1)
    add_items(it, "w1_donut", pt_ring(0, 0, 5.8, 7.2, 6, 0.5), 2)
    emit(2, 1, "Twin Spiral", "EASY", 45, 17, 21, [0, 0],
         {"w1_boba_tea": 7, "w1_donut": 5}, it, [{"kind": "magnet", "pos": [0, -3.2]}], [])

    # Lv.3 — Smiley Face (Wide outer rim donuts for crisp 26s pacing)
    it = []
    add_items(it, "w1_sprinkle", pt_ring(0, 0, 6.4, 7.2, 32), 3)
    add_items(it, "w1_strawberry", pt_arc(0, 0.4, 4.2, 4.0, 0.25, math.pi - 0.25, 20), 1)
    add_items(it, "w1_macaron", pt_ring(-2.8, -2.8, 1.3, 1.3, 6) + pt_ring(2.8, -2.8, 1.3, 1.3, 6), 3)
    add_items(it, "w1_gummy_bear", pt_line(0, -1.6, 0, 1.0, 6), 3)
    add_items(it, "w1_donut", [[-6.8, -7.6], [6.8, -7.6], [-6.8, 7.6], [6.8, 7.6], [0, -8.4], [0, 8.4]], 2)
    emit(3, 1, "Smiley Face", "NORMAL", 24, 17, 21, [0, 2.5],
         {"w1_macaron": 9, "w1_donut": 6}, it, [], [])

    # Lv.4 — Ice-Magnet Cross
    it = []
    add_items(it, "w1_sprinkle", pt_line(-6.8, 0, 6.8, 0, 16) + pt_line(0, -7.8, 0, 7.8, 18), 3, [0, 0])
    add_items(it, "w1_gummy_bear", pt_grid(-4.0, -4.5, 3, 3, 1.1, 1.1) + pt_grid(4.0, 4.5, 3, 3, 1.1, 1.1), 3)
    add_items(it, "w1_strawberry", pt_grid(4.0, -4.5, 3, 3, 1.1, 1.1) + pt_grid(-4.0, 4.5, 3, 3, 1.1, 1.1), 1)
    add_items(it, "w1_boba_tea", pt_ring(0, 0, 4.8, 5.4, 10, 0.3), 1)
    add_items(it, "w1_donut", [[-6.0, -7.2], [6.0, -7.2], [-6.0, 7.2], [6.0, 7.2], [0, -7.8], [0, 7.8]], 2)
    emit(4, 1, "Ice-Magnet Cross", "EASY", 44, 18, 22, [0, 0],
         {"w1_boba_tea": 8, "w1_donut": 6}, it,
         [{"kind": "ice", "pos": [-2.6, 0]}, {"kind": "magnet", "pos": [2.6, 0]}], [])

    # Lv.5 — HARD · Hourglass Pinch (Scheme A tightened XP: ~335/245 = 1.37x!)
    it = []
    add_items(it, "w1_sprinkle", pt_line(-7.2, 8.6, 7.2, 8.6, 8) + pt_line(-7.2, -8.6, 7.2, -8.6, 8), 3)
    add_items(it, "w1_strawberry", pt_line(-6.6, 7.2, -1.8, 1.8, 4) + pt_line(6.6, 7.2, 1.8, 1.8, 4), 1, [0, 4.2])
    add_items(it, "w1_gummy_bear", pt_line(-6.6, -7.2, -1.8, -1.8, 4) + pt_line(6.6, -7.2, 1.8, -1.8, 4), 3)
    add_items(it, "w1_macaron", pt_line(-6.8, 6.8, 6.8, 6.8, 5) + pt_line(-5.4, -5.0, 5.4, -5.0, 4), 3)
    add_items(it, "w1_donut", [[-7.6, -9.2], [7.6, -9.2], [0, -9.6], [-7.2, 0.0], [7.2, 0.0], [-7.6, 9.2], [7.6, 9.2]], 2)
    traps = [{"pos": [-2.2, 0.0]}, {"pos": [2.2, 0.0]}, {"pos": [0.0, -2.5]}, {"pos": [0.0, 2.0]}]
    emit(5, 1, "Hourglass Pinch", "HARD", 31, 20, 24, [0, 4.2],
         {"w1_macaron": 8, "w1_donut": 7}, it,
         [{"kind": "ice", "pos": [-5.8, 2.2]}], traps, streak_hint=5)

    # Lv.6 — Starburst Sun
    it = []
    add_items(it, "w1_sprinkle", pt_star(5, 7.6, 3.4, 7), 3, [0, 0])
    add_items(it, "w1_strawberry", pt_ring(0, 0, 2.8, 2.8, 16), 1)
    add_items(it, "w1_macaron", pt_ring(0, 0, 4.8, 5.2, 12, 0.25), 3)
    add_items(it, "w1_donut", pt_ring(0, 0, 6.6, 7.6, 8, 0.0), 2)
    add_items(it, "w1_cake", pt_ring(0, 0, 8.2, 9.8, 5, -math.pi / 2.0), 1)
    emit(6, 1, "Starburst Sun", "NORMAL", 26, 20, 24, [0, 0],
         {"w1_donut": 7, "w1_cake": 5}, it,
         [{"kind": "magnet", "pos": [0, 3.6]}], [])

    # Lv.7 — Bakery Islands
    it = []
    centers = [(-5.4, -6.2), (0, -6.2), (5.4, -6.2), (-5.4, 0), (0, 0), (5.4, 0), (-5.4, 6.2), (0, 6.2), (5.4, 6.2)]
    for idx, (cx, cz) in enumerate(centers):
        if idx == 4:
            continue
        add_items(it, "w1_sprinkle" if idx % 2 == 0 else "w1_gummy_bear", pt_ring(cx, cz, 1.7, 1.7, 8), 3)
        add_items(it, "w1_boba_tea" if idx % 2 == 0 else "w1_macaron", pt_ring(cx, cz, 0.85, 0.85, 3), 3)
        if idx in (0, 2, 6, 8):
            add_items(it, "w1_cake", [[cx, cz]], 1)
        else:
            add_items(it, "w1_donut", [[cx, cz], [cx, cz + 1.1]], 2)
    emit(7, 1, "Bakery Islands", "EASY", 45, 20, 24, [0, 0],
         {"w1_boba_tea": 8, "w1_donut": 6, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [-2.6, 0]}, {"kind": "ice", "pos": [2.6, 0]}], [])

    # Lv.8 — Cake Citadel
    it = []
    add_items(it, "w1_sprinkle", pt_rect_outline(0, 0, 7.6, 8.8, 10), 3)
    add_items(it, "w1_strawberry", pt_rect_outline(0, 0, 5.8, 6.8, 8), 1)
    add_items(it, "w1_macaron", pt_rect_outline(0, 0, 4.0, 4.8, 6), 3)
    add_items(it, "w1_donut", pt_rect_outline(0, 0, 6.8, 7.8, 3), 2)
    add_items(it, "w1_cake", [[-7.6, -9.2], [7.6, -9.2], [-7.6, 9.2], [7.6, 9.2]], 1)
    emit(8, 1, "Cake Citadel", "NORMAL", 28, 20, 24, [0, 8.0],
         {"w1_macaron": 10, "w1_donut": 7, "w1_cake": 4}, it,
         [{"kind": "ice", "pos": [-5.2, 0]}], [])

    # Lv.9 — HARD · Gum Bow-Tie (Scheme A tightened XP: ~640/475 = 1.35x!)
    it = []
    add_items(it, "w1_sprinkle", pt_line(-8.2, -7.8, -8.2, 7.8, 11) + pt_line(8.2, -7.8, 8.2, 7.8, 11), 3)
    add_items(it, "w1_gummy_bear", pt_line(-7.2, -6.8, -1.8, -1.6, 5) + pt_line(-7.2, 6.8, -1.8, 1.6, 5) +
              pt_line(7.2, -6.8, 1.8, -1.6, 5) + pt_line(7.2, 6.8, 1.8, 1.6, 5), 3)
    add_items(it, "w1_boba_tea", pt_grid(-5.6, 0, 2, 3, 1.6, 3.0) + pt_grid(5.6, 0, 2, 3, 1.6, 3.0), 1)
    add_items(it, "w1_donut", [[-7.6, -4.6], [-7.6, 0], [-7.6, 4.6], [7.6, -4.6], [7.6, 0], [7.6, 4.6], [0, -7.2], [0, 7.2]], 2)
    add_items(it, "w1_cake", [[-8.4, -9.2], [-8.4, 9.2], [8.4, -9.2], [8.4, 9.2], [0, -9.8]], 1)
    traps = [{"pos": [-2.8, -1.8]}, {"pos": [-2.8, 1.8]}, {"pos": [2.8, -1.8]}, {"pos": [2.8, 1.8]}, {"pos": [0.0, -4.8]}, {"pos": [0.0, 4.8]}]
    emit(9, 1, "Gum Bow-Tie", "HARD", 34, 21, 25, [0, 0],
         {"w1_donut": 8, "w1_cake": 5}, it,
         [{"kind": "ice", "pos": [0, 2.6]}], traps, streak_hint=9)

    # Lv.10 — SUPER HARD CLIFF · Bakery Plaza!
    # Large 30x34 ASMR decompression showcase: tightly packed, razor-neat regional candy blocks!
    # Screen 1 immediately showcases the dense 8x4 Sprinkle Carpet + Twin 3x3 Strawberry/Gummy blocks + Magnet!
    # Outer wings: 3x3 Macaron (W), 3x3 Rainbow-Cream Boba (E), 4x2 Donut Plaza (C), 3-Cake Terrace, 4-Grand-Cake Row!
    # Scheme A XP below Tier 5: 32*5 + 18*6 + 18*7 + 9*14 + 9*13 + 8*26 + 3*46 = 983 / 810 = 1.21x!
    it = []
    # Zone A (Immediate Spawn Carpet): Razor-neat 8x4 Sprinkle Carpet right in front of hole!
    add_items(it, "w1_sprinkle", pt_grid(0.0, 8.6, 8, 4, 0.72, 0.72), 3)
    # Zone B (Flanking Berry & Gummy Blocks): Tight 3x3 blocks visible on Frame 1 + 3x3 outer wing pairs
    add_items(it, "w1_strawberry", pt_grid(-3.2, 4.8, 3, 3, 0.88, 0.88) + pt_grid(-9.2, 8.6, 3, 3, 0.92, 0.92), 1)
    add_items(it, "w1_gummy_bear", pt_grid(3.2, 4.8, 3, 3, 0.90, 0.90) + pt_grid(9.2, 8.6, 3, 3, 0.94, 0.94), 3)
    # Zone C (Mid Wings): Tight 3x3 Macaron (West) & 3x3 Rainbow-Cream Boba Sundae (East)
    add_items(it, "w1_macaron", pt_grid(-8.2, 0.6, 3, 3, 1.35, 1.35), 3)
    add_items(it, "w1_boba_tea", pt_grid(8.2, 0.6, 3, 3, 1.35, 1.35), 1)
    # Zone D (Center Plaza): Razor-neat 4x2 Donut Precision Grid
    add_items(it, "w1_donut", pt_grid(0.0, -2.6, 4, 2, 2.15, 2.15), 2)
    # Zone E (Upper Terrace): 3 Symmetrical Tier-4 Cakes
    add_items(it, "w1_cake", [[-8.6, -8.4], [0.0, -8.4], [8.6, -8.4]], 1)
    # Zone F (Far-North Vault): 4 Majestic Tier-5 Grand Cakes in a crisp row
    add_items(it, "w1_grand_cake", [[-9.6, -13.6], [-3.2, -13.6], [3.2, -13.6], [9.6, -13.6]], 1)
    traps = [
        {"pos": [-4.4, -5.6]}, {"pos": [4.4, -5.6]},
        {"pos": [-4.8, -11.0]}, {"pos": [4.8, -11.0]},
    ]
    emit(10, 1, "Bakery Plaza", "SUPER_HARD", 23, 30, 34, [0.0, 12.2],
         {"w1_donut": 8, "w1_cake": 3, "w1_grand_cake": 4}, it,
         [{"kind": "magnet", "pos": [0.0, 5.2]}, {"kind": "ice", "pos": [0.0, 1.4]}], traps, streak_hint=49)

    # Lv.11 — Candy S-Wave
    it = []
    add_items(it, "w1_sprinkle", pt_wave(36, -7.5, 7.5, -4.5, 2.2, 1.5) + pt_wave(36, -7.5, 7.5, 4.5, 2.2, 1.5), 3)
    add_items(it, "w1_gummy_bear", pt_wave(26, -7.5, 7.5, 0.0, 2.4, 1.5), 3, [0, 0])
    add_items(it, "w1_macaron", pt_wave(14, -7.0, 7.0, -2.2, 1.6, 1.5), 3)
    add_items(it, "w1_donut", pt_wave(8, -7.0, 7.0, 2.2, 1.6, 1.5), 2)
    add_items(it, "w1_cake", [[-7.2, -7.5], [7.2, -7.5], [0, 8.0]], 1)
    emit(11, 1, "Candy S-Wave", "EASY", 45, 20, 24, [0, 0],
         {"w1_macaron": 10, "w1_donut": 6, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [-3.0, 0]}], [])

    # Lv.12 — Diamond Pavilion
    it = []
    add_items(it, "w1_sprinkle", pt_diamond(0, 0, 8.2, 9.6, 10), 3)
    add_items(it, "w1_strawberry", pt_diamond(0, 0, 6.0, 7.2, 8), 1)
    add_items(it, "w1_boba_tea", pt_diamond(0, 0, 3.8, 4.6, 5), 1)
    add_items(it, "w1_donut", pt_diamond(0, 0, 7.2, 8.4, 3), 2)
    add_items(it, "w1_cake", [[0, -9.2], [0, 9.2], [-7.8, 0], [7.8, 0]], 1)
    emit(12, 1, "Diamond Pavilion", "EASY", 45, 20, 24, [0, 0],
         {"w1_strawberry": 16, "w1_donut": 7, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [0, 2.8]}], [])

    # Lv.13 — Butterfly Wings
    it = []
    add_items(it, "w1_sprinkle", pt_ring(-4.8, -3.6, 3.4, 3.6, 16) + pt_ring(4.8, -3.6, 3.4, 3.6, 16), 3)
    add_items(it, "w1_gummy_bear", pt_ring(-4.2, 3.8, 2.8, 3.0, 14) + pt_ring(4.2, 3.8, 2.8, 3.0, 14), 3)
    add_items(it, "w1_macaron", pt_line(0, -7.5, 0, 7.5, 11), 3, [0, 0])
    add_items(it, "w1_boba_tea", [[-4.8, -3.6], [4.8, -3.6], [-4.2, 3.8], [4.2, 3.8], [-2.5, -1.5], [2.5, -1.5], [-2.5, 1.5], [2.5, 1.5]], 1)
    add_items(it, "w1_donut", [[-6.8, -5.8], [6.8, -5.8], [-6.2, 5.8], [6.2, 5.8], [-4.8, -0.2], [4.8, -0.2], [0, -7.8]], 2)
    add_items(it, "w1_cake", [[-7.6, -7.6], [7.6, -7.6], [0, 8.2], [0, -4.2]], 1)
    emit(13, 1, "Butterfly Wings", "NORMAL", 28, 20, 24, [0, 0],
         {"w1_boba_tea": 7, "w1_donut": 6, "w1_cake": 3}, it,
         [{"kind": "ice", "pos": [0, 3.8]}], [{"pos": [-2.6, 0]}, {"pos": [2.6, 0]}])

    # Lv.14 — Clover Garden
    it = []
    for cx, cz in [(-4.4, -4.8), (4.4, -4.8), (-4.4, 4.8), (4.4, 4.8)]:
        add_items(it, "w1_sprinkle", pt_ring(cx, cz, 3.0, 3.0, 14), 3)
        add_items(it, "w1_strawberry", pt_ring(cx, cz, 1.9, 1.9, 9), 1)
        add_items(it, "w1_macaron", pt_ring(cx, cz, 1.0, 1.0, 4), 3)
        add_items(it, "w1_donut", [[cx, cz], [cx * 1.45, cz * 1.45]], 2)
    add_items(it, "w1_cake", [[0, -8.5], [0, 8.5], [-7.8, 0], [7.8, 0]], 1)
    emit(14, 1, "Clover Garden", "EASY", 45, 20, 24, [0, 0],
         {"w1_macaron": 12, "w1_donut": 7, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [0, -2.5]}, {"kind": "ice", "pos": [0, 2.5]}],
         [{"pos": [-2.2, -2.2]}, {"pos": [2.2, 2.2]}])

    # Lv.15 — HARD · Pinwheel Blades (Scheme A tightened XP: ~640/475 = 1.35x!)
    it = []
    for arm in range(4):
        ang = arm * math.pi / 2.0
        add_items(it, "w1_sprinkle", pt_spiral(7, 2.0, 8.6, 0.35, ang), 3, [0, 0])
        add_items(it, "w1_gummy_bear", pt_spiral(5, 2.4, 8.4, 0.35, ang + 0.35), 3, [0, 0])
        add_items(it, "w1_boba_tea", pt_spiral(3, 3.4, 7.6, 0.35, ang + 0.18), 1)
        add_items(it, "w1_donut", pt_spiral(2, 4.6, 8.4, 0.35, ang + 0.55), 2)
    add_items(it, "w1_cake", pt_ring(0, 0, 8.8, 9.8, 5, 0.4), 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 4.6, 5.0, 6, 0.25)]
    emit(15, 1, "Pinwheel Blades", "HARD", 29, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 5}, it,
         [{"kind": "ice", "pos": [0, -3.0]}], traps, streak_hint=15)

    # Lv.16 — Hex Honeycomb
    it = []
    add_items(it, "w1_sprinkle", pt_ring(0, 0, 8.4, 9.2, 30), 3)
    add_items(it, "w1_strawberry", pt_ring(0, 0, 6.4, 7.0, 20), 1)
    add_items(it, "w1_macaron", pt_ring(0, 0, 4.4, 4.8, 16), 3)
    add_items(it, "w1_boba_tea", pt_ring(0, 0, 2.6, 3.0, 10), 1)
    add_items(it, "w1_donut", pt_ring(0, 0, 5.6, 6.2, 10, 0.3), 2)
    add_items(it, "w1_cake", pt_ring(0, 0, 7.8, 8.6, 6, 0.0), 1)
    add_items(it, "w1_grand_cake", [[0, -10.2], [0, 10.2]], 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 5.0, 5.5, 6, 0.52)]
    emit(16, 1, "Hex Honeycomb", "NORMAL", 33, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 4, "w1_grand_cake": 1}, it,
         [{"kind": "ice", "pos": [-3.4, 0]}, {"kind": "magnet", "pos": [0, 4.0]}], traps)

    # Lv.17 — Sweet Pyramid
    it = []
    add_items(it, "w1_sprinkle", pt_grid(0, 9.4, 10, 3, 1.8, 1.1), 3, [0, 9.4])
    add_items(it, "w1_strawberry", pt_grid(0, 6.0, 9, 2, 1.9, 1.3), 1)
    add_items(it, "w1_gummy_bear", pt_grid(0, 3.2, 8, 2, 1.9, 1.3), 3)
    add_items(it, "w1_macaron", pt_grid(0, 0.2, 7, 2, 2.1, 1.5), 3)
    add_items(it, "w1_boba_tea", pt_grid(0, -2.6, 6, 2, 2.2, 1.5), 1)
    add_items(it, "w1_donut", pt_grid(0, -5.4, 5, 2, 2.6, 1.8), 2)
    add_items(it, "w1_cake", [[-5.6, -8.2], [0, -8.2], [5.6, -8.2], [-2.8, -8.2], [2.8, -8.2]], 1)
    add_items(it, "w1_grand_cake", [[-3.2, -10.6], [3.2, -10.6]], 1)
    traps = [{"pos": [-5.2, 1.6]}, {"pos": [0, 1.6]}, {"pos": [5.2, 1.6]}, {"pos": [-3.5, -4.0]}, {"pos": [3.5, -4.0]}, {"pos": [0, -6.8]}]
    emit(17, 1, "Sweet Pyramid", "NORMAL", 31, 22, 26, [0, 10.6],
         {"w1_boba_tea": 9, "w1_cake": 4, "w1_grand_cake": 2}, it,
         [{"kind": "ice", "pos": [-7.0, 4.5]}, {"kind": "magnet", "pos": [7.0, -1.0]}], traps)

    # Lv.18 — Infinity Track
    it = []
    add_items(it, "w1_sprinkle", pt_figure8(44, 8.2, 8.8), 3, [0, 0])
    add_items(it, "w1_gummy_bear", pt_figure8(32, 6.6, 7.0), 3, [0, 0])
    add_items(it, "w1_macaron", pt_figure8(20, 5.0, 5.2), 3, [0, 0])
    add_items(it, "w1_donut", pt_ring(-4.8, 0, 2.6, 3.8, 5) + pt_ring(4.8, 0, 2.6, 3.8, 5), 2)
    add_items(it, "w1_cake", [[-8.0, -7.8], [8.0, -7.8], [-8.0, 7.8], [8.0, 7.8]], 1)
    add_items(it, "w1_grand_cake", [[0, -9.8], [0, 9.8]], 1)
    traps = [{"pos": [0, -2.5]}, {"pos": [0, 2.5]}, {"pos": [-4.8, 0]}, {"pos": [4.8, 0]}, {"pos": [-4.8, -5.8]}, {"pos": [4.8, 5.8]}, {"pos": [0, -6.2]}]
    emit(18, 1, "Infinity Track", "NORMAL", 36, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 4, "w1_grand_cake": 2}, it,
         [{"kind": "ice", "pos": [-7.5, 0]}, {"kind": "magnet", "pos": [7.5, 0]}], traps)

    # Lv.19 — HARD · Fortress Corners (Scheme A tightened XP: ~1080/810 = 1.33x!)
    it = []
    add_items(it, "w1_sprinkle", pt_ring(0, 0, 2.8, 3.0, 18), 3)
    add_items(it, "w1_strawberry", pt_rect_outline(0, 0, 4.6, 5.2, 5), 1)
    add_items(it, "w1_boba_tea", pt_rect_outline(0, 0, 6.8, 7.6, 4), 1)
    add_items(it, "w1_macaron", pt_ring(0, 0, 3.8, 4.2, 10), 3)
    add_items(it, "w1_donut", [[-8.4, -5.0], [8.4, -5.0], [-8.4, 5.0], [8.4, 5.0], [-4.5, -9.8], [4.5, -9.8], [-4.5, 9.8], [4.5, 9.8]], 2)
    add_items(it, "w1_cake", [[-8.8, -10.2], [8.8, -10.2], [-8.8, 10.2], [8.8, 10.2], [0, -10.6], [0, 10.6]], 1)
    add_items(it, "w1_grand_cake", [[-9.2, 0], [9.2, 0]], 1)
    traps = [{"pos": p} for p in pt_rect_outline(0, 0, 6.0, 6.6, 3)]
    emit(19, 1, "Fortress Corners", "HARD", 34, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 5, "w1_grand_cake": 2}, it,
         [{"kind": "ice", "pos": [0, -2.6]}], traps, streak_hint=19)

    # Lv.20 — MEGA_BOSS (30x34 Epic Stage!) · Grand Bakery Palace! (Scheme A XP ~975/810 = 1.20x!)
    it = []
    # Central royal banquet growth court (Lv.1 -> Lv.3)
    add_items(it, "w1_sprinkle", pt_ring(0, 0, 3.2, 3.2, 18), 3)
    add_items(it, "w1_strawberry", pt_ring(0, 0, 5.2, 5.6, 16), 1)
    add_items(it, "w1_gummy_bear", pt_line(-9.5, 0, -4.5, 0, 5) + pt_line(4.5, 0, 9.5, 0, 5), 3)
    add_items(it, "w1_macaron", pt_ring(0, 0, 7.6, 8.6, 12), 3)
    add_items(it, "w1_boba_tea", [[-7.2, -6.8], [7.2, -6.8], [-7.2, 6.8], [7.2, 6.8], [0, -9.2], [0, 9.2], [-10.2, 0], [10.2, 0]], 1)
    # Four palace wing pastries (Lv.3 -> Lv.4)
    add_items(it, "w1_donut", [[-10.6, -6.2], [10.6, -6.2], [-10.6, 6.2], [10.6, 6.2], [-5.4, -11.8], [5.4, -11.8], [-5.4, 11.8], [5.4, 11.8]], 2)
    add_items(it, "w1_cake", [[-11.8, -10.5], [11.8, -10.5], [-11.8, 10.5], [11.8, 10.5], [0, -13.6], [0, 13.6]], 1)
    # 4 Far-Corner Royal Grand Cakes (Lv.5 Mega Bosses!)
    add_items(it, "w1_grand_cake", [[-12.6, -14.2], [12.6, -14.2], [-12.6, 14.2], [12.6, 14.2]], 1)
    traps = [
        {"pos": [-5.2, -5.2]}, {"pos": [5.2, -5.2]}, {"pos": [-5.2, 5.2]}, {"pos": [5.2, 5.2]},
        {"pos": [0, -7.8]}, {"pos": [0, 7.8]}, {"pos": [-9.2, 0]}, {"pos": [9.2, 0]},
        {"pos": [-9.6, -11.8]}, {"pos": [9.6, -11.8]}, {"pos": [-9.6, 11.8]}, {"pos": [9.6, 11.8]},
    ]
    emit(20, 1, "Grand Bakery Palace", "MEGA_BOSS", 49, 30, 34, [0, 0],
         {"w1_donut": 7, "w1_cake": 5, "w1_grand_cake": 4}, it,
         [{"kind": "ice", "pos": [0, -3.4]}, {"kind": "magnet", "pos": [0, 3.4]}], traps, streak_hint=99)

    # =========================================================================
    # WORLD 2: GACHA TOYBOX (Lv.21 - Lv.30) — Rubber Band Walls!
    # =========================================================================

    # Lv.21 — Toybox Mosaic
    it = []
    add_items(it, "w2_block", pt_grid(0, 0, 9, 7, 1.7, 1.8), 4, [0, 0])
    add_items(it, "w2_duck", pt_ring(0, 0, 5.2, 6.0, 14), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 3.2, 3.8, 8), 3)
    add_items(it, "w2_arcade", [[-6.5, -7.2], [6.5, -7.2], [-6.5, 7.2], [6.5, 7.2], [0, -7.8], [0, 7.8]], 1)
    emit(21, 2, "Toybox Mosaic", "EASY", 45, 18, 22, [0, 0],
         {"w2_duck": 10, "w2_arcade": 5}, it, [{"kind": "magnet", "pos": [0, 3.2]}], [])

    # Lv.22 — Duck Pond Ring
    it = []
    add_items(it, "w2_block", pt_ring(0, 0, 7.2, 8.2, 36) + pt_ring(0, 0, 5.6, 6.4, 28), 4)
    add_items(it, "w2_duck", pt_ring(0, 0, 4.0, 4.6, 16), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 2.4, 2.8, 10), 3)
    add_items(it, "w2_arcade", pt_ring(0, 0, 6.6, 7.6, 8, 0.4), 1)
    add_items(it, "w2_unicorn", [[-7.0, -8.0], [7.0, -8.0], [0, 8.5]], 1)
    emit(22, 2, "Duck Pond Ring", "EASY", 45, 20, 24, [0, 0],
         {"w2_figurine": 8, "w2_arcade": 6, "w2_unicorn": 3}, it,
         [{"kind": "ice", "pos": [-3.0, 0]}, {"kind": "magnet", "pos": [3.0, 0]}], [])

    # Lv.23 — Arcade Alley
    it = []
    add_items(it, "w2_block", pt_grid(-5.6, 0, 3, 10, 1.3, 1.7) + pt_grid(5.6, 0, 3, 10, 1.3, 1.7), 4)
    add_items(it, "w2_duck", pt_line(-2.2, -8.0, -2.2, 8.0, 9) + pt_line(2.2, -8.0, 2.2, 8.0, 9), 1, [0, 0])
    add_items(it, "w2_figurine", pt_line(0, -8.5, 0, 8.5, 9), 3, [0, 0])
    add_items(it, "w2_arcade", pt_line(-7.8, -6.5, -7.8, 6.5, 5) + pt_line(7.8, -6.5, 7.8, 6.5, 5), 1)
    add_items(it, "w2_unicorn", [[0, -9.4], [-4.5, -9.4], [4.5, -9.4], [0, 9.4]], 1)
    emit(23, 2, "Arcade Alley", "NORMAL", 31, 20, 24, [0, 0],
         {"w2_arcade": 8, "w2_unicorn": 4}, it,
         [{"kind": "magnet", "pos": [0, 4.0]}], [{"pos": [-2.2, -3.0]}, {"pos": [2.2, 3.0]}])

    # Lv.24 — Unicorn Star
    it = []
    add_items(it, "w2_block", pt_star(5, 8.0, 3.6, 8), 4, [0, 0])
    add_items(it, "w2_duck", pt_ring(0, 0, 3.2, 3.2, 14), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 5.4, 5.8, 12, 0.3), 3)
    add_items(it, "w2_arcade", pt_ring(0, 0, 6.8, 7.6, 8, 0.0), 1)
    add_items(it, "w2_unicorn", pt_ring(0, 0, 8.4, 9.8, 5, -math.pi / 2.0), 1)
    emit(24, 2, "Unicorn Star", "NORMAL", 26, 20, 24, [0, 0],
         {"w2_figurine": 10, "w2_arcade": 7, "w2_unicorn": 5}, it,
         [{"kind": "ice", "pos": [0, -3.5]}],
         [{"pos": [-3.4, -2.0]}, {"pos": [3.4, 2.0]}])

    # Lv.25 — HARD · Gacha Spiral (Scheme A tightened XP: ~640/475 = 1.35x!)
    it = []
    add_items(it, "w2_block", pt_spiral(26, 2.0, 9.0, 2.0, 0.0), 4, [0, 0])
    add_items(it, "w2_duck", pt_spiral(11, 2.8, 8.2, 1.6, 0.8), 1)
    add_items(it, "w2_figurine", pt_spiral(8, 3.2, 8.0, 1.5, 2.4), 3)
    add_items(it, "w2_arcade", pt_ring(0, 0, 6.8, 7.6, 8, 0.2), 1)
    add_items(it, "w2_unicorn", pt_ring(0, 0, 9.0, 10.0, 5, 0.5), 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 4.6, 5.2, 6, 0.3)]
    emit(25, 2, "Gacha Spiral", "HARD", 29, 22, 26, [0, 0],
         {"w2_arcade": 8, "w2_unicorn": 5}, it,
         [{"kind": "ice", "pos": [-3.0, -3.0]}], traps, streak_hint=25)

    # Lv.26 — Rubber S-Slalom
    it = []
    add_items(it, "w2_block", pt_grid(0, 8.5, 9, 3, 1.8, 1.3) + pt_grid(0, 0, 9, 2, 1.8, 1.4) + pt_grid(0, -8.5, 9, 2, 1.8, 1.4), 4, [0, 8.5])
    add_items(it, "w2_duck", pt_line(-8.2, 4.2, 8.2, 4.2, 10) + pt_line(-8.2, -4.2, 8.2, -4.2, 10), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 5.2, 5.2, 12), 3)
    add_items(it, "w2_arcade", [[-7.5, -1.8], [0, -1.8], [7.5, -1.8], [-7.5, -6.5], [0, -6.5], [7.5, -6.5], [-7.5, 2.0], [7.5, 2.0]], 1)
    add_items(it, "w2_unicorn", [[-7.2, -9.8], [0, -10.0], [7.2, -9.8], [0, 2.5]], 1)
    add_items(it, "w2_golden_gacha", [[0, -10.8]], 1)
    walls = [{"pos": [-4.2, 4.2], "rot_deg": 0.0}, {"pos": [4.2, -0.5], "rot_deg": 0.0}, {"pos": [-4.2, -5.2], "rot_deg": 0.0}]
    traps = [{"pos": [6.5, 4.2]}, {"pos": [-6.5, -0.5]}, {"pos": [6.5, -5.2]}]
    emit(26, 2, "Rubber S-Slalom", "NORMAL", 34, 22, 26, [0, 9.5],
         {"w2_arcade": 7, "w2_unicorn": 3, "w2_golden_gacha": 1}, it,
         [{"kind": "magnet", "pos": [5.5, 7.0]}, {"kind": "ice", "pos": [-5.5, -2.5]}], traps, walls)

    # Lv.27 — Twin Toy Vaults (Wide 7.2m center gate + 5.2m outer flanks!)
    it = []
    add_items(it, "w2_block", pt_grid(0, 7.8, 10, 3, 1.9, 1.3) + pt_grid(0, 1.4, 6, 3, 1.9, 1.4), 4, [0, 8.8])
    add_items(it, "w2_duck", pt_ring(-6.6, -6.4, 3.2, 3.4, 10) + pt_ring(6.6, -6.4, 3.2, 3.4, 10), 1)
    add_items(it, "w2_figurine", pt_line(-9.0, 3.2, 9.0, 3.2, 12), 3)
    add_items(it, "w2_arcade", [[-7.2, -3.2], [-7.2, -9.2], [7.2, -3.2], [7.2, -9.2], [-2.8, -5.2], [2.8, -5.2], [-9.0, 0.4], [9.0, 0.4]], 1)
    add_items(it, "w2_unicorn", [[-9.2, -6.4], [9.2, -6.4], [-3.8, -10.2], [3.8, -10.2]], 1)
    add_items(it, "w2_golden_gacha", [[-6.6, -6.6], [6.6, -6.6]], 1)
    walls = [{"pos": [-5.2, -0.6], "rot_deg": 0.0}, {"pos": [5.2, -0.6], "rot_deg": 0.0}, {"pos": [0.0, -7.8], "rot_deg": 90.0}]
    traps = [{"pos": [-2.2, -0.6]}, {"pos": [2.2, -0.6]}, {"pos": [-6.6, -10.2]}, {"pos": [6.6, -10.2]}, {"pos": [0, 4.2]}]
    emit(27, 2, "Twin Toy Vaults", "NORMAL", 32, 24, 26, [0, 9.4],
         {"w2_arcade": 7, "w2_unicorn": 3, "w2_golden_gacha": 2}, it,
         [{"kind": "ice", "pos": [0, 1.2]}, {"kind": "magnet", "pos": [-6.4, 5.8]}], traps, walls)

    # Lv.28 — Cross-Wall Maze
    it = []
    add_items(it, "w2_block", pt_grid(-5.8, -6.2, 4, 4, 1.5, 1.5) + pt_grid(5.8, -6.2, 4, 4, 1.5, 1.5) +
              pt_grid(-5.8, 6.2, 4, 4, 1.5, 1.5) + pt_grid(5.8, 6.2, 4, 4, 1.5, 1.5), 4)
    add_items(it, "w2_duck", pt_ring(0, 0, 7.8, 8.8, 18), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 3.2, 3.6, 12), 3)
    add_items(it, "w2_arcade", [[-7.4, -2.8], [7.4, -2.8], [-7.4, 2.8], [7.4, 2.8], [-3.0, -8.6], [3.0, -8.6], [-3.0, 8.6], [3.0, 8.6]], 1)
    add_items(it, "w2_unicorn", [[-8.6, -9.0], [8.6, -9.0], [-8.6, 9.0], [8.6, 9.0]], 1)
    add_items(it, "w2_golden_gacha", [[0, -10.4], [0, 10.4]], 1)
    walls = [{"pos": [-5.2, 0.0], "rot_deg": 0.0}, {"pos": [5.2, 0.0], "rot_deg": 0.0},
             {"pos": [0.0, -6.2], "rot_deg": 90.0}, {"pos": [0.0, 6.2], "rot_deg": 90.0}]
    traps = [{"pos": [-2.4, -2.4]}, {"pos": [2.4, -2.4]}, {"pos": [-2.4, 2.4]}, {"pos": [2.4, 2.4]}, {"pos": [-8.2, 0]}, {"pos": [8.2, 0]}]
    emit(28, 2, "Cross-Wall Maze", "NORMAL", 42, 24, 26, [0, 0],
         {"w2_arcade": 7, "w2_unicorn": 4, "w2_golden_gacha": 2}, it,
         [{"kind": "ice", "pos": [0, -2.6]}, {"kind": "magnet", "pos": [0, 2.6]}], traps, walls)

    # Lv.29 — SUPER_HARD CLIFF · Golden Runway (Scheme A XP ~965/810 = 1.19x, wide navigable corridors!)
    it = []
    add_items(it, "w2_block", pt_grid(0, 9.2, 8, 2, 2.2, 1.3) + pt_line(-8.8, 5.5, -8.8, -5.5, 6) + pt_line(8.8, 5.5, 8.8, -5.5, 6), 4, [0, 9.8])
    add_items(it, "w2_duck", pt_line(-4.0, 5.8, -4.0, -4.2, 6) + pt_line(4.0, 5.8, 4.0, -4.2, 6), 1)
    add_items(it, "w2_figurine", pt_line(0, 5.4, 0, -4.2, 6) + [[-8.6, 2.2], [8.6, 2.2]], 3)
    add_items(it, "w2_arcade", [[-8.6, -2.4], [8.6, -2.4], [-3.4, -3.5], [3.4, -3.5], [-8.6, -7.2], [8.6, -7.2], [0, -8.2], [0, 1.2]], 1)
    add_items(it, "w2_unicorn", [[-9.2, -9.8], [9.2, -9.8], [-4.2, -9.2], [4.2, -9.2], [0, -3.0]], 1)
    add_items(it, "w2_golden_gacha", [[-7.2, -11.4], [0.0, -11.6], [7.2, -11.4]], 1)
    walls = [{"pos": [-5.4, 1.5], "rot_deg": 90.0}, {"pos": [5.4, 1.5], "rot_deg": 90.0}, {"pos": [0.0, -5.8], "rot_deg": 0.0}]
    traps = [
        {"pos": [-7.4, 3.0]}, {"pos": [7.4, 3.0]}, {"pos": [0, 3.0]},
        {"pos": [-7.4, -1.5]}, {"pos": [7.4, -1.5]}, {"pos": [0, -1.2]},
        {"pos": [-5.4, -7.2]}, {"pos": [5.4, -7.2]},
    ]
    emit(29, 2, "Golden Runway", "SUPER_HARD", 37, 24, 26, [0, 10.2],
         {"w2_arcade": 7, "w2_unicorn": 4, "w2_golden_gacha": 3}, it,
         [{"kind": "ice", "pos": [-6.4, 7.2]}], traps, walls, streak_hint=149)

    # Lv.30 — MEGA_BOSS (30x34 Epic Stage!) · Mega Gacha Vault! (Scheme A XP ~980/810 = 1.21x!)
    it = []
    add_items(it, "w2_block", pt_ring(0, 0, 3.2, 3.2, 16) + pt_line(-8.5, 0, -4.5, 0, 5) + pt_line(4.5, 0, 8.5, 0, 5), 4)
    add_items(it, "w2_duck", pt_ring(0, 0, 5.4, 6.2, 12), 1)
    add_items(it, "w2_figurine", [[-9.2, -5.2], [9.2, -5.2], [-9.2, 5.2], [9.2, 5.2], [0, -9.2], [0, 9.2], [-5.2, -8.8], [5.2, -8.8], [-5.2, 8.8], [5.2, 8.8]], 3)
    add_items(it, "w2_arcade", [[-11.0, -4.5], [11.0, -4.5], [-11.0, 4.5], [11.0, 4.5], [-4.5, -12.4], [4.5, -12.4], [-4.5, 12.4], [4.5, 12.4]], 1)
    add_items(it, "w2_unicorn", [[-12.0, -10.2], [12.0, -10.2], [-12.0, 10.2], [12.0, 10.2], [0, -13.8], [0, 13.8]], 1)
    add_items(it, "w2_golden_gacha", [[-12.6, -14.2], [12.6, -14.2], [-12.6, 14.2], [12.6, 14.2]], 1)
    walls = [
        {"pos": [-7.4, -7.8], "rot_deg": 0.0}, {"pos": [7.4, -7.8], "rot_deg": 0.0},
        {"pos": [-7.4, 7.8], "rot_deg": 0.0}, {"pos": [7.4, 7.8], "rot_deg": 0.0},
    ]
    traps = [
        {"pos": [0, -6.2]}, {"pos": [0, 6.2]}, {"pos": [-7.4, 0]}, {"pos": [7.4, 0]},
        {"pos": [-11.8, -7.8]}, {"pos": [11.8, -7.8]}, {"pos": [-11.8, 7.8]}, {"pos": [11.8, 7.8]},
        {"pos": [-8.8, -13.2]}, {"pos": [8.8, -13.2]},
    ]
    emit(30, 2, "Mega Gacha Vault", "MEGA_BOSS", 45, 30, 34, [0, 0],
         {"w2_arcade": 7, "w2_unicorn": 5, "w2_golden_gacha": 4}, it,
         [{"kind": "ice", "pos": [0, -3.4]}, {"kind": "magnet", "pos": [0, 3.4]}], traps, walls, streak_hint=199)

    # =========================================================================
    # WORLD 3: NEON BENTO STREET (Lv.31 - Lv.40) — Golden Cheese + Time Bombs!
    # =========================================================================

    # Lv.31 — Sushi Conveyor (Fresh W3 ASMR Intro, 0 bombs, 0 traps)
    it = []
    add_items(it, "w3_sushi", pt_line(-6.8, -6.0, 6.8, -6.0, 12) + pt_line(-6.8, 0.0, 6.8, 0.0, 12) + pt_line(-6.8, 6.0, 6.8, 6.0, 12), 1, [0, 0])
    add_items(it, "w3_takoyaki", pt_line(-6.2, -3.0, 6.2, -3.0, 10) + pt_line(-6.2, 3.0, 6.2, 3.0, 10), 1)
    add_items(it, "w3_ramen", pt_ring(0, 0, 4.8, 6.2, 12), 1)
    add_items(it, "w3_big_ramen", [[-6.5, -7.8], [6.5, -7.8], [-6.5, 7.8], [6.5, 7.8], [0, -8.2], [0, 8.2]], 1)
    emit(31, 3, "Sushi Conveyor", "EASY", 45, 18, 22, [0, 0],
         {"w3_ramen": 9, "w3_big_ramen": 5}, it, [{"kind": "magnet", "pos": [0, 3.2]}], [])

    # Lv.32 — Ramen Bowl Ring (Introduces Golden Melted Cheese traps!)
    it = []
    add_items(it, "w3_sushi", pt_ring(0, 0, 7.2, 8.2, 34), 1)
    add_items(it, "w3_takoyaki", pt_ring(0, 0, 5.4, 6.2, 24), 1)
    add_items(it, "w3_ramen", pt_ring(0, 0, 3.6, 4.2, 14), 1)
    add_items(it, "w3_big_ramen", pt_ring(0, 0, 6.4, 7.2, 8, 0.4), 1)
    add_items(it, "w3_bento", [[-7.4, -8.2], [7.4, -8.2], [0, 8.6]], 1)
    traps = [{"pos": [-2.8, 0.0]}, {"pos": [2.8, 0.0]}]
    emit(32, 3, "Ramen Bowl Ring", "EASY", 45, 20, 24, [0, 0],
         {"w3_ramen": 10, "w3_big_ramen": 6, "w3_bento": 3}, it,
         [{"kind": "ice", "pos": [0, -3.2]}, {"kind": "magnet", "pos": [0, 3.2]}], traps)

    # Lv.33 — Bento Grid (Introduces FIRST Time Bombs: 2 bombs!)
    it = []
    compartments = [(-5.4, -6.2), (5.4, -6.2), (-5.4, 0.0), (5.4, 0.0), (-5.4, 6.2), (5.4, 6.2)]
    for idx, (cx, cz) in enumerate(compartments):
        add_items(it, "w3_sushi" if idx % 2 == 0 else "w3_takoyaki", pt_rect_outline(cx, cz, 2.2, 2.0, 4), 1)
        add_items(it, "w3_ramen", [[cx - 1.0, cz], [cx + 1.0, cz]], 1)
        if idx in (0, 1, 4, 5):
            add_items(it, "w3_bento", [[cx, cz]], 1)
        else:
            add_items(it, "w3_big_ramen", [[cx, cz - 1.2], [cx, cz + 1.2]], 1)
    add_items(it, "w3_big_ramen", [[0, -7.8], [0, 7.8], [0, -3.4], [0, 3.4]], 1)
    traps = [{"pos": [0, -5.6]}, {"pos": [0, 5.6]}]
    bombs = [{"pos": [-2.8, -3.0]}, {"pos": [2.8, 3.0]}]
    emit(33, 3, "Bento Grid", "NORMAL", 32, 20, 24, [0, 0],
         {"w3_big_ramen": 6, "w3_bento": 4}, it,
         [{"kind": "magnet", "pos": [0, 2.6]}, {"kind": "ice", "pos": [0, -2.6]}], traps, bombs=bombs)

    # Lv.34 — Torii Gate (Japanese Torii silhouette + 3 Time Bombs!)
    it = []
    # Top Kasagi beam + lower Nuki beam + two pillars
    add_items(it, "w3_sushi", pt_line(-8.2, -7.4, 8.2, -7.4, 15) + pt_line(-7.2, -4.4, 7.2, -4.4, 13), 1)
    add_items(it, "w3_takoyaki", pt_line(-4.6, -7.4, -4.6, 8.2, 12) + pt_line(4.6, -7.4, 4.6, 8.2, 12), 1)
    add_items(it, "w3_ramen", pt_line(-7.8, 2.0, 7.8, 2.0, 9) + pt_line(-7.8, 6.2, 7.8, 6.2, 7), 1)
    add_items(it, "w3_big_ramen", [[-7.6, -1.6], [7.6, -1.6], [-2.2, -1.6], [2.2, -1.6], [-7.6, 5.0], [7.6, 5.0], [0, -9.2], [0, 8.6]], 1)
    add_items(it, "w3_bento", [[-7.8, -8.8], [7.8, -8.8], [-7.8, 8.8], [7.8, 8.8]], 1)
    traps = [{"pos": [-4.6, -1.2]}, {"pos": [4.6, -1.2]}, {"pos": [0, -4.4]}]
    bombs = [{"pos": [-2.0, -6.0]}, {"pos": [2.0, -6.0]}, {"pos": [0.0, 4.0]}]
    emit(34, 3, "Torii Gate", "NORMAL", 37, 20, 24, [0, 8.8],
         {"w3_big_ramen": 7, "w3_bento": 4}, it,
         [{"kind": "ice", "pos": [-3.0, 4.2]}, {"kind": "magnet", "pos": [3.0, 4.2]}], traps, bombs=bombs)

    # Lv.35 — HARD · Neon Crossroad (Scheme A tightened XP ~640/475 = 1.35x + 4 Time Bombs!)
    it = []
    add_items(it, "w3_sushi", pt_line(-8.4, 0, 8.4, 0, 14) + pt_line(0, -9.4, 0, 9.4, 14), 1, [0, 0])
    add_items(it, "w3_takoyaki", pt_grid(-5.6, -6.2, 2, 2, 1.8, 1.8) + pt_grid(5.6, -6.2, 2, 2, 1.8, 1.8) +
              pt_grid(-5.6, 6.2, 2, 2, 1.8, 1.8) + pt_grid(5.6, 6.2, 2, 2, 1.8, 1.8), 1)
    add_items(it, "w3_ramen", pt_ring(0, 0, 4.2, 4.6, 10), 1)
    add_items(it, "w3_big_ramen", [[-8.0, -4.6], [8.0, -4.6], [-8.0, 4.6], [8.0, 4.6], [-4.2, -9.2], [4.2, -9.2], [-4.2, 9.2], [4.2, 9.2]], 1)
    add_items(it, "w3_bento", [[-8.6, -9.8], [8.6, -9.8], [-8.6, 9.8], [8.6, 9.8], [0, -10.2]], 1)
    traps = [{"pos": [-3.2, -3.2]}, {"pos": [3.2, -3.2]}, {"pos": [-3.2, 3.2]}, {"pos": [3.2, 3.2]}, {"pos": [0, -6.8]}]
    bombs = [{"pos": [-6.2, 0.0]}, {"pos": [6.2, 0.0]}, {"pos": [0.0, -4.4]}, {"pos": [0.0, 4.4]}]
    emit(35, 3, "Neon Crossroad", "HARD", 34, 22, 26, [0, 0],
         {"w3_big_ramen": 8, "w3_bento": 5}, it,
         [{"kind": "ice", "pos": [0, 2.2]}], traps, bombs=bombs, streak_hint=35)

    # Lv.36 — Cheese Spiral (Melted cheese spiral + 3 bombs)
    it = []
    add_items(it, "w3_sushi", pt_spiral(34, 2.0, 8.8, 2.0, 0.0), 1, [0, 0])
    add_items(it, "w3_takoyaki", pt_spiral(28, 2.2, 8.6, 1.8, math.pi), 1, [0, 0])
    add_items(it, "w3_ramen", pt_spiral(16, 2.8, 8.0, 1.6, 0.9), 1)
    add_items(it, "w3_big_ramen", pt_ring(0, 0, 6.2, 7.0, 10, 0.2), 1)
    add_items(it, "w3_bento", pt_ring(0, 0, 8.4, 9.4, 5, 0.5), 1)
    add_items(it, "w3_grand_bento", [[0, -10.6]], 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 4.4, 4.8, 5, 0.3)]
    bombs = [{"pos": [-6.8, -2.0]}, {"pos": [6.8, 2.0]}, {"pos": [0.0, -7.2]}]
    emit(36, 3, "Cheese Spiral", "NORMAL", 31, 22, 26, [0, 0],
         {"w3_big_ramen": 8, "w3_bento": 4, "w3_grand_bento": 1}, it,
         [{"kind": "ice", "pos": [-3.0, 2.4]}, {"kind": "magnet", "pos": [3.0, -2.4]}], traps, bombs=bombs)

    # Lv.37 — Tempura Star (6-point lantern star + Royal Bento Bosses!)
    it = []
    add_items(it, "w3_sushi", pt_star(6, 8.8, 4.2, 5), 1, [0, 0])
    add_items(it, "w3_takoyaki", pt_ring(0, 0, 3.2, 3.4, 18), 1)
    add_items(it, "w3_ramen", pt_ring(0, 0, 5.4, 6.0, 14), 1)
    add_items(it, "w3_big_ramen", pt_ring(0, 0, 7.0, 7.8, 10, 0.25), 1)
    add_items(it, "w3_bento", pt_ring(0, 0, 8.8, 9.6, 6, 0.0), 1)
    add_items(it, "w3_grand_bento", [[0, -10.8], [0, 10.8]], 1)
    traps = [{"pos": [-4.2, -3.2]}, {"pos": [4.2, -3.2]}, {"pos": [-4.2, 3.2]}, {"pos": [4.2, 3.2]}, {"pos": [0, -7.2]}]
    bombs = [{"pos": [-6.8, 0.0]}, {"pos": [6.8, 0.0]}, {"pos": [0.0, 7.2]}]
    emit(37, 3, "Tempura Star", "NORMAL", 36, 22, 26, [0, 0],
         {"w3_big_ramen": 8, "w3_bento": 4, "w3_grand_bento": 2}, it,
         [{"kind": "ice", "pos": [-2.8, 0]}, {"kind": "magnet", "pos": [2.8, 0]}], traps, bombs=bombs)

    # Lv.38 — Izakaya Twins
    it = []
    add_items(it, "w3_sushi", pt_ring(-5.8, -5.2, 3.2, 3.4, 14) + pt_ring(5.8, -5.2, 3.2, 3.4, 14), 1)
    add_items(it, "w3_takoyaki", pt_ring(-5.8, 5.2, 3.2, 3.4, 14) + pt_ring(5.8, 5.2, 3.2, 3.4, 14), 1)
    add_items(it, "w3_ramen", pt_line(0, -8.5, 0, 8.5, 11) + [[-5.8, 0], [5.8, 0]], 1, [0, 0])
    add_items(it, "w3_big_ramen", [[-8.6, -5.2], [8.6, -5.2], [-8.6, 5.2], [8.6, 5.2], [-3.0, -8.8], [3.0, -8.8], [-3.0, 8.8], [3.0, 8.8], [-5.8, -5.2], [5.8, 5.2]], 1)
    add_items(it, "w3_bento", [[-8.8, -9.6], [8.8, -9.6], [-8.8, 9.6], [8.8, 9.6]], 1)
    add_items(it, "w3_grand_bento", [[-5.8, 5.2], [5.8, -5.2]], 1)
    traps = [{"pos": [-2.8, 0]}, {"pos": [2.8, 0]}, {"pos": [0, -5.2]}, {"pos": [0, 5.2]}, {"pos": [-5.8, -1.8]}, {"pos": [5.8, 1.8]}]
    bombs = [{"pos": [-2.8, -5.2]}, {"pos": [2.8, -5.2]}, {"pos": [-2.8, 5.2]}, {"pos": [2.8, 5.2]}]
    emit(38, 3, "Izakaya Twins", "NORMAL", 48, 22, 26, [0, 0],
         {"w3_big_ramen": 8, "w3_bento": 4, "w3_grand_bento": 2}, it,
         [{"kind": "ice", "pos": [0, -2.6]}, {"kind": "magnet", "pos": [0, 2.6]}], traps, bombs=bombs)

    # Lv.39 — SUPER_HARD CLIFF · Midnight Ramen Rush (Scheme A XP ~955/810 = 1.18x + 5 Time Bombs!)
    it = []
    add_items(it, "w3_sushi", pt_grid(0, 9.4, 9, 2, 2.0, 1.3), 1, [0, 10.2])
    add_items(it, "w3_takoyaki", pt_line(-8.6, 6.6, 8.6, 6.6, 12) + pt_line(-7.6, 4.2, 7.6, 4.2, 10), 1)
    add_items(it, "w3_ramen", pt_line(-8.8, 1.4, -8.8, -5.8, 6) + pt_line(8.8, 1.4, 8.8, -5.8, 6) + pt_line(-4.0, 1.2, 4.0, 1.2, 5), 1)
    add_items(it, "w3_big_ramen", [[-8.8, -2.5], [8.8, -2.5], [-4.5, -5.4], [4.5, -5.4], [0, -5.4], [-8.8, 4.8], [8.8, 4.8], [0, -8.4]], 1)
    add_items(it, "w3_bento", [[-9.2, -9.0], [9.2, -9.0], [-4.4, -9.4], [4.4, -9.4], [0, -1.6]], 1)
    add_items(it, "w3_grand_bento", [[-8.4, -12.0], [0.0, -12.2], [8.4, -12.0]], 1)
    traps = [
        {"pos": [-6.2, 2.8]}, {"pos": [0.0, 2.8]}, {"pos": [6.2, 2.8]},
        {"pos": [-3.6, -2.2]}, {"pos": [3.6, -2.2]},
        {"pos": [-6.8, -6.2]}, {"pos": [6.8, -6.2]},
    ]
    bombs = [
        {"pos": [-4.4, 5.2]}, {"pos": [4.4, 5.2]},
        {"pos": [0.0, -3.6]},
        {"pos": [-4.2, -10.8]}, {"pos": [4.2, -10.8]},
    ]
    emit(39, 3, "Midnight Ramen Rush", "SUPER_HARD", 31, 24, 28, [0, 10.6],
         {"w3_big_ramen": 7, "w3_bento": 4, "w3_grand_bento": 3}, it,
         [{"kind": "ice", "pos": [-5.4, 7.8]}], traps, bombs=bombs, streak_hint=249)

    # Lv.40 — MEGA_BOSS (30x34 Epic Stage!) · Grand Night Market! (Scheme A XP ~985/810 = 1.22x + 6 Bombs!)
    it = []
    add_items(it, "w3_sushi", pt_ring(0, 0, 3.2, 3.2, 16) + pt_line(-9.0, 0, -4.5, 0, 4) + pt_line(4.5, 0, 9.0, 0, 4), 1)
    add_items(it, "w3_takoyaki", pt_ring(0, 0, 5.6, 6.2, 14), 1)
    add_items(it, "w3_ramen", pt_ring(0, 0, 8.2, 9.2, 12) + [[-4.8, -11.4], [4.8, -11.4], [-4.8, 11.4], [4.8, 11.4]], 1)
    add_items(it, "w3_big_ramen", [[-11.2, -5.2], [11.2, -5.2], [-11.2, 5.2], [11.2, 5.2], [-5.2, -12.8], [5.2, -12.8], [-5.2, 12.8], [5.2, 12.8]], 1)
    add_items(it, "w3_bento", [[-12.0, -10.4], [12.0, -10.4], [-12.0, 10.4], [12.0, 10.4], [0, -14.0], [0, 14.0]], 1)
    add_items(it, "w3_grand_bento", [[-12.6, -14.2], [12.6, -14.2], [-12.6, 14.2], [12.6, 14.2]], 1)
    traps = [
        {"pos": [-5.6, -5.6]}, {"pos": [5.6, -5.6]}, {"pos": [-5.6, 5.6]}, {"pos": [5.6, 5.6]},
        {"pos": [0, -8.2]}, {"pos": [0, 8.2]}, {"pos": [-9.6, 0]}, {"pos": [9.6, 0]},
    ]
    bombs = [
        {"pos": [-9.4, -11.6]}, {"pos": [9.4, -11.6]}, {"pos": [-9.4, 11.6]}, {"pos": [9.4, 11.6]},
        {"pos": [-11.6, 0.0]}, {"pos": [11.6, 0.0]},
    ]
    emit(40, 3, "Grand Night Market", "MEGA_BOSS", 51, 30, 34, [0, 0],
         {"w3_big_ramen": 7, "w3_bento": 5, "w3_grand_bento": 4}, it,
         [{"kind": "ice", "pos": [0, -3.4]}, {"kind": "magnet", "pos": [0, 3.4]}], traps, bombs=bombs, streak_hint=299)

    # =========================================================================
    # WORLD 4: COZY ALCHEMIST DESK (Lv.41 - Lv.50) — Slime + Bombs + Rubber Walls!
    # =========================================================================

    # Lv.41 — Crystal Hex (Fresh W4 ASMR Intro, 0 bombs, 0 traps)
    it = []
    add_items(it, "w4_d20", pt_poly(6, 7.0, 7.8, 7), 3)
    add_items(it, "w4_slime", pt_poly(6, 4.8, 5.4, 5), 3)
    add_items(it, "w4_potion", pt_ring(0, 0, 3.0, 3.4, 10), 2)
    add_items(it, "w4_spellbook", pt_ring(0, 0, 6.2, 7.2, 6, 0.5), 1)
    emit(41, 4, "Crystal Hex", "EASY", 45, 18, 22, [0, 0],
         {"w4_potion": 8, "w4_spellbook": 5}, it, [{"kind": "magnet", "pos": [0, 3.2]}], [])

    # Lv.42 — Potion Flask (Flask silhouette + 2 Neon Slime traps!)
    it = []
    add_items(it, "w4_d20", pt_ring(0, 2.4, 6.2, 6.2, 30) + pt_line(-2.2, -3.6, -2.2, -8.4, 6) + pt_line(2.2, -3.6, 2.2, -8.4, 6), 3)
    add_items(it, "w4_slime", pt_ring(0, 2.4, 4.2, 4.2, 18) + pt_line(-3.4, -8.4, 3.4, -8.4, 6), 3)
    add_items(it, "w4_potion", pt_ring(0, 2.4, 2.6, 2.6, 10) + [[0, -5.8], [0, -7.2]], 2)
    add_items(it, "w4_spellbook", [[-6.8, -5.2], [6.8, -5.2], [-7.2, 6.2], [7.2, 6.2], [0, 8.8], [0, -2.2]], 1)
    add_items(it, "w4_cauldron", [[-7.2, -8.6], [7.2, -8.6], [0, 2.4]], 1)
    traps = [{"pos": [-3.0, -2.2]}, {"pos": [3.0, -2.2]}]
    emit(42, 4, "Potion Flask", "EASY", 45, 20, 24, [0, -4.2],
         {"w4_potion": 9, "w4_spellbook": 5, "w4_cauldron": 3}, it,
         [{"kind": "ice", "pos": [-3.2, 2.4]}, {"kind": "magnet", "pos": [3.2, 2.4]}], traps)

    # Lv.43 — Spellbook Pages (Open Twin-Page Grimoire + 3 Time Bombs!)
    it = []
    add_items(it, "w4_d20", pt_rect_outline(-4.8, 0, 3.4, 7.6, 7) + pt_rect_outline(4.8, 0, 3.4, 7.6, 7), 3)
    add_items(it, "w4_slime", pt_line(-6.8, -4.4, -2.8, -4.4, 4) + pt_line(-6.8, 0, -2.8, 0, 4) + pt_line(-6.8, 4.4, -2.8, 4.4, 4) +
              pt_line(2.8, -4.4, 6.8, -4.4, 4) + pt_line(2.8, 0, 6.8, 0, 4) + pt_line(2.8, 4.4, 6.8, 4.4, 4), 3)
    add_items(it, "w4_potion", pt_line(0, -7.6, 0, 7.6, 10) + [[-4.8, -2.2], [4.8, 2.2]], 2, [0, 0])
    add_items(it, "w4_spellbook", [[-4.8, -6.2], [-4.8, 2.2], [-4.8, 6.2], [4.8, -6.2], [4.8, -2.2], [4.8, 6.2], [0, -9.2], [0, 9.2]], 1)
    add_items(it, "w4_cauldron", [[-7.6, -8.8], [7.6, -8.8], [-7.6, 8.8], [7.6, 8.8]], 1)
    traps = [{"pos": [-2.2, -2.2]}, {"pos": [2.2, 2.2]}]
    bombs = [{"pos": [-4.8, 0.0]}, {"pos": [4.8, 0.0]}, {"pos": [0.0, -5.0]}]
    emit(43, 4, "Spellbook Pages", "NORMAL", 37, 20, 24, [0, 0],
         {"w4_spellbook": 7, "w4_cauldron": 4}, it,
         [{"kind": "ice", "pos": [0, 3.6]}, {"kind": "magnet", "pos": [0, -2.8]}], traps, bombs=bombs)

    # Lv.44 — Pentagram Altar (5-point arcane star + Slimes + 3 Bombs)
    it = []
    add_items(it, "w4_d20", pt_star(5, 8.4, 3.6, 7), 3, [0, 0])
    add_items(it, "w4_slime", pt_ring(0, 0, 3.2, 3.4, 16), 3)
    add_items(it, "w4_potion", pt_ring(0, 0, 5.4, 5.8, 12, 0.25), 2)
    add_items(it, "w4_spellbook", pt_ring(0, 0, 7.0, 7.8, 8, 0.0), 1)
    add_items(it, "w4_cauldron", pt_ring(0, 0, 8.6, 9.8, 5, -math.pi / 2.0), 1)
    traps = [{"pos": [-3.6, -2.4]}, {"pos": [3.6, -2.4]}, {"pos": [0.0, 4.2]}]
    bombs = [{"pos": [-5.8, 2.6]}, {"pos": [5.8, 2.6]}, {"pos": [0.0, -5.6]}]
    emit(44, 4, "Pentagram Altar", "NORMAL", 27, 20, 24, [0, 0],
         {"w4_spellbook": 8, "w4_cauldron": 5}, it,
         [{"kind": "ice", "pos": [-2.8, 0]}], traps, bombs=bombs)

    # Lv.45 — HARD · Cauldron Spiral (Scheme A tightened XP ~645/475 = 1.36x + 4 Time Bombs!)
    it = []
    add_items(it, "w4_d20", pt_spiral(20, 2.0, 8.8, 1.8, 0.0), 3, [0, 0])
    add_items(it, "w4_slime", pt_spiral(16, 2.2, 8.6, 1.8, math.pi), 3, [0, 0])
    add_items(it, "w4_potion", pt_spiral(12, 2.8, 8.0, 1.5, 0.85), 2)
    add_items(it, "w4_spellbook", pt_ring(0, 0, 6.8, 7.6, 8, 0.2), 1)
    add_items(it, "w4_cauldron", pt_ring(0, 0, 8.8, 9.8, 5, 0.5), 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 4.6, 5.0, 5, 0.3)]
    bombs = [{"pos": [-6.4, -3.2]}, {"pos": [6.4, 3.2]}, {"pos": [-3.2, 6.8]}, {"pos": [3.2, -6.8]}]
    emit(45, 4, "Cauldron Spiral", "HARD", 32, 22, 26, [0, 0],
         {"w4_spellbook": 8, "w4_cauldron": 5}, it,
         [{"kind": "ice", "pos": [0, -2.8]}], traps, bombs=bombs, streak_hint=45)

    # Lv.46 — Rune Corridor (Wide Rubber Walls + Neon Slimes + 1st Grand Cauldron Boss!)
    it = []
    add_items(it, "w4_d20", pt_grid(0, 8.8, 9, 2, 1.9, 1.4) + pt_grid(0, 0, 8, 2, 2.0, 1.4) + pt_grid(0, -8.4, 8, 2, 2.0, 1.4), 3, [0, 9.4])
    add_items(it, "w4_slime", pt_line(-8.2, 4.2, 8.2, 4.2, 9) + pt_line(-8.2, -4.2, 8.2, -4.2, 9), 3)
    add_items(it, "w4_potion", pt_ring(0, 0, 5.6, 5.8, 12), 2)
    add_items(it, "w4_spellbook", [[-7.8, -1.8], [0, -1.8], [7.8, -1.8], [-7.8, -6.6], [0, -6.6], [7.8, -6.6], [-7.8, 2.0], [7.8, 2.0]], 1)
    add_items(it, "w4_cauldron", [[-7.8, -9.8], [7.8, -9.8], [0, -10.0], [0, 2.6]], 1)
    add_items(it, "w4_grand_cauldron", [[0, -11.0]], 1)
    walls = [{"pos": [-4.4, 4.2], "rot_deg": 0.0}, {"pos": [4.4, -0.5], "rot_deg": 0.0}, {"pos": [-4.4, -5.2], "rot_deg": 0.0}]
    traps = [{"pos": [6.6, 4.2]}, {"pos": [-6.6, -0.5]}, {"pos": [6.6, -5.2]}]
    bombs = [{"pos": [2.2, 4.2]}, {"pos": [-2.2, -0.5]}, {"pos": [2.2, -5.2]}, {"pos": [0.0, -8.6]}]
    emit(46, 4, "Rune Corridor", "NORMAL", 45, 22, 26, [0, 9.6],
         {"w4_spellbook": 7, "w4_cauldron": 3, "w4_grand_cauldron": 1}, it,
         [{"kind": "magnet", "pos": [5.5, 7.2]}, {"kind": "ice", "pos": [-5.5, -2.5]}], traps, walls, bombs)

    # Lv.47 — Twin Alchemy Towers (Wide Rubber Walls + 2 Grand Cauldrons + 4 Bombs!)
    it = []
    add_items(it, "w4_d20", pt_grid(0, 8.2, 9, 2, 2.0, 1.4) + pt_grid(0, 1.6, 6, 3, 2.0, 1.4), 3, [0, 9.2])
    add_items(it, "w4_slime", pt_ring(-6.8, -6.4, 3.2, 3.4, 10) + pt_ring(6.8, -6.4, 3.2, 3.4, 10), 3)
    add_items(it, "w4_potion", pt_line(-9.2, 3.4, 9.2, 3.4, 12), 2)
    add_items(it, "w4_spellbook", [[-7.4, -3.2], [-7.4, -9.4], [7.4, -3.2], [7.4, -9.4], [-3.0, -5.2], [3.0, -5.2], [-9.2, 0.6], [9.2, 0.6]], 1)
    add_items(it, "w4_cauldron", [[-9.4, -6.4], [9.4, -6.4], [-3.8, -10.2], [3.8, -10.2]], 1)
    add_items(it, "w4_grand_cauldron", [[-6.8, -6.6], [6.8, -6.6]], 1)
    walls = [{"pos": [-5.4, -0.6], "rot_deg": 0.0}, {"pos": [5.4, -0.6], "rot_deg": 0.0}, {"pos": [0.0, -7.8], "rot_deg": 90.0}]
    traps = [{"pos": [-2.2, -0.6]}, {"pos": [2.2, -0.6]}, {"pos": [-6.8, -10.2]}, {"pos": [6.8, -10.2]}]
    bombs = [{"pos": [0.0, 4.6]}, {"pos": [-9.0, -2.6]}, {"pos": [9.0, -2.6]}, {"pos": [0.0, -3.4]}]
    emit(47, 4, "Twin Alchemy Towers", "NORMAL", 42, 24, 26, [0, 9.6],
         {"w4_spellbook": 7, "w4_cauldron": 3, "w4_grand_cauldron": 2}, it,
         [{"kind": "ice", "pos": [0, 1.4]}, {"kind": "magnet", "pos": [-6.4, 6.2]}], traps, walls, bombs)

    # Lv.48 — Constellation Orbit (4 Wide Rubber Walls + 5 Bombs!)
    it = []
    add_items(it, "w4_d20", pt_ring(0, 0, 8.2, 9.0, 32), 3)
    add_items(it, "w4_slime", pt_ring(0, 0, 5.4, 6.0, 22), 3)
    add_items(it, "w4_potion", pt_ring(0, 0, 3.0, 3.4, 12), 2)
    add_items(it, "w4_spellbook", [[-7.6, -3.0], [7.6, -3.0], [-7.6, 3.0], [7.6, 3.0], [-3.2, -8.8], [3.2, -8.8], [-3.2, 8.8], [3.2, 8.8]], 1)
    add_items(it, "w4_cauldron", [[-8.8, -9.2], [8.8, -9.2], [-8.8, 9.2], [8.8, 9.2]], 1)
    add_items(it, "w4_grand_cauldron", [[0, -10.6], [0, 10.6]], 1)
    walls = [{"pos": [-5.2, 0.0], "rot_deg": 0.0}, {"pos": [5.2, 0.0], "rot_deg": 0.0},
             {"pos": [0.0, -6.2], "rot_deg": 90.0}, {"pos": [0.0, 6.2], "rot_deg": 90.0}]
    traps = [{"pos": [-2.6, -2.6]}, {"pos": [2.6, -2.6]}, {"pos": [-2.6, 2.6]}, {"pos": [2.6, 2.6]}]
    bombs = [{"pos": [-8.4, 0.0]}, {"pos": [8.4, 0.0]}, {"pos": [-5.2, -5.6]}, {"pos": [5.2, 5.6]}, {"pos": [0.0, -9.2]}]
    emit(48, 4, "Constellation Orbit", "NORMAL", 50, 24, 26, [0, 0],
         {"w4_spellbook": 7, "w4_cauldron": 4, "w4_grand_cauldron": 2}, it,
         [{"kind": "ice", "pos": [0, -2.4]}, {"kind": "magnet", "pos": [0, 2.4]}], traps, walls, bombs)

    # Lv.49 — SUPER_HARD CLIFF · Arcane Gauntlet (Scheme A XP ~955/810 = 1.18x + Walls + Slimes + 5 Bombs!)
    it = []
    add_items(it, "w4_d20", pt_grid(0, 9.6, 9, 2, 2.0, 1.3), 3, [0, 10.4])
    add_items(it, "w4_slime", pt_line(-8.8, 6.6, 8.8, 6.6, 12) + pt_line(-8.0, 4.0, 8.0, 4.0, 10), 3)
    add_items(it, "w4_potion", pt_line(-8.8, 1.4, -8.8, -5.6, 6) + pt_line(8.8, 1.4, 8.8, -5.6, 6) + pt_line(-3.8, 1.4, 3.8, 1.4, 5), 2)
    add_items(it, "w4_spellbook", [[-8.8, -2.6], [8.8, -2.6], [-4.2, -4.6], [4.2, -4.6], [0, -8.4], [-8.8, 4.6], [8.8, 4.6], [0, 0.2]], 1)
    add_items(it, "w4_cauldron", [[-9.2, -9.2], [9.2, -9.2], [-4.4, -9.6], [4.4, -9.6], [0, -2.8]], 1)
    add_items(it, "w4_grand_cauldron", [[-8.4, -12.0], [0.0, -12.2], [8.4, -12.0]], 1)
    walls = [{"pos": [-5.4, 1.4], "rot_deg": 90.0}, {"pos": [5.4, 1.4], "rot_deg": 90.0}, {"pos": [0.0, -5.8], "rot_deg": 0.0}]
    traps = [{"pos": [-7.4, 3.0]}, {"pos": [7.4, 3.0]}, {"pos": [0, 3.0]}, {"pos": [-7.4, -1.6]}, {"pos": [7.4, -1.6]}, {"pos": [-5.4, -7.4]}, {"pos": [5.4, -7.4]}]
    bombs = [{"pos": [-3.0, 5.2]}, {"pos": [3.0, 5.2]}, {"pos": [0.0, -1.2]}, {"pos": [-4.2, -11.0]}, {"pos": [4.2, -11.0]}]
    emit(49, 4, "Arcane Gauntlet", "SUPER_HARD", 32, 24, 28, [0, 10.6],
         {"w4_spellbook": 7, "w4_cauldron": 4, "w4_grand_cauldron": 3}, it,
         [{"kind": "ice", "pos": [-6.0, 7.8]}], traps, walls, bombs, streak_hint=349)

    # Lv.50 — MEGA_BOSS FINALE (30x34 Epic Stage!) · Grand Alchemist Library! (5 Grand Cauldrons!)
    it = []
    add_items(it, "w4_d20", pt_ring(0, 0, 3.2, 3.2, 16) + pt_line(-9.0, 0, -4.5, 0, 4) + pt_line(4.5, 0, 9.0, 0, 4), 3)
    add_items(it, "w4_slime", pt_ring(0, 0, 5.6, 6.2, 14), 3)
    add_items(it, "w4_potion", pt_ring(0, 0, 8.2, 9.2, 12) + [[-4.8, -11.4], [4.8, -11.4], [-4.8, 11.4], [4.8, 11.4]], 2)
    add_items(it, "w4_spellbook", [[-11.2, -5.2], [11.2, -5.2], [-11.2, 5.2], [11.2, 5.2], [-5.2, -12.8], [5.2, -12.8], [-5.2, 12.8], [5.2, 12.8]], 1)
    add_items(it, "w4_cauldron", [[-12.0, -10.4], [12.0, -10.4], [-12.0, 10.4], [12.0, 10.4], [0, -11.2], [0, 14.0]], 1)
    # 5 Grand Cauldrons: 4 far corners + Northern Arcane Throne!
    add_items(it, "w4_grand_cauldron", [[-12.6, -14.4], [0.0, -14.8], [12.6, -14.4], [-12.6, 14.4], [12.6, 14.4]], 1)
    walls = [
        {"pos": [-7.4, -7.8], "rot_deg": 0.0}, {"pos": [7.4, -7.8], "rot_deg": 0.0},
        {"pos": [-7.4, 7.8], "rot_deg": 0.0}, {"pos": [7.4, 7.8], "rot_deg": 0.0},
    ]
    traps = [
        {"pos": [0, -6.2]}, {"pos": [0, 6.2]}, {"pos": [-7.4, 0]}, {"pos": [7.4, 0]},
        {"pos": [-11.8, -7.8]}, {"pos": [11.8, -7.8]}, {"pos": [-11.8, 7.8]}, {"pos": [11.8, 7.8]},
    ]
    bombs = [
        {"pos": [-9.2, -12.4]}, {"pos": [9.2, -12.4]}, {"pos": [-9.2, 12.4]}, {"pos": [9.2, 12.4]},
        {"pos": [-12.2, 0.0]}, {"pos": [12.2, 0.0]}, {"pos": [0.0, -12.8]},
    ]
    emit(50, 4, "Grand Alchemist Library", "MEGA_BOSS", 53, 30, 34, [0, 0],
         {"w4_spellbook": 7, "w4_cauldron": 5, "w4_grand_cauldron": 5}, it,
         [{"kind": "ice", "pos": [0, -3.4]}, {"kind": "magnet", "pos": [0, 3.4]}], traps, walls, bombs, streak_hint=499)

    print(f"Generated ALL {len(levels)} sculptural levels across 4 Worlds (Lv.1-50)!")
    for row in levels:
        num, w, nm, tg, dur, ni, nt, nw, nb, xa, xr = row
        print(f"  Lv.{num:02d} W{w} | {nm:24s} | {tg:10s} | {dur:2.0f}s | items={ni:3d} T={nt:2d} W={nw} B={nb} | XP={xa:4d}/{xr}")


if __name__ == "__main__":
    build_all()
