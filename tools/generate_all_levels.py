#!/usr/bin/env python3
"""
Gobble Pop! — 30 Handcrafted Hole-Stars-Style Sculptural Level Formations (World 1 Lv.1-20 & World 2 Lv.21-30)
Calibrated against gobble-pop-demo cumulative XP (95 / 245 / 475 / 810) and genuine cliff difficulty spikes!
"""
import json
import math
import os
import random

OUT_DIR = "/Users/unmercy/Documents/antig/hole/data/levels"
os.makedirs(OUT_DIR, exist_ok=True)

XP = {
    "w1_sprinkle": 5, "w1_strawberry": 6, "w1_gummy_bear": 7,
    "w1_macaron": 14, "w1_boba_tea": 13, "w1_donut": 26,
    "w1_cake": 46, "w1_grand_cake": 80,
    "w2_block": 6, "w2_duck": 14, "w2_figurine": 15,
    "w2_arcade": 28, "w2_unicorn": 46, "w2_golden_gacha": 80,
}

# ---------------------------------------------------------------------------
# Distinct geometric / sculptural formation generators (Hole Stars style!)
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
        items.append({"key": key, "pos": p, "color_idx": i % max(1, mod_colors)})


def build_all():
    levels = []

    def emit(num, world, name, tag, duration, arena_w, arena_h, spawn, targets, items, powerups, traps, walls=None, streak_hint=0):
        # Clamp all items inside arena cleanly
        hw, hh = arena_w * 0.5 - 1.1, arena_h * 0.5 - 1.1
        for it in items:
            it["pos"][0] = round(max(-hw, min(hw, it["pos"][0])), 2)
            it["pos"][1] = round(max(-hh, min(hh, it["pos"][1])), 2)
        for tr in traps:
            tr["pos"][0] = round(max(-hw, min(hw, tr["pos"][0])), 2)
            tr["pos"][1] = round(max(-hh, min(hh, tr["pos"][1])), 2)

        # Ensure every target exists with enough count & validate cumulative XP!
        counts = {}
        for it in items:
            counts[it["key"]] = counts.get(it["key"], 0) + 1
        for k, need in targets.items():
            assert counts.get(k, 0) >= need, f"Lv.{num} {name}: not enough {k}: {counts.get(k,0)} < {need}"

        max_tier = max(
            5 if k in ("w1_grand_cake", "w2_golden_gacha") else
            4 if k in ("w1_cake", "w2_unicorn") else
            3 if k in ("w1_donut", "w2_arcade") else
            2 if k in ("w1_macaron", "w1_boba_tea", "w2_duck", "w2_figurine") else 1
            for k in targets
        )
        xp_need = {1: 0, 2: 95, 3: 245, 4: 475, 5: 810}[max_tier]
        xp_avail = sum(XP[it["key"]] for it in items if it["key"] not in ("w1_grand_cake", "w2_golden_gacha"))
        assert xp_avail >= xp_need * 1.15, f"Lv.{num} {name}: XP {xp_avail} < req {xp_need}"

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
        }
        with open(os.path.join(OUT_DIR, f"level_{num:03d}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        levels.append((num, world, name, tag, duration, len(items), len(traps), len(walls or []), xp_avail, xp_need))

    # =========================================================================
    # WORLD 1: SUGAR RUSH BAKERY (Lv.1 - Lv.20) — 20 Distinct Formations!
    # =========================================================================

    # Lv.1 — Candy Heart (Tutorial, ASMR flow)
    it = []
    add_items(it, "w1_sprinkle", pt_heart(32, 6.4, 6.4, 0, -0.4), 3, [0, 0])
    add_items(it, "w1_strawberry", pt_heart(24, 4.7, 4.7, 0, -0.4), 1, [0, 0])
    add_items(it, "w1_macaron", pt_heart(12, 3.2, 3.2, 0, -0.4), 3, [0, 0])
    add_items(it, "w1_donut", [[-4.8, -5.2], [4.8, -5.2], [-4.8, 4.8], [4.8, 4.8], [0.0, -6.6]], 2)
    emit(1, 1, "Candy Heart", "TUTORIAL", 45, 16, 20, [0, 0.2],
         {"w1_macaron": 6, "w1_donut": 4}, it, [{"kind": "magnet", "pos": [0, 4.2]}], [])

    # Lv.2 — Twin Spiral Vortex
    it = []
    add_items(it, "w1_sprinkle", pt_spiral(28, 1.8, 6.5, 1.6, 0.0), 3, [0, 0])
    add_items(it, "w1_gummy_bear", pt_spiral(24, 1.8, 6.5, 1.6, math.pi), 3, [0, 0])
    add_items(it, "w1_boba_tea", pt_ring(0, 0, 4.2, 5.2, 10, 0.2), 1)
    add_items(it, "w1_donut", pt_ring(0, 0, 5.8, 7.2, 6, 0.5), 2)
    emit(2, 1, "Twin Spiral", "EASY", 45, 17, 21, [0, 0],
         {"w1_boba_tea": 7, "w1_donut": 5}, it, [{"kind": "magnet", "pos": [0, -3.2]}], [])

    # Lv.3 — Smiley Bakery Face
    it = []
    add_items(it, "w1_sprinkle", pt_ring(0, 0, 6.4, 7.2, 32), 3) # Face circle
    add_items(it, "w1_strawberry", pt_arc(0, 0.4, 4.2, 4.0, 0.25, math.pi - 0.25, 20), 1) # Big smile!
    add_items(it, "w1_macaron", pt_ring(-2.6, -2.5, 1.1, 1.1, 6) + pt_ring(2.6, -2.5, 1.1, 1.1, 6), 3) # Eyes
    add_items(it, "w1_gummy_bear", pt_line(0, -1.6, 0, 1.0, 6), 3) # Nose
    add_items(it, "w1_donut", [[-4.8, 1.4], [4.8, 1.4], [-2.6, -2.5], [2.6, -2.5], [0, -5.6], [0, 5.6]], 2) # Cheeks & accents
    emit(3, 1, "Smiley Face", "NORMAL", 44, 17, 21, [0, 2.5],
         {"w1_macaron": 9, "w1_donut": 5}, it, [], [])

    # Lv.4 — Ice & Magnet Crossroad
    it = []
    add_items(it, "w1_sprinkle", pt_line(-6.8, 0, 6.8, 0, 16) + pt_line(0, -7.8, 0, 7.8, 18), 3, [0, 0])
    add_items(it, "w1_gummy_bear", pt_grid(-4.0, -4.5, 3, 3, 1.1, 1.1) + pt_grid(4.0, 4.5, 3, 3, 1.1, 1.1), 3)
    add_items(it, "w1_strawberry", pt_grid(4.0, -4.5, 3, 3, 1.1, 1.1) + pt_grid(-4.0, 4.5, 3, 3, 1.1, 1.1), 1)
    add_items(it, "w1_boba_tea", pt_ring(0, 0, 4.8, 5.4, 10, 0.3), 1)
    add_items(it, "w1_donut", [[-6.0, -7.2], [6.0, -7.2], [-6.0, 7.2], [6.0, 7.2], [0, -7.8], [0, 7.8]], 2)
    emit(4, 1, "Ice-Magnet Cross", "EASY", 45, 18, 22, [0, 0],
         {"w1_boba_tea": 8, "w1_donut": 6}, it,
         [{"kind": "ice", "pos": [-2.6, 0]}, {"kind": "magnet", "pos": [2.6, 0]}], [])

    # Lv.5 — HARD · Hourglass Squeeze (First real IAA pinch!)
    it = []
    add_items(it, "w1_sprinkle", pt_line(-7.2, 8.2, 7.2, 8.2, 16) + pt_line(-7.2, -8.2, 7.2, -8.2, 16), 3)
    add_items(it, "w1_strawberry", pt_line(-7.0, 8.0, 0.0, 0.0, 11) + pt_line(7.0, 8.0, 0.0, 0.0, 11), 1, [0, 5.2])
    add_items(it, "w1_gummy_bear", pt_line(-7.0, -8.0, 0.0, 0.0, 11) + pt_line(7.0, -8.0, 0.0, 0.0, 11), 3)
    add_items(it, "w1_macaron", pt_grid(0, 6.4, 6, 2, 1.8, 1.5), 3, [0, 3.6])
    add_items(it, "w1_boba_tea", pt_grid(0, -5.8, 5, 2, 1.6, 1.4), 1)
    add_items(it, "w1_donut", [[-6.8, -8.2], [6.8, -8.2], [0, -8.8], [-5.2, -5.6], [5.2, -5.6], [-6.8, 8.2], [6.8, 8.2], [0, 0]], 2)
    traps = [{"pos": [-2.2, 0.0]}, {"pos": [2.2, 0.0]}, {"pos": [0.0, -2.2]}]
    emit(5, 1, "Hourglass Pinch", "HARD", 37, 20, 24, [0, 3.6],
         {"w1_macaron": 9, "w1_donut": 7}, it,
         [{"kind": "ice", "pos": [-5.2, 2.2]}, {"kind": "magnet", "pos": [5.2, -2.2]}], traps, streak_hint=5)

    # Lv.6 — Starburst Cake Sun
    it = []
    add_items(it, "w1_sprinkle", pt_star(5, 7.6, 3.4, 7), 3, [0, 0])
    add_items(it, "w1_strawberry", pt_ring(0, 0, 2.8, 2.8, 16), 1)
    add_items(it, "w1_macaron", pt_ring(0, 0, 4.8, 5.2, 12, 0.25), 3)
    add_items(it, "w1_donut", pt_ring(0, 0, 6.2, 6.8, 8, 0.0), 2)
    add_items(it, "w1_cake", pt_ring(0, 0, 7.6, 8.2, 5, -math.pi / 2.0), 1)
    emit(6, 1, "Starburst Sun", "NORMAL", 45, 20, 24, [0, 0],
         {"w1_donut": 6, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [0, 3.6]}, {"kind": "ice", "pos": [0, -3.6]}], [])

    # Lv.7 — 3x3 Bakery Islands
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

    # Lv.8 — Concentric Cake Citadel
    it = []
    add_items(it, "w1_sprinkle", pt_rect_outline(0, 0, 7.6, 8.8, 10), 3)
    add_items(it, "w1_strawberry", pt_rect_outline(0, 0, 5.8, 6.8, 8), 1)
    add_items(it, "w1_macaron", pt_rect_outline(0, 0, 4.0, 4.8, 6), 3)
    add_items(it, "w1_donut", pt_rect_outline(0, 0, 2.4, 2.8, 3), 2)
    add_items(it, "w1_cake", [[-1.6, 0], [1.6, 0], [0, -2.0], [0, 2.0]], 1)
    emit(8, 1, "Cake Citadel", "NORMAL", 44, 20, 24, [0, 8.0],
         {"w1_macaron": 10, "w1_donut": 7, "w1_cake": 4}, it,
         [{"kind": "ice", "pos": [-5.2, 0]}, {"kind": "magnet", "pos": [5.2, 0]}], [])

    # Lv.9 — HARD · Bubblegum Bow-Tie
    it = []
    # Left triangle wing + right triangle wing
    add_items(it, "w1_sprinkle", pt_line(-8.0, -7.8, -8.0, 7.8, 14) + pt_line(8.0, -7.8, 8.0, 7.8, 14), 3)
    add_items(it, "w1_gummy_bear", pt_line(-7.6, -7.4, 0, 0, 9) + pt_line(-7.6, 7.4, 0, 0, 9) +
              pt_line(7.6, -7.4, 0, 0, 9) + pt_line(7.6, 7.4, 0, 0, 9), 3, [0, 0])
    add_items(it, "w1_boba_tea", pt_grid(-5.5, 0, 2, 4, 1.5, 2.4) + pt_grid(5.5, 0, 2, 4, 1.5, 2.4), 1)
    add_items(it, "w1_donut", [[-7.2, -4.5], [-7.2, 0], [-7.2, 4.5], [7.2, -4.5], [7.2, 0], [7.2, 4.5], [0, -6.5], [0, 6.5]], 2)
    add_items(it, "w1_cake", [[-7.8, -7.8], [-7.8, 7.8], [7.8, -7.8], [7.8, 7.8], [0, -8.6]], 1)
    traps = [{"pos": [-2.8, -1.6]}, {"pos": [-2.8, 1.6]}, {"pos": [2.8, -1.6]}, {"pos": [2.8, 1.6]}, {"pos": [0.0, -4.5]}]
    emit(9, 1, "Gum Bow-Tie", "HARD", 39, 21, 25, [0, 0],
         {"w1_donut": 7, "w1_cake": 4}, it,
         [{"kind": "ice", "pos": [0, 4.8]}, {"kind": "magnet", "pos": [0, -2.5]}], traps, streak_hint=9)

    # Lv.10 — SUPER HARD CLIFF · Triple-Lane Gum Gauntlet!
    it = []
    # Dense starter XP in south yard, 3 gum-laced highways going north, Lv.5 Grand Cakes in northern vault!
    add_items(it, "w1_sprinkle", pt_grid(0, 9.2, 10, 3, 1.8, 1.2) + pt_line(-7.5, 5, -7.5, -7, 10) + pt_line(7.5, 5, 7.5, -7, 10), 3, [0, 9.2])
    add_items(it, "w1_strawberry", pt_grid(-7.5, 4.5, 3, 4, 1.2, 1.3) + pt_grid(7.5, 4.5, 3, 4, 1.2, 1.3), 1)
    add_items(it, "w1_gummy_bear", pt_grid(0, 4.2, 4, 4, 1.4, 1.3), 3)
    add_items(it, "w1_macaron", pt_line(-7.5, -1.5, -7.5, -7.5, 6) + pt_line(0, -1.5, 0, -7.5, 6) + pt_line(7.5, -1.5, 7.5, -7.5, 6), 3)
    add_items(it, "w1_boba_tea", pt_ring(0, 0, 5.0, 5.5, 14), 1)
    add_items(it, "w1_donut", pt_line(-8.5, -4.5, 8.5, -4.5, 7) + [[-8.5, 1.0], [8.5, 1.0], [0, -8.5]], 2)
    add_items(it, "w1_cake", [[-8.5, -9.2], [8.5, -9.2], [-3.8, -6.8], [3.8, -6.8], [0, -2.2]], 1)
    add_items(it, "w1_grand_cake", [[-5.6, -11.2], [0.0, -11.4], [5.6, -11.2]], 1)
    traps = [
        {"pos": [-7.5, 1.5]}, {"pos": [0.0, 1.5]}, {"pos": [7.5, 1.5]},
        {"pos": [-4.0, -1.8]}, {"pos": [4.0, -1.8]},
        {"pos": [-7.5, -5.0]}, {"pos": [0.0, -5.0]}, {"pos": [7.5, -5.0]},
        {"pos": [-3.2, -9.0]}, {"pos": [3.2, -9.0]},
    ]
    emit(10, 1, "Gum Gauntlet", "SUPER_HARD", 36, 24, 28, [0, 9.8],
         {"w1_donut": 8, "w1_cake": 4, "w1_grand_cake": 3}, it,
         [{"kind": "ice", "pos": [-4.5, 6.2]}], traps, streak_hint=49)

    # Lv.11 — Candy S-Wave (ASMR Recovery)
    it = []
    add_items(it, "w1_sprinkle", pt_wave(36, -7.5, 7.5, -4.5, 2.2, 1.5) + pt_wave(36, -7.5, 7.5, 4.5, 2.2, 1.5), 3)
    add_items(it, "w1_gummy_bear", pt_wave(26, -7.5, 7.5, 0.0, 2.4, 1.5), 3, [0, 0])
    add_items(it, "w1_macaron", pt_wave(14, -7.0, 7.0, -2.2, 1.6, 1.5), 3)
    add_items(it, "w1_donut", pt_wave(8, -7.0, 7.0, 2.2, 1.6, 1.5), 2)
    add_items(it, "w1_cake", [[-7.2, -7.5], [7.2, -7.5], [0, 8.0]], 1)
    emit(11, 1, "Candy S-Wave", "EASY", 45, 20, 24, [0, 0],
         {"w1_macaron": 10, "w1_donut": 6, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [-3.0, 0]}], [])

    # Lv.12 — Nested Diamond Pavilion
    it = []
    add_items(it, "w1_sprinkle", pt_diamond(0, 0, 8.2, 9.6, 10), 3)
    add_items(it, "w1_strawberry", pt_diamond(0, 0, 6.0, 7.2, 8), 1)
    add_items(it, "w1_boba_tea", pt_diamond(0, 0, 3.8, 4.6, 5), 1)
    add_items(it, "w1_donut", pt_diamond(0, 0, 7.2, 8.4, 3), 2)
    add_items(it, "w1_cake", [[0, -9.2], [0, 9.2], [-7.8, 0], [7.8, 0]], 1)
    emit(12, 1, "Diamond Pavilion", "EASY", 45, 20, 24, [0, 0],
         {"w1_strawberry": 16, "w1_donut": 7, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [0, 2.8]}], [])

    # Lv.13 — Twin Butterfly Wings
    it = []
    add_items(it, "w1_sprinkle", pt_ring(-4.8, -3.6, 3.4, 3.6, 16) + pt_ring(4.8, -3.6, 3.4, 3.6, 16), 3)
    add_items(it, "w1_gummy_bear", pt_ring(-4.2, 3.8, 2.8, 3.0, 14) + pt_ring(4.2, 3.8, 2.8, 3.0, 14), 3)
    add_items(it, "w1_macaron", pt_line(0, -7.5, 0, 7.5, 11), 3, [0, 0])
    add_items(it, "w1_boba_tea", [[-4.8, -3.6], [4.8, -3.6], [-4.2, 3.8], [4.2, 3.8], [-2.5, -1.5], [2.5, -1.5], [-2.5, 1.5], [2.5, 1.5]], 1)
    add_items(it, "w1_donut", [[-6.8, -5.8], [6.8, -5.8], [-6.2, 5.8], [6.2, 5.8], [-4.8, -0.2], [4.8, -0.2], [0, -7.8]], 2)
    add_items(it, "w1_cake", [[-7.6, -7.6], [7.6, -7.6], [0, 8.2], [0, -4.2]], 1)
    emit(13, 1, "Butterfly Wings", "NORMAL", 44, 20, 24, [0, 0],
         {"w1_boba_tea": 7, "w1_donut": 6, "w1_cake": 3}, it,
         [{"kind": "ice", "pos": [0, 3.8]}], [{"pos": [-2.6, 0]}, {"pos": [2.6, 0]}])

    # Lv.14 — Four-Leaf Clover Garden
    it = []
    petals = [(-4.4, -4.8), (4.4, -4.8), (-4.4, 4.8), (4.4, 4.8)]
    for cx, cz in petals:
        add_items(it, "w1_sprinkle", pt_ring(cx, cz, 3.0, 3.0, 14), 3)
        add_items(it, "w1_strawberry", pt_ring(cx, cz, 1.9, 1.9, 9), 1)
        add_items(it, "w1_macaron", pt_ring(cx, cz, 1.0, 1.0, 4), 3)
        add_items(it, "w1_donut", [[cx, cz], [cx * 1.45, cz * 1.45]], 2)
    add_items(it, "w1_cake", [[0, -8.5], [0, 8.5], [-7.8, 0], [7.8, 0]], 1)
    emit(14, 1, "Clover Garden", "EASY", 45, 20, 24, [0, 0],
         {"w1_macaron": 12, "w1_donut": 7, "w1_cake": 3}, it,
         [{"kind": "magnet", "pos": [0, -2.5]}, {"kind": "ice", "pos": [0, 2.5]}],
         [{"pos": [-2.2, -2.2]}, {"pos": [2.2, 2.2]}])

    # Lv.15 — HARD · Pinwheel Blades
    it = []
    for arm in range(4):
        ang = arm * math.pi / 2.0
        add_items(it, "w1_sprinkle", pt_spiral(16, 1.8, 8.6, 0.35, ang), 3, [0, 0])
        add_items(it, "w1_gummy_bear", pt_spiral(12, 2.2, 8.4, 0.35, ang + 0.35), 3, [0, 0])
        add_items(it, "w1_boba_tea", pt_spiral(5, 3.0, 7.4, 0.35, ang + 0.18), 1)
        add_items(it, "w1_donut", pt_spiral(3, 4.2, 8.2, 0.35, ang + 0.55), 2)
    add_items(it, "w1_cake", pt_ring(0, 0, 8.6, 9.6, 5, 0.4), 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 4.2, 4.5, 6, 0.25)]
    emit(15, 1, "Pinwheel Blades", "HARD", 38, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 5}, it,
         [{"kind": "ice", "pos": [0, -3.0]}, {"kind": "magnet", "pos": [0, 3.0]}], traps, streak_hint=15)

    # Lv.16 — Hexagon Honeycomb
    it = []
    add_items(it, "w1_sprinkle", pt_ring(0, 0, 8.4, 9.2, 36), 3)
    add_items(it, "w1_strawberry", pt_ring(0, 0, 6.4, 7.0, 24), 1)
    add_items(it, "w1_macaron", pt_ring(0, 0, 4.4, 4.8, 18), 3)
    add_items(it, "w1_boba_tea", pt_ring(0, 0, 2.6, 3.0, 10), 1)
    add_items(it, "w1_donut", pt_ring(0, 0, 5.6, 6.2, 10, 0.3), 2)
    add_items(it, "w1_cake", pt_ring(0, 0, 7.8, 8.6, 6, 0.0), 1)
    add_items(it, "w1_grand_cake", [[0, -10.2], [0, 10.2]], 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 5.0, 5.5, 6, 0.52)]
    emit(16, 1, "Hex Honeycomb", "NORMAL", 42, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 4, "w1_grand_cake": 1}, it,
         [{"kind": "ice", "pos": [-3.4, 0]}, {"kind": "ice", "pos": [3.4, 0]}, {"kind": "magnet", "pos": [0, 4.0]}], traps)

    # Lv.17 — Pyramid Staircase (Bottom Lv.1 -> Top Lv.5!)
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
    emit(17, 1, "Sweet Pyramid", "NORMAL", 42, 22, 26, [0, 10.6],
         {"w1_boba_tea": 9, "w1_cake": 4, "w1_grand_cake": 2}, it,
         [{"kind": "ice", "pos": [-7.0, 4.5]}, {"kind": "magnet", "pos": [7.0, -1.0]}], traps)

    # Lv.18 — Figure-8 Infinity Track
    it = []
    add_items(it, "w1_sprinkle", pt_figure8(44, 8.2, 8.8), 3, [0, 0])
    add_items(it, "w1_gummy_bear", pt_figure8(32, 6.6, 7.0), 3, [0, 0])
    add_items(it, "w1_macaron", pt_figure8(20, 5.0, 5.2), 3, [0, 0])
    add_items(it, "w1_donut", pt_ring(-4.8, 0, 2.6, 3.8, 5) + pt_ring(4.8, 0, 2.6, 3.8, 5), 2)
    add_items(it, "w1_cake", [[-8.0, -7.8], [8.0, -7.8], [-8.0, 7.8], [8.0, 7.8]], 1)
    add_items(it, "w1_grand_cake", [[0, -9.8], [0, 9.8]], 1)
    traps = [{"pos": [0, -2.5]}, {"pos": [0, 2.5]}, {"pos": [-4.8, 0]}, {"pos": [4.8, 0]}, {"pos": [-4.8, -5.8]}, {"pos": [4.8, 5.8]}, {"pos": [0, -6.2]}]
    emit(18, 1, "Infinity Track", "NORMAL", 42, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 4, "w1_grand_cake": 2}, it,
         [{"kind": "ice", "pos": [-7.5, 0]}, {"kind": "magnet", "pos": [7.5, 0]}], traps)

    # Lv.19 — HARD · Fortress Corners
    it = []
    add_items(it, "w1_sprinkle", pt_grid(0, 0, 7, 5, 1.3, 1.3), 3, [0, 0])
    add_items(it, "w1_strawberry", pt_rect_outline(0, 0, 5.2, 5.8, 8), 1)
    add_items(it, "w1_boba_tea", pt_rect_outline(0, 0, 6.8, 7.6, 6), 1)
    add_items(it, "w1_macaron", pt_ring(0, 0, 3.6, 4.0, 14), 3)
    add_items(it, "w1_donut", [[-8.2, -5.0], [8.2, -5.0], [-8.2, 5.0], [8.2, 5.0], [-4.5, -9.5], [4.5, -9.5], [-4.5, 9.5], [4.5, 9.5], [0, -7.2], [0, 7.2]], 2)
    add_items(it, "w1_cake", [[-8.4, -9.8], [8.4, -9.8], [-8.4, 9.8], [8.4, 9.8], [0, -10.4]], 1)
    add_items(it, "w1_grand_cake", [[-8.4, 0], [8.4, 0]], 1)
    traps = [{"pos": p} for p in pt_rect_outline(0, 0, 6.0, 6.6, 3)]  # 8 traps ringing the fortress!
    emit(19, 1, "Fortress Corners", "HARD", 38, 22, 26, [0, 0],
         {"w1_donut": 8, "w1_cake": 4, "w1_grand_cake": 2}, it,
         [{"kind": "ice", "pos": [0, -3.2]}, {"kind": "magnet", "pos": [0, 3.2]}], traps, streak_hint=19)

    # Lv.20 — SUPER HARD CLIFF · Grand Bakery Crown (World 1 Finale!)
    it = []
    # Crown base + 3 towering jewel peaks guarded by 12 bubblegum traps!
    add_items(it, "w1_sprinkle", pt_grid(0, 9.2, 11, 3, 1.8, 1.2) + pt_line(-9.5, 6.0, 9.5, 6.0, 16), 3, [0, 9.2])
    add_items(it, "w1_strawberry", pt_grid(-7.5, 3.2, 4, 3, 1.3, 1.3) + pt_grid(7.5, 3.2, 4, 3, 1.3, 1.3), 1)
    add_items(it, "w1_gummy_bear", pt_grid(0, 3.2, 5, 3, 1.4, 1.3), 3)
    add_items(it, "w1_macaron", pt_line(-9.5, 0, -5.0, -8.5, 7) + pt_line(0, 0, 0, -9.5, 7) + pt_line(9.5, 0, 5.0, -8.5, 7), 3)
    add_items(it, "w1_boba_tea", pt_ring(0, -1.5, 6.5, 5.0, 14), 1)
    add_items(it, "w1_donut", pt_line(-9.2, -3.5, 9.2, -3.5, 8) + [[-4.5, -7.2], [4.5, -7.2]], 2)
    add_items(it, "w1_cake", [[-9.2, -8.5], [9.2, -8.5], [-4.4, -9.2], [4.4, -9.2], [0, -6.2]], 1)
    add_items(it, "w1_grand_cake", [[-7.6, -11.4], [0.0, -11.8], [7.6, -11.4]], 1)
    traps = (
        [{"pos": p} for p in pt_line(-8.5, 0.5, 8.5, 0.5, 5)] +
        [{"pos": p} for p in pt_line(-7.2, -4.8, 7.2, -4.8, 4)] +
        [{"pos": [-4.2, -8.6]}, {"pos": [0.0, -8.8]}, {"pos": [4.2, -8.6]}]
    )
    emit(20, 1, "Bakery Crown", "SUPER_HARD", 36, 24, 28, [0, 9.8],
         {"w1_donut": 8, "w1_cake": 4, "w1_grand_cake": 3}, it,
         [{"kind": "ice", "pos": [-6.5, 6.5]}, {"kind": "magnet", "pos": [6.5, 6.5]}], traps, streak_hint=99)

    # =========================================================================
    # WORLD 2: GACHA TOYBOX (Lv.21 - Lv.30) — Butter-Yellow Vinyl + Rubber Band Walls!
    # =========================================================================

    # Lv.21 — Toybox Welcome Mosaic (Fresh World 2 ASMR Intro!)
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

    # Lv.23 — Retro Arcade Alley
    it = []
    add_items(it, "w2_block", pt_grid(-5.6, 0, 3, 10, 1.3, 1.7) + pt_grid(5.6, 0, 3, 10, 1.3, 1.7), 4)
    add_items(it, "w2_duck", pt_line(-2.2, -8.0, -2.2, 8.0, 9) + pt_line(2.2, -8.0, 2.2, 8.0, 9), 1, [0, 0])
    add_items(it, "w2_figurine", pt_line(0, -8.5, 0, 8.5, 9), 3, [0, 0])
    add_items(it, "w2_arcade", pt_line(-7.8, -6.5, -7.8, 6.5, 5) + pt_line(7.8, -6.5, 7.8, 6.5, 5), 1)
    add_items(it, "w2_unicorn", [[0, -9.4], [-4.5, -9.4], [4.5, -9.4], [0, 9.4]], 1)
    emit(23, 2, "Arcade Alley", "NORMAL", 44, 20, 24, [0, 0],
         {"w2_arcade": 8, "w2_unicorn": 4}, it,
         [{"kind": "magnet", "pos": [0, 4.0]}], [{"pos": [-2.2, -3.0]}, {"pos": [2.2, 3.0]}])

    # Lv.24 — Unicorn Star Parade
    it = []
    add_items(it, "w2_block", pt_star(5, 8.0, 3.6, 8), 4, [0, 0])
    add_items(it, "w2_duck", pt_ring(0, 0, 3.2, 3.2, 14), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 5.4, 5.8, 12, 0.3), 3)
    add_items(it, "w2_arcade", pt_ring(0, 0, 6.6, 7.2, 8, 0.0), 1)
    add_items(it, "w2_unicorn", pt_ring(0, 0, 8.2, 8.8, 5, -math.pi / 2.0), 1)
    emit(24, 2, "Unicorn Star", "NORMAL", 44, 20, 24, [0, 0],
         {"w2_figurine": 10, "w2_arcade": 6, "w2_unicorn": 4}, it,
         [{"kind": "ice", "pos": [0, -3.5]}, {"kind": "magnet", "pos": [0, 3.5]}],
         [{"pos": [-3.4, -2.0]}, {"pos": [3.4, 2.0]}])

    # Lv.25 — HARD · Gacha Spiral Pinch
    it = []
    add_items(it, "w2_block", pt_spiral(44, 2.0, 9.0, 2.2, 0.0) + pt_spiral(36, 2.2, 8.8, 2.0, math.pi), 4, [0, 0])
    add_items(it, "w2_duck", pt_spiral(18, 2.8, 8.2, 1.8, 0.8), 1)
    add_items(it, "w2_figurine", pt_spiral(14, 3.2, 8.0, 1.6, 2.4), 3)
    add_items(it, "w2_arcade", pt_ring(0, 0, 6.2, 7.2, 10, 0.2), 1)
    add_items(it, "w2_unicorn", pt_ring(0, 0, 8.5, 9.5, 6, 0.5), 1)
    traps = [{"pos": p} for p in pt_ring(0, 0, 4.6, 5.2, 6, 0.3)]
    emit(25, 2, "Gacha Spiral", "HARD", 38, 22, 26, [0, 0],
         {"w2_arcade": 8, "w2_unicorn": 5}, it,
         [{"kind": "ice", "pos": [-3.0, -3.0]}, {"kind": "magnet", "pos": [3.0, 3.0]}], traps, streak_hint=25)

    # Lv.26 — Rubber Band S-Slalom (Wide navigable S-curve doorways >= 6.0m!)
    it = []
    add_items(it, "w2_block", pt_grid(0, 8.5, 9, 3, 1.8, 1.3) + pt_grid(0, 0, 9, 2, 1.8, 1.4) + pt_grid(0, -8.5, 9, 2, 1.8, 1.4), 4, [0, 8.5])
    add_items(it, "w2_duck", pt_line(-8.2, 4.2, 8.2, 4.2, 10) + pt_line(-8.2, -4.2, 8.2, -4.2, 10), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 5.2, 5.2, 12), 3)
    add_items(it, "w2_arcade", [[-7.5, -1.8], [0, -1.8], [7.5, -1.8], [-7.5, -6.5], [0, -6.5], [7.5, -6.5], [-7.5, 2.0], [7.5, 2.0]], 1)
    add_items(it, "w2_unicorn", [[-7.2, -9.8], [0, -10.0], [7.2, -9.8], [0, 2.5]], 1)
    add_items(it, "w2_golden_gacha", [[0, -10.8]], 1)
    walls = [
        {"pos": [-4.2, 4.2], "rot_deg": 0.0},
        {"pos": [4.2, -0.5], "rot_deg": 0.0},
        {"pos": [-4.2, -5.2], "rot_deg": 0.0},
    ]
    traps = [{"pos": [6.5, 4.2]}, {"pos": [-6.5, -0.5]}, {"pos": [6.5, -5.2]}]
    emit(26, 2, "Rubber S-Slalom", "NORMAL", 42, 22, 26, [0, 9.5],
         {"w2_arcade": 7, "w2_unicorn": 3, "w2_golden_gacha": 1}, it,
         [{"kind": "magnet", "pos": [5.5, 7.0]}, {"kind": "ice", "pos": [-5.5, -2.5]}], traps, walls)

    # Lv.27 — Twin Toy Vaults (Generous 7.2m center gate + 5.2m outer flanks + 6.4m vault foyer!)
    it = []
    add_items(it, "w2_block", pt_grid(0, 7.8, 10, 3, 1.9, 1.3) + pt_grid(0, 1.4, 6, 3, 1.9, 1.4), 4, [0, 8.8])
    add_items(it, "w2_duck", pt_ring(-6.6, -6.4, 3.2, 3.4, 10) + pt_ring(6.6, -6.4, 3.2, 3.4, 10), 1)
    add_items(it, "w2_figurine", pt_line(-9.0, 3.2, 9.0, 3.2, 12), 3)
    add_items(it, "w2_arcade", [[-7.2, -3.2], [-7.2, -9.2], [7.2, -3.2], [7.2, -9.2], [-2.8, -5.2], [2.8, -5.2], [-9.0, 0.4], [9.0, 0.4]], 1)
    add_items(it, "w2_unicorn", [[-9.2, -6.4], [9.2, -6.4], [-3.8, -10.2], [3.8, -10.2]], 1)
    add_items(it, "w2_golden_gacha", [[-6.6, -6.6], [6.6, -6.6]], 1)
    walls = [
        {"pos": [-5.2, -0.6], "rot_deg": 0.0},
        {"pos": [5.2, -0.6], "rot_deg": 0.0},
        {"pos": [0.0, -7.8], "rot_deg": 90.0},
    ]
    traps = [{"pos": [-2.2, -0.6]}, {"pos": [2.2, -0.6]}, {"pos": [-6.6, -10.2]}, {"pos": [6.6, -10.2]}, {"pos": [0, 4.2]}]
    emit(27, 2, "Twin Toy Vaults", "NORMAL", 42, 24, 26, [0, 9.4],
         {"w2_arcade": 7, "w2_unicorn": 3, "w2_golden_gacha": 2}, it,
         [{"kind": "ice", "pos": [0, 1.2]}, {"kind": "magnet", "pos": [-6.4, 5.8]}], traps, walls)

    # Lv.28 — Cross-Wall Pinwheel Maze (Wide 6.8m center & outer gaps!)
    it = []
    add_items(it, "w2_block", pt_grid(-5.8, -6.2, 4, 4, 1.5, 1.5) + pt_grid(5.8, -6.2, 4, 4, 1.5, 1.5) +
              pt_grid(-5.8, 6.2, 4, 4, 1.5, 1.5) + pt_grid(5.8, 6.2, 4, 4, 1.5, 1.5), 4)
    add_items(it, "w2_duck", pt_ring(0, 0, 7.8, 8.8, 18), 1)
    add_items(it, "w2_figurine", pt_ring(0, 0, 3.2, 3.6, 12), 3)
    add_items(it, "w2_arcade", [[-7.4, -2.8], [7.4, -2.8], [-7.4, 2.8], [7.4, 2.8], [-3.0, -8.6], [3.0, -8.6], [-3.0, 8.6], [3.0, 8.6]], 1)
    add_items(it, "w2_unicorn", [[-8.6, -9.0], [8.6, -9.0], [-8.6, 9.0], [8.6, 9.0]], 1)
    add_items(it, "w2_golden_gacha", [[0, -10.4], [0, 10.4]], 1)
    walls = [
        {"pos": [-5.2, 0.0], "rot_deg": 0.0},
        {"pos": [5.2, 0.0], "rot_deg": 0.0},
        {"pos": [0.0, -6.2], "rot_deg": 90.0},
        {"pos": [0.0, 6.2], "rot_deg": 90.0},
    ]
    traps = [{"pos": [-2.4, -2.4]}, {"pos": [2.4, -2.4]}, {"pos": [-2.4, 2.4]}, {"pos": [2.4, 2.4]}, {"pos": [-8.2, 0]}, {"pos": [8.2, 0]}]
    emit(28, 2, "Cross-Wall Maze", "NORMAL", 42, 24, 26, [0, 0],
         {"w2_arcade": 7, "w2_unicorn": 4, "w2_golden_gacha": 2}, it,
         [{"kind": "ice", "pos": [0, -2.6]}, {"kind": "magnet", "pos": [0, 2.6]}], traps, walls)

    # Lv.29 — HARD · Golden Runway (Wide navigable corridors >= 6.4m!)
    it = []
    add_items(it, "w2_block", pt_grid(0, 9.2, 10, 3, 1.9, 1.3) + pt_line(-8.8, 6, -8.8, -8, 14) + pt_line(8.8, 6, 8.8, -8, 14), 4, [0, 9.2])
    add_items(it, "w2_duck", pt_line(-4.2, 6.0, -4.2, -6.0, 9) + pt_line(4.2, 6.0, 4.2, -6.0, 9), 1)
    add_items(it, "w2_figurine", pt_line(0, 6.0, 0, -6.0, 11), 3)
    add_items(it, "w2_arcade", pt_line(-8.4, -3.5, 8.4, -3.5, 7) + [[-6.8, 2.0], [6.8, 2.0], [0, -8.0]], 1)
    add_items(it, "w2_unicorn", [[-8.6, -9.5], [8.6, -9.5], [-4.2, -8.4], [4.2, -8.4], [0, -1.8]], 1)
    add_items(it, "w2_golden_gacha", [[-5.2, -10.8], [5.2, -10.8]], 1)
    walls = [
        {"pos": [-5.4, 1.5], "rot_deg": 90.0},
        {"pos": [5.4, 1.5], "rot_deg": 90.0},
        {"pos": [0.0, -5.8], "rot_deg": 0.0},
    ]
    traps = [
        {"pos": [-7.6, 3.0]}, {"pos": [7.6, 3.0]}, {"pos": [0, 3.0]},
        {"pos": [-7.6, -1.5]}, {"pos": [7.6, -1.5]}, {"pos": [0, -1.5]},
        {"pos": [-5.6, -6.8]}, {"pos": [5.6, -6.8]},
    ]
    emit(29, 2, "Golden Runway", "HARD", 38, 24, 26, [0, 9.8],
         {"w2_arcade": 8, "w2_unicorn": 4, "w2_golden_gacha": 2}, it,
         [{"kind": "ice", "pos": [-6.4, 7.0]}, {"kind": "magnet", "pos": [6.4, 7.0]}], traps, walls, streak_hint=149)

    # Lv.30 — SUPER HARD CLIFF · 199-Streak Gacha Hell! (Wide 7.0m center lane + 5.1m side lanes — hard but 100% passable!)
    it = []
    add_items(it, "w2_block", pt_grid(0, 9.6, 11, 3, 1.9, 1.2) + pt_grid(-8.4, 2.2, 3, 6, 1.3, 1.4) + pt_grid(8.4, 2.2, 3, 6, 1.3, 1.4), 4, [0, 9.6])
    add_items(it, "w2_duck", pt_ring(0, 2.0, 5.2, 4.6, 16) + pt_line(-8.5, -5.0, 8.5, -5.0, 10), 1)
    add_items(it, "w2_figurine", pt_ring(0, -1.2, 7.2, 5.5, 16), 3)
    add_items(it, "w2_arcade", pt_ring(0, -2.5, 8.8, 7.2, 10, 0.25), 1)
    add_items(it, "w2_unicorn", [[-9.2, -8.5], [9.2, -8.5], [-4.4, -7.2], [4.4, -7.2], [0, -4.0], [0, -8.8]], 1)
    add_items(it, "w2_golden_gacha", [[-8.2, -11.4], [0.0, -11.8], [8.2, -11.4]], 1)
    walls = [
        {"pos": [-5.2, 5.4], "rot_deg": 0.0},
        {"pos": [5.2, 5.4], "rot_deg": 0.0},
        {"pos": [-5.2, -6.2], "rot_deg": 0.0},
        {"pos": [5.2, -6.2], "rot_deg": 0.0},
    ]
    traps = [
        {"pos": [0.0, 5.4]}, {"pos": [-9.2, 5.4]}, {"pos": [9.2, 5.4]},
        {"pos": [-4.8, 2.0]}, {"pos": [0.0, 1.8]}, {"pos": [4.8, 2.0]},
        {"pos": [-7.5, -1.6]}, {"pos": [-2.5, -1.6]}, {"pos": [2.5, -1.6]}, {"pos": [7.5, -1.6]},
        {"pos": [0.0, -6.2]}, {"pos": [-9.2, -6.2]}, {"pos": [9.2, -6.2]},
        {"pos": [0.0, -9.2]},
    ]
    emit(30, 2, "199-Streak Gacha Hell", "SUPER_HARD", 36, 24, 28, [0, 10.2],
         {"w2_arcade": 7, "w2_unicorn": 5, "w2_golden_gacha": 3}, it,
         [{"kind": "ice", "pos": [0, 7.6]}], traps, walls, streak_hint=199)

    print(f"Generated ALL {len(levels)} sculptural levels (World 1 Lv.1-20 & World 2 Lv.21-30):")
    for row in levels:
        num, w, nm, tg, dur, ni, nt, nw, xa, xr = row
        print(f"  Lv.{num:02d} W{w} | {nm:22s} | {tg:10s} | {dur:2.0f}s | items={ni:3d} gums={nt:2d} walls={nw} | XP={xa:4d}/{xr}")


if __name__ == "__main__":
    build_all()
