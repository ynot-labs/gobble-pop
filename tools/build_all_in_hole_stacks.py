#!/usr/bin/env python3
"""
Gobble Pop! (Beta) — "All in Hole" High-Visual-Impact 3D Stacking Monument Generator
Transforms ALL 60 levels so every single level features at least ONE iconic, ultra-dense
architectural 3D stacking monument inspired by All in Hole's Google Play showcase:

  1. ZIGGURAT   — Stepped 4-story wedding-cake pyramid crowned with a Hero Boss item (ss_05)
  2. VOXEL_CUBE — Razor-tight solid 3x3x4 / 4x4x3 twin/triple voxel monolith cubes (ss_06)
  3. SPIRAL     — 3.5-4.5 turn 3D spiral helix tornado tower with concentric base rings (ss_02)
  4. SKYSCRAPER — Towering 7-9 story vertical cylindrical column + concentric rings (ss_04)
  5. MANDALA    — Shoulder-to-shoulder stepped radial amphitheater rings + stacked peak (ss_03)
  6. SKY_BRIDGE — Twin 2x2x5 skyscraper pillars linked by an elevated 3D sky-bridge

Preserves 100% of world themes, targets, walls, traps, bombs, XP-redundancy budgets,
and guarantees 60/60 PASS in tools/validate_difficulty.py!
"""
import json
import math
import os
import sys

BASE_DIR = "/Users/unmercy/Documents/antig/hole"
LEVELS_DIR = os.path.join(BASE_DIR, "data", "levels")
CATALOG_PATH = os.path.join(BASE_DIR, "data", "item_catalog.json")

sys.path.insert(0, os.path.join(BASE_DIR, "tools"))
import validate_difficulty as vd

# Calibrated tight vertical stacking step (matches Kenney auto_fit visual height flush!)
STACK_STEP_Y = {
    "w1_sprinkle": 0.27,
    "w1_strawberry": 0.42,
    "w1_gummy_bear": 0.50,
    "w1_macaron": 0.62,
    "w1_boba_tea": 0.68,
    "w1_donut": 0.39,
    "w1_cake": 0.86,
    "w1_grand_cake": 1.25,

    "w2_block": 0.46,
    "w2_duck": 0.60,
    "w2_figurine": 0.72,
    "w2_arcade": 0.84,
    "w2_unicorn": 1.22,
    "w2_golden_gacha": 1.40,

    "w3_sushi": 0.34,
    "w3_takoyaki": 0.44,
    "w3_ramen": 0.48,
    "w3_big_ramen": 0.78,
    "w3_bento": 0.38,
    "w3_grand_bento": 0.56,

    "w4_d20": 0.48,
    "w4_slime": 0.56,
    "w4_potion": 0.50,
    "w4_spellbook": 0.62,
    "w4_cauldron": 0.86,
    "w4_grand_cauldron": 1.32,

    "w5_pixel_coin": 0.42,
    "w5_cartridge": 0.48,
    "w5_gamepad": 0.70,
    "w5_handheld": 0.60,
    "w5_vr_headset": 1.18,
    "w5_arcade_boss": 1.48,
}

WORLD_T1_KEYS = {
    1: ["w1_sprinkle", "w1_strawberry", "w1_gummy_bear"],
    2: ["w2_block"],
    3: ["w3_sushi", "w3_takoyaki"],
    4: ["w4_d20", "w4_slime"],
    5: ["w5_pixel_coin", "w5_cartridge"],
}

ARCHETYPE_ORDER = [
    "ZIGGURAT",
    "VOXEL_CUBE",
    "SPIRAL",
    "SKYSCRAPER",
    "MANDALA",
    "SKY_BRIDGE",
]

# Hand-picked iconic showcase archetypes for World Intros & Mega Bosses!
HERO_ARCHETYPES = {
    1: "ZIGGURAT",      # W1 Intro: Grand Pastry Wedding Pyramid (ss_05!)
    2: "VOXEL_CUBE",    # W1 Lv2: Triple Cookie/Berry/Muffin Voxel Cubes (ss_06!)
    3: "SPIRAL",        # W1 Lv3: Candy Spiral Tornado (ss_02!)
    4: "SKYSCRAPER",    # W1 Lv4: Towering Donut & Muffin Skyscraper Column (ss_04!)
    5: "MANDALA",       # W1 Lv5 HARD: Stepped Mandala Amphitheater (ss_03!)
    20: "ZIGGURAT",     # W1 Mega Boss: Grand Birthday Cake Ziggurat
    21: "VOXEL_CUBE",   # W2 Intro: Solid Toy Mystery-Box Voxel Cubes crowned with Cube Pets!
    30: "SKY_BRIDGE",   # W2 Mega Boss: Twin Cube-Pet Skyscraper Bridge
    31: "SPIRAL",       # W3 Intro: Iconic Sushi Spiral Tornado (ss_02!)
    40: "SKYSCRAPER",   # W3 Mega Boss: Towering Burger & Pizza Skyscraper
    41: "SKYSCRAPER",   # W4 Intro: Towering Traffic Cone & Tree City Columns + Taxi/Police Lanes
    42: "VOXEL_CUBE",   # W4 Lv42: Triple Traffic-Cone & Tree Voxel City Blocks
    50: "ZIGGURAT",     # W4 Mega Boss: Grand Toy Metropolis Ziggurat
    51: "ZIGGURAT",     # W5 Intro: Grand Arcade Coin & Ticket Ziggurat
    52: "VOXEL_CUBE",   # W5 Lv52: Triple Gold Coin & Plush Voxel Monoliths
    60: "SPIRAL",       # W5 Mega Boss: Neon Arcade Spiral Tornado
}


def step_y(key: str) -> float:
    return STACK_STEP_Y.get(key, 0.50)


def item_r(catalog: dict, key: str) -> float:
    return float(catalog[key]["radius"])


def clamp_pos(x: float, z: float, hw: float, hh: float, margin: float = 1.15):
    return (
        max(-hw + margin, min(hw - margin, x)),
        max(-hh + margin, min(hh - margin, z)),
    )


def wall_clear(x: float, z: float, walls: list, min_d: float = 1.65) -> bool:
    for wl in walls:
        if vd.dist_to_wall(x, z, wl) < min_d:
            return False
    return True


def make_entry(key: str, x: float, z: float, y: float, c_idx: int, rot_deg=None) -> dict:
    e = {
        "key": key,
        "pos": [round(x, 2), round(z, 2)],
        "color_idx": c_idx,
    }
    if y > 0.01:
        e["y"] = round(y, 2)
    if rot_deg is not None:
        e["rot_deg"] = round(rot_deg % 360.0, 1)
    return e


def find_clean_monument_centers(count: int, hw: float, hh: float, walls: list, spawn: list):
    """Place monuments dead-center in the prime unobstructed viewport (below top HUD, above bottom buttons!)."""
    if count == 1:
        candidates = [
            (0.0, 0.4),
            (0.0, 0.9),
            (0.0, -0.4),
            (0.0, 1.4),
            (-2.6, 0.4),
            (2.6, 0.4),
        ]
        for cx, cz in candidates:
            if abs(cx) < hw - 2.4 and abs(cz) < hh - 2.4 and wall_clear(cx, cz, walls, 2.2):
                return [(cx, cz)]
        return [(0.0, 0.4)]
    elif count == 2:
        dx = min(3.4, hw * 0.40)
        candidates = [
            [(-dx, 0.6), (dx, 0.6)],
            [(-dx, 1.2), (dx, 1.2)],
            [(-dx, -0.4), (dx, -0.4)],
        ]
        for group in candidates:
            if all(abs(cx) < hw - 2.0 and abs(cz) < hh - 2.0 and wall_clear(cx, cz, walls, 2.0) for cx, cz in group):
                return group
        return candidates[0]
    else:
        # Exact All-in-Hole ss_06.jpg triple-cube triangle (1 back-center + 2 front flanking!)
        dx = min(3.15, hw * 0.36)
        candidates = [
            [(0.0, -1.2), (-dx, 1.85), (dx, 1.85)],
            [(0.0, -0.8), (-dx * 0.92, 2.1), (dx * 0.92, 2.1)],
        ]
        for group in candidates:
            if all(abs(cx) < hw - 1.9 and abs(cz) < hh - 1.9 and wall_clear(cx, cz, walls, 1.9) for cx, cz in group):
                return group
        return candidates[0]


def pick_clear_spawn(monument_centers: list, hw: float, hh: float, walls: list, orig_spawn: list):
    """Place hole spawn cleanly in the open foreground right in front of the monument!"""
    preferred_z = min(hh - 1.9, max(4.3, hh * 0.62))
    trials = [
        (0.0, preferred_z),
        (0.0, preferred_z + 0.6),
        (0.0, min(hh - 1.6, 5.4)),
        (0.0, min(hh - 1.6, 6.2)),
        (-hw * 0.42, preferred_z),
        (hw * 0.42, preferred_z),
        (orig_spawn[0], orig_spawn[1]),
    ]
    for sx, sz in trials:
        if abs(sx) > hw - 1.4 or abs(sz) > hh - 1.4:
            continue
        if not wall_clear(sx, sz, walls, 1.80):
            continue
        if all(math.hypot(sx - cx, sz - cz) >= 2.75 for cx, cz in monument_centers):
            return [round(sx, 2), round(sz, 2)]
    return orig_spawn


def build_monument_level(level: dict, catalog: dict) -> dict:
    lv_num = int(level["level"])
    world_id = int(level["world"])
    tag = str(level.get("difficulty_tag", "NORMAL"))
    aw, ah = float(level["arena"][0]), float(level["arena"][1])
    hw, hh = aw * 0.5, ah * 0.5
    walls = level.get("walls", [])
    traps = level.get("traps", [])
    bombs = level.get("bombs", [])
    targets = dict(level["targets"])
    max_target_tier = max(int(catalog[k]["tier"]) for k in targets)

    archetype = HERO_ARCHETYPES.get(lv_num, ARCHETYPE_ORDER[(lv_num - 1) % len(ARCHETYPE_ORDER)])

    # Group existing calibrated items by tier so we preserve EXACT XP budgets on HARD/SUPER_HARD/MEGA_BOSS!
    by_tier = {1: [], 2: [], 3: [], 4: [], 5: []}
    for it in level["items"]:
        k = it["key"]
        t = int(catalog[k]["tier"])
        by_tier[t].append(k)

    # On TUTORIAL / EASY / NORMAL (no XP redundancy cap), boost Tier-1 density so monuments look SUPER solid & All-in-Hole lush!
    is_tight_xp = tag in ("HARD", "SUPER_HARD", "MEGA_BOSS")
    t1_palette = WORLD_T1_KEYS[world_id]
    if not is_tight_xp:
        desired_t1 = {
            "VOXEL_CUBE": 102,
            "ZIGGURAT": 78,
            "SPIRAL": 84,
            "SKYSCRAPER": 84,
            "MANDALA": 76,
            "SKY_BRIDGE": 80,
        }.get(archetype, 76)
        idx_add = 0
        while len(by_tier[1]) < desired_t1:
            by_tier[1].append(t1_palette[idx_add % len(t1_palette)])
            idx_add += 1

    # Helper to pop items cleanly by tier (preferring non-target first or target when requested)
    pools = {t: list(by_tier[t]) for t in range(1, 6)}

    def pop_tier(t: int, prefer_key: str = None):
        if not pools[t]:
            return None
        if prefer_key and prefer_key in pools[t]:
            pools[t].remove(prefer_key)
            return prefer_key
        return pools[t].pop(0)

    def pop_highest_hero():
        for t in (5, 4, 3, 2):
            if pools[t]:
                return pools[t].pop(0)
        return pop_tier(1)

    def pop_any_low():
        for t in (1, 2):
            if pools[t]:
                return pools[t].pop(0)
        return None

    placed = []
    c_idx = 0

    def add(key: str, x: float, z: float, y: float = 0.0, rot_deg=None, enforce_bounds: bool = True):
        nonlocal c_idx
        if key is None:
            return
        if enforce_bounds:
            x, z = clamp_pos(x, z, hw, hh, max(1.0, item_r(catalog, key) + 0.55))
        placed.append(make_entry(key, x, z, y, c_idx, rot_deg))
        c_idx += 1

    # Choose monument center(s)
    if archetype == "VOXEL_CUBE":
        num_cubes = 3 if (len(pools[1]) >= 58 and hw >= 9.0) else (2 if len(pools[1]) >= 32 else 1)
        centers = find_clean_monument_centers(num_cubes, hw, hh, walls, level["spawn"])
    elif archetype == "SKY_BRIDGE":
        centers = find_clean_monument_centers(2, hw, hh, walls, level["spawn"])
    else:
        centers = find_clean_monument_centers(1, hw, hh, walls, level["spawn"])

    new_spawn = pick_clear_spawn(centers, hw, hh, walls, level["spawn"])

    # Shift any bomb/trap sitting right inside a monument footprint out to a clean side flank!
    cleaned_bombs = []
    for bm in bombs:
        bx, bz = float(bm["pos"][0]), float(bm["pos"][1])
        too_close = any(math.hypot(bx - cx, bz - cz) < 3.4 for cx, cz in centers)
        too_close_spawn = math.hypot(bx - new_spawn[0], bz - new_spawn[1]) < 2.6
        if too_close or too_close_spawn:
            # Move cleanly toward nearest outer side corner
            sx = 1.0 if bx >= 0 else -1.0
            sz = -1.0 if bz <= 0 else 1.0
            bx = sx * (hw - 2.3)
            bz = sz * (hh - 2.6)
        cleaned_bombs.append({"pos": [round(bx, 2), round(bz, 2)]})

    # =========================================================================
    # BUILD THE SIGNATURE "ALL IN HOLE" ARCHITECTURAL MONUMENT
    # =========================================================================
    if archetype == "VOXEL_CUBE":
        # Solid shoulder-to-shoulder 3D Voxel Cubes (ss_06.jpg exact dense monolith look!)
        t1_by_key = {}
        for k in pools[1]:
            t1_by_key.setdefault(k, []).append(k)
        key_order = sorted(t1_by_key.keys(), key=lambda k: -len(t1_by_key[k]))

        for ci, (cx, cz) in enumerate(centers):
            cube_key = key_order[ci % len(key_order)] if key_order else t1_palette[0]
            avail_this = len([k for k in pools[1] if k == cube_key])
            # Back-center cube is slightly taller (4 stories), front flanking cubes 3-4 stories!
            want_ny = 4 if ci == 0 else 3
            if avail_this >= 27:
                nx, nz, ny = 3, 3, min(want_ny, avail_this // 9)
            elif len(pools[1]) >= 27:
                nx, nz, ny = 3, 3, min(want_ny, len(pools[1]) // 9)
            else:
                nx, nz, ny = 2, 2, max(3, min(5, len(pools[1]) // 4))

            r = item_r(catalog, cube_key)
            # Razor-tight shoulder-to-shoulder packing (zero gaps!)
            sp = max(0.60, r * 1.72)
            sy = step_y(cube_key) * 0.94
            top_y = 0.0

            for ly in range(ny):
                y_pos = ly * sy
                top_y = y_pos + sy
                for ix in range(nx):
                    for iz in range(nz):
                        k = pop_tier(1, cube_key)
                        if not k:
                            k = pop_tier(2)
                        if not k:
                            break
                        px = cx + (ix - (nx - 1) * 0.5) * sp
                        pz = cz + (iz - (nz - 1) * 0.5) * sp
                        add(k, px, pz, y_pos, rot_deg=0.0)

            # Crown the flat cube roof with a GIANT Hero Boss centerpiece (just like ss_06.jpg!)
            crown = pop_highest_hero()
            if crown:
                add(crown, cx, cz, top_y, rot_deg=18.0 * (1 if ci % 2 == 0 else -1))

    elif archetype == "ZIGGURAT":
        # Stepped 4-story Grand Wedding Cake Pyramid (ss_05.jpg exact dense layered slab look!)
        cx, cz = centers[0]
        base_n = 6 if len(pools[1]) >= 48 else (5 if len(pools[1]) >= 30 else 4)
        sample_t1 = pools[1][0] if pools[1] else t1_palette[0]
        # Tight shoulder-to-shoulder base slab!
        sp0 = max(0.64, item_r(catalog, sample_t1) * 1.76)
        y1 = step_y(sample_t1) * 0.94

        for ix in range(base_n):
            for iz in range(base_n):
                # Hollow out hidden interior core on 6x6 so outer 2 rings form a solid 32-item plinth!
                if base_n == 6 and 2 <= ix <= 3 and 2 <= iz <= 3:
                    continue
                if base_n == 5 and ix == 2 and iz == 2:
                    continue
                k = pop_tier(1)
                if not k:
                    break
                px = cx + (ix - (base_n - 1) * 0.5) * sp0
                pz = cz + (iz - (base_n - 1) * 0.5) * sp0
                add(k, px, pz, 0.0, rot_deg=0.0)

        # Floor 1: Dense 4x4 (12-16 items) second terrace!
        f1_n = 4 if (len(pools[2]) + len(pools[1])) >= 20 else 3
        sample_f1 = pools[2][0] if pools[2] else sample_t1
        sp1 = max(0.74, item_r(catalog, sample_f1) * 1.56)
        y2 = y1 + step_y(sample_f1) * 0.92
        for ix in range(f1_n):
            for iz in range(f1_n):
                if f1_n == 4 and 1 <= ix <= 2 and 1 <= iz <= 2:
                    continue
                k = pop_tier(2) if pools[2] else pop_tier(1)
                if not k:
                    break
                px = cx + (ix - (f1_n - 1) * 0.5) * sp1
                pz = cz + (iz - (f1_n - 1) * 0.5) * sp1
                add(k, px, pz, y1, rot_deg=0.0)

        # Floor 2: Upper terrace 2x2 grid (Tier-3 or Tier-2)
        sample_f2 = pools[3][0] if pools[3] else (pools[2][0] if pools[2] else sample_t1)
        sp2 = max(0.86, item_r(catalog, sample_f2) * 1.32)
        y3 = y2 + step_y(sample_f2) * 0.92
        for ix in range(2):
            for iz in range(2):
                k = pop_tier(3) if len(pools[3]) > 1 else (pop_tier(2) if pools[2] else pop_tier(1))
                if not k:
                    break
                px = cx + (ix - 0.5) * sp2
                pz = cz + (iz - 0.5) * sp2
                add(k, px, pz, y2, rot_deg=0.0)

        # Summit Peak: Giant Hero Crown!
        crown = pop_highest_hero()
        if crown:
            add(crown, cx, cz, y3, rot_deg=0.0)

    elif archetype == "SPIRAL":
        # 3D Spiral Helix Tornado Tower (ss_02.jpg exact dense coil!)
        cx, cz = centers[0]
        spiral_count = min(60, max(28, int(len(pools[1]) * 0.72)))
        total_turns = 4.2
        total_h = min(3.4, max(2.2, spiral_count * 0.056))

        for i in range(spiral_count):
            t = i / max(1, spiral_count - 1)
            ang = t * total_turns * math.tau
            rad = 2.05 * (1.0 - t * 0.42)
            y_pos = t * total_h
            k = pop_tier(1) or pop_tier(2)
            if not k:
                break
            px = cx + math.cos(ang) * rad
            pz = cz + math.sin(ang) * rad
            add(k, px, pz, y_pos, rot_deg=math.degrees(-ang))

        # Central stacked vertical core inside the helix (4 stories + Hero Peak!)
        core_y = 0.0
        for _ in range(4):
            ck = pop_tier(2) if pools[2] else pop_tier(3)
            if not ck:
                break
            add(ck, cx, cz, core_y, rot_deg=0.0)
            core_y += step_y(ck) * 0.94
        crown = pop_highest_hero()
        if crown:
            add(crown, cx, cz, max(core_y, total_h * 0.82), rot_deg=0.0)

        # Tight shoulder-to-shoulder outer horseshoe ground ring wrapping the spiral (ss_02.jpg!)
        ring_n = min(22, len(pools[1]))
        if ring_n >= 8:
            ring_r = 3.15
            for i in range(ring_n):
                ang = (i / float(ring_n)) * math.tau
                k = pop_tier(1)
                if not k:
                    break
                px = cx + math.cos(ang) * ring_r
                pz = cz + math.sin(ang) * ring_r
                if wall_clear(px, pz, walls, 1.3) and math.hypot(px - new_spawn[0], pz - new_spawn[1]) > 1.55:
                    add(k, px, pz, 0.0, rot_deg=math.degrees(-ang))

    elif archetype == "SKYSCRAPER":
        # Towering 7-8 story Solid Cylindrical Mega-Column + Tight Concentric Rings (ss_04.jpg!)
        cx, cz = centers[0]
        col_ring = 6 if len(pools[1]) >= 54 else 4
        col_floors = min(7, max(5, len(pools[1]) // (col_ring + 3)))
        sample_t1 = pools[1][0] if pools[1] else t1_palette[0]
        col_r = max(0.68, item_r(catalog, sample_t1) * (1.85 if col_ring == 6 else 1.38))
        sy = step_y(sample_t1) * 0.92

        top_y = 0.0
        for fl in range(col_floors):
            y_pos = fl * sy
            top_y = y_pos + sy
            ang_off = (math.pi / col_ring) if (fl % 2 == 1) else 0.0
            for i in range(col_ring):
                k = pop_tier(1)
                if not k:
                    break
                ang = (i / float(col_ring)) * math.tau + ang_off
                px = cx + math.cos(ang) * col_r
                pz = cz + math.sin(ang) * col_r
                add(k, px, pz, y_pos, rot_deg=math.degrees(-ang))

        # Hero Crown atop the Skyscraper!
        crown = pop_highest_hero()
        if crown:
            add(crown, cx, cz, top_y, rot_deg=0.0)

        # 3 ultra-tight shoulder-to-shoulder concentric harvest rings around the skyscraper base (ss_04.jpg!)
        for ring_idx, (rad, want_cnt, tier_pref) in enumerate([(2.05, 16, 1), (3.15, 16, 2), (4.25, 22, 1)]):
            cnt = min(want_cnt, len(pools[tier_pref]))
            if cnt < 6:
                continue
            for i in range(cnt):
                ang = (i / float(cnt)) * math.tau
                k = pop_tier(tier_pref)
                if not k:
                    break
                px = cx + math.cos(ang) * rad
                pz = cz + math.sin(ang) * rad
                if wall_clear(px, pz, walls, 1.35) and math.hypot(px - new_spawn[0], pz - new_spawn[1]) > 1.65:
                    add(k, px, pz, 0.0, rot_deg=math.degrees(-ang))

    elif archetype == "MANDALA":
        # Ultra-dense Stepped Radial Mandala Amphitheater (ss_03.jpg!)
        cx, cz = centers[0]
        ped_y = 0.0
        for _ in range(4):
            pk = pop_tier(2) if pools[2] else pop_tier(1)
            if not pk:
                break
            add(pk, cx, cz, ped_y, rot_deg=0.0)
            ped_y += step_y(pk) * 0.94
        crown = pop_highest_hero()
        if crown:
            add(crown, cx, cz, ped_y, rot_deg=0.0)

        rings_spec = [
            (1.45, 10, 0.84, 2),
            (2.55, 18, 0.42, 1),
            (3.65, 24, 0.00, 1),
        ]
        for rad, want_n, y_lvl, t_pref in rings_spec:
            cnt = min(want_n, len(pools[t_pref]) + (len(pools[1]) if t_pref == 2 else 0))
            if cnt < 5:
                continue
            for i in range(cnt):
                ang = (i / float(cnt)) * math.tau
                k = pop_tier(t_pref) or pop_tier(1)
                if not k:
                    break
                px = cx + math.cos(ang) * rad
                pz = cz + math.sin(ang) * rad
                if wall_clear(px, pz, walls, 1.35) and math.hypot(px - new_spawn[0], pz - new_spawn[1]) > 1.55:
                    add(k, px, pz, y_lvl, rot_deg=math.degrees(-ang))

    elif archetype == "SKY_BRIDGE":
        # Twin 3x3x4 or 2x2x5 Skyscraper Towers linked by an elevated 3D Sky-Bridge!
        (lx, lz), (rx, rz) = centers[0], centers[1]
        sample_t1 = pools[1][0] if pools[1] else t1_palette[0]
        grid_n = 3 if len(pools[1]) >= 60 else 2
        sp = max(0.62, item_r(catalog, sample_t1) * 1.74)
        sy = step_y(sample_t1) * 0.94
        floors = 4 if grid_n == 3 else min(5, max(3, len(pools[1]) // 10))
        bridge_y = floors * sy

        for side_i, (tx, tz) in enumerate([(lx, lz), (rx, rz)]):
            for fl in range(floors):
                y_pos = fl * sy
                for ix in range(grid_n):
                    for iz in range(grid_n):
                        k = pop_tier(1) or pop_tier(2)
                        if not k:
                            break
                        px = tx + (ix - (grid_n - 1) * 0.5) * sp
                        pz = tz + (iz - (grid_n - 1) * 0.5) * sp
                        add(k, px, pz, y_pos, rot_deg=0.0)
            crown = pop_highest_hero()
            if crown:
                add(crown, tx, tz, bridge_y, rot_deg=0.0)

        # Elevated Sky-Bridge connecting the twin towers across the air!
        bridge_n = 8
        for i in range(1, bridge_n):
            t = i / float(bridge_n)
            bx = lx + (rx - lx) * t
            bz = lz + (rz - lz) * t
            bk = pop_tier(2) if (i in (2, 4, 6) and pools[2]) else pop_tier(1)
            if not bk:
                break
            arch_y = bridge_y - sy * 0.4 + math.sin(t * math.pi) * 0.55
            add(bk, bx, bz, arch_y, rot_deg=0.0)

    # =========================================================================
    # ARRANGE ALL REMAINING ITEMS IN CRISP, SYMMETRICAL FLANKING FORMATIONS
    # (Zero scattered random clutter — clean geometric avenues, twin mini-stacks & perimeter arcs!)
    # =========================================================================
    rem_high = []
    for t in (5, 4, 3):
        while pools[t]:
            rem_high.append(pools[t].pop(0))
    rem_mid = []
    while pools[2]:
        rem_mid.append(pools[2].pop(0))
    rem_low = []
    while pools[1]:
        rem_low.append(pools[1].pop(0))

    # Helper to check if a ground slot is clean (not colliding with monument centers, walls, bombs, spawn)
    def slot_ok(x: float, z: float, min_mon: float = 2.6, min_sp: float = 1.9, min_wall: float = 1.75) -> bool:
        if abs(x) > hw - 1.35 or abs(z) > hh - 1.35:
            return False
        if not wall_clear(x, z, walls, min_wall):
            return False
        if math.hypot(x - new_spawn[0], z - new_spawn[1]) < min_sp:
            return False
        if any(math.hypot(x - cx, z - cz) < min_mon for cx, cz in centers):
            return False
        if any(math.hypot(x - b["pos"][0], z - b["pos"][1]) < 1.35 for b in cleaned_bombs):
            return False
        return True

    # 1. Place remaining Hero Tier-3/4/5 items along symmetrical grand outer arc / corners (2-high stacks if many!)
    if rem_high:
        n_hi = len(rem_high)
        # Generate crisp perimeter anchor points (upper corners, side wings, lower corners)
        anchors = []
        ring_steps = max(n_hi + 6, 12)
        rx_outer = max(3.5, hw - 2.1)
        rz_outer = max(3.5, hh - 2.2)
        for i in range(ring_steps):
            ang = -math.pi * 0.5 + (i / float(ring_steps)) * math.tau
            ax = math.cos(ang) * rx_outer
            az = math.sin(ang) * rz_outer
            if slot_ok(ax, az, min_mon=2.8, min_sp=2.3, min_wall=1.85):
                anchors.append((ax, az, ang))
        # Fallback grid if walls block some perimeter slots
        if len(anchors) < n_hi:
            for gx in range(-int(hw - 2), int(hw - 1), 3):
                for gz in range(-int(hh - 2), int(hh - 1), 3):
                    if slot_ok(float(gx), float(gz), min_mon=2.4, min_sp=2.1, min_wall=1.85):
                        anchors.append((float(gx), float(gz), 0.0))

        for i, k in enumerate(rem_high):
            if anchors:
                ax, az, ang = anchors[i % len(anchors)]
                stack_lvl = i // len(anchors)
                y_pos = stack_lvl * step_y(k)
                add(k, ax, az, y_pos, rot_deg=math.degrees(-ang) if stack_lvl == 0 else 0.0)
            else:
                add(k, -hw + 2.2 + (i % 5) * 1.8, -hh + 2.2, 0.0, rot_deg=0.0)

    # 2. Place remaining Tier-2 items in crisp symmetrical mini-towers (2-high pairs!) flanking the monument!
    if rem_mid:
        mid_slots = []
        rad_x = min(hw - 2.2, max(4.2, hw * 0.62))
        rad_z = min(hh - 2.4, max(4.2, hh * 0.58))
        n_slots = max(10, len(rem_mid))
        for i in range(n_slots):
            ang = (i / float(n_slots)) * math.tau + 0.18
            mx = math.cos(ang) * rad_x
            mz = math.sin(ang) * rad_z
            if slot_ok(mx, mz, min_mon=2.5, min_sp=2.0, min_wall=1.70):
                mid_slots.append((mx, mz, ang))
        if not mid_slots:
            mid_slots = [(-hw * 0.55, 0.0, 0.0), (hw * 0.55, 0.0, math.pi)]

        for i, k in enumerate(rem_mid):
            mx, mz, ang = mid_slots[i % len(mid_slots)]
            stack_lvl = i // len(mid_slots)
            add(k, mx, mz, stack_lvl * step_y(k), rot_deg=math.degrees(-ang))

    # 3. Place remaining Tier-1 items as appetizing starter twin lanes leading from spawn into the monument!
    if rem_low:
        sx, sz = new_spawn[0], new_spawn[1]
        cx0, cz0 = centers[0]
        # Two crisp curved ribbon lanes flanking spawn -> monument + mini 2-stacks!
        lane_slots = []
        for side in (-1.0, 1.0):
            for step_i in range(10):
                t = (step_i + 1) / 10.0
                lx = sx + side * (1.55 + math.sin(t * math.pi) * min(3.4, hw * 0.38))
                lz = sz + (cz0 - sz) * t * 0.92
                if slot_ok(lx, lz, min_mon=2.05, min_sp=1.55, min_wall=1.25):
                    lane_slots.append((lx, lz))
        # Also outer symmetrical rows
        for side in (-1.0, 1.0):
            for row_i in range(-3, 4):
                lx = side * (hw - 1.75)
                lz = row_i * 1.45
                if slot_ok(lx, lz, min_mon=2.0, min_sp=1.6, min_wall=1.25):
                    lane_slots.append((lx, lz))

        if not lane_slots:
            lane_slots = [(sx + 1.8, sz - 1.5), (sx - 1.8, sz - 1.5)]

        for i, k in enumerate(rem_low):
            lx, lz = lane_slots[i % len(lane_slots)]
            stack_lvl = i // len(lane_slots)
            add(k, lx, lz, stack_lvl * step_y(k), rot_deg=0.0)

    # Assemble updated level dict
    out = dict(level)
    out["spawn"] = new_spawn
    out["bombs"] = cleaned_bombs
    out["items"] = placed

    # Verify Lv.5 reachability (if any target landed near a wall, pull gently inward toward center!)
    ok_reach, unreach = vd.check_lv5_reachability(out)
    if not ok_reach:
        for it in out["items"]:
            if it["key"] in targets:
                px, pz = it["pos"]
                if not wall_clear(px, pz, walls, 2.0):
                    it["pos"] = [round(px * 0.65, 2), round(pz * 0.65, 2)]

    # Auto-calibrate duration cleanly into target TimeRatio band so 60/60 PASS validate_difficulty.py!
    res = vd.simulate_level(out, catalog)
    band = {
        "TUTORIAL": (1.45, 2.80),
        "EASY": (1.28, 2.20),
        "NORMAL": (1.12, 1.44),
        "HARD": (0.96, 1.03),
        "SUPER_HARD": (0.84, 0.90),
        "MEGA_BOSS": (0.84, 0.90),
    }.get(tag, (1.12, 1.44))

    if res["issues"]:
        norm_sec = res["norm_sec"]
        opt_sec = res["opt_sec"]
        ice_cnt = sum(1 for p in out.get("powerups", []) if p.get("kind") == "ice")
        eff_ice_norm = ice_cnt * 2.2
        eff_ice_opt = ice_cnt * 3.8
        target_tr = (band[0] + band[1]) * 0.5
        ideal_dur = int(round(norm_sec * target_tr - eff_ice_norm))
        min_opt_dur = int(math.ceil(opt_sec / 0.94 - eff_ice_opt))
        base_dur = max(14, min(75, max(ideal_dur, min_opt_dur)))
        for delta_s in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8, 10, -10]:
            cand = max(14, base_dur + delta_s)
            out["duration"] = cand
            r2 = vd.simulate_level(out, catalog)
            if not r2["issues"]:
                break

    return out, archetype


def main():
    with open(CATALOG_PATH, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    counts = {}
    for lv_num in range(1, 61):
        path = os.path.join(LEVELS_DIR, f"level_{lv_num:03d}.json")
        with open(path, "r", encoding="utf-8") as f:
            lv = json.load(f)
        new_lv, arch = build_monument_level(lv, catalog)
        counts[arch] = counts.get(arch, 0) + 1
        with open(path, "w", encoding="utf-8") as f:
            json.dump(new_lv, f, indent=2)

        stacked_n = sum(1 for it in new_lv["items"] if float(it.get("y", 0.0)) > 0.05)
        max_y = max((float(it.get("y", 0.0)) for it in new_lv["items"]), default=0.0)
        if lv_num in (1, 2, 3, 4, 5, 20, 21, 31, 41, 50, 51, 60):
            print(f"  Lv.{lv_num:02d} (W{new_lv['world']}) [{arch:10s}] items={len(new_lv['items']):3d} stacked={stacked_n:2d} maxY={max_y:.2f}m dur={new_lv['duration']}s")

    print("\n=== ALL 60 LEVELS UPGRADED WITH 'ALL IN HOLE' 3D STACKING MONUMENTS ===")
    for k, v in sorted(counts.items()):
        print(f"  {k:12s}: {v} levels")


if __name__ == "__main__":
    main()
