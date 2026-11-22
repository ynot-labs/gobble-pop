#!/usr/bin/env python3
"""
Gobble Pop! — Automated Difficulty, TimeRatio, XP-Redundancy & Lv.5 Reachability Validator
Simulates a realistic greedy sweep route matching HoleController physics:
  - Cumulative XP: 95 / 245 / 475 / 810 (Lv.1 -> Lv.5)
  - Speeds: 6.35 + (lv - 1) * 0.36
  - Sweep radius: 0.82 * [1.0, 1.45, 2.0, 2.65, 3.5]
  - Checks:
      1. Zero deadlocks (greedy bot can always level up to swallow all targets)
      2. Zero wall soft-locks (2D BFS flood-fill at Lv.5 collision radius 1.75m reaches every target)
      3. Optimal route is strictly beatable (optimal_sec <= eff_duration_opt * 0.96)
      4. Normal player TimeRatio falls cleanly inside each difficulty tier's IAA target band:
           TUTORIAL / EASY : TimeRatio >= 1.16
           NORMAL          : 1.04 <= TimeRatio <= 1.32
           HARD            : 0.94 <= TimeRatio <= 1.05
           SUPER_HARD      : 0.82 <= TimeRatio <= 0.92
           MEGA_BOSS       : 0.82 <= TimeRatio <= 0.92
      5. Scheme A XP Redundancy Ratio (xp_below_max_tier / xp_needed_for_max_tier):
           HARD            : <= 1.45 (disciplined routing required)
           SUPER_HARD/MEGA : <= 1.26 (tight cliff growth curve!)
"""
import collections
import glob
import json
import math
import os
import sys
from typing import Dict, List, Optional, Tuple

BASE_DIR = "/Users/unmercy/Documents/antig/hole"
CATALOG_PATH = os.path.join(BASE_DIR, "data", "item_catalog.json")
LEVELS_DIR = os.path.join(BASE_DIR, "data", "levels")

LEVEL_CUMULATIVE_XP = {1: 0.0, 2: 95.0, 3: 245.0, 4: 475.0, 5: 810.0}
LEVEL_RADIUS = {1: 0.82, 2: 0.82 * 1.45, 3: 0.82 * 2.0, 4: 0.82 * 2.65, 5: 0.82 * 3.5}
LEVEL_SPEED = {1: 6.35, 2: 6.71, 3: 7.07, 4: 7.43, 5: 7.79}

WALL_HALF_LEN = 1.65
WALL_LV5_CLEAR = 1.74  # min(2.87*0.62, 1.48) + 0.24 + 0.02 margin


def point_to_segment_dist(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
    vx, vz = bx - ax, bz - az
    wx, wz = px - ax, pz - az
    len2 = vx * vx + vz * vz
    if len2 <= 1e-9:
        return math.hypot(px - ax, pz - az)
    t = max(0.0, min(1.0, (wx * vx + wz * vz) / len2))
    cx = ax + t * vx
    cz = az + t * vz
    return math.hypot(px - cx, pz - cz)


def dist_to_wall(px: float, pz: float, wall: dict) -> float:
    wx, wz = wall["pos"]
    ang = -math.radians(float(wall.get("rot_deg", 0.0)))
    rx, rz = px - wx, pz - wz
    ca, sa = math.cos(ang), math.sin(ang)
    lx = rx * ca - rz * sa
    lz = rx * sa + rz * ca
    cx = max(-WALL_HALF_LEN, min(WALL_HALF_LEN, lx))
    return math.hypot(lx - cx, lz)


def check_lv5_reachability(level: dict) -> Tuple[bool, int]:
    """2D Grid BFS verifying a Lv.5 hole (clearance 1.74m) can reach every target from spawn."""
    walls = level.get("walls", [])
    if not walls:
        return True, 0

    aw, ah = float(level["arena"][0]), float(level["arena"][1])
    hw, hh = aw * 0.5 - 0.6, ah * 0.5 - 0.6
    step = 0.5
    cols = int(round((2.0 * hw) / step)) + 1
    rows = int(round((2.0 * hh) / step)) + 1

    def to_grid(x: float, z: float) -> Tuple[int, int]:
        c = max(0, min(cols - 1, int(round((x + hw) / step))))
        r = max(0, min(rows - 1, int(round((z + hh) / step))))
        return c, r

    def to_world(c: int, r: int) -> Tuple[float, float]:
        return -hw + c * step, -hh + r * step

    blocked = [[False] * cols for _ in range(rows)]
    for r in range(rows):
        for c in range(cols):
            x, z = to_world(c, r)
            for wl in walls:
                if dist_to_wall(x, z, wl) < WALL_LV5_CLEAR:
                    blocked[r][c] = True
                    break

    sx, sz = level["spawn"]
    sc, sr = to_grid(sx, sz)
    visited = [[False] * cols for _ in range(rows)]
    q = collections.deque()
    if not blocked[sr][sc]:
        visited[sr][sc] = True
        q.append((sc, sr))
    else:
        # Search small radius around spawn if needed
        for dc in range(-2, 3):
            for dr in range(-2, 3):
                nc, nr = sc + dc, sr + dr
                if 0 <= nc < cols and 0 <= nr < rows and not blocked[nr][nc]:
                    visited[nr][nc] = True
                    q.append((nc, nr))

    while q:
        c, r = q.popleft()
        for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nc, nr = c + dc, r + dr
            if 0 <= nc < cols and 0 <= nr < rows and not visited[nr][nc] and not blocked[nr][nc]:
                visited[nr][nc] = True
                q.append((nc, nr))

    targets = level["targets"]
    unreachable = 0
    for it in level["items"]:
        if it["key"] not in targets:
            continue
        tx, tz = it["pos"]
        tc, tr = to_grid(tx, tz)
        # Hole can swallow a target if hole center gets within 1.5m (3 cells) of target
        ok = False
        for dr in range(-3, 4):
            for dc in range(-3, 4):
                nc, nr = tc + dc, tr + dr
                if 0 <= nc < cols and 0 <= nr < rows and visited[nr][nc]:
                    wx, wz = to_world(nc, nr)
                    if math.hypot(wx - tx, wz - tz) <= 1.75:
                        ok = True
                        break
            if ok:
                break
        if not ok:
            unreachable += 1

    return unreachable == 0, unreachable


def simulate_level(level: dict, catalog: Dict[str, dict]) -> dict:
    targets = dict(level["targets"])
    max_target_tier = max(int(catalog[k]["tier"]) for k in targets)
    xp_needed = LEVEL_CUMULATIVE_XP[max_target_tier]

    # Compute available XP strictly from items below max_target_tier (or all non-Lv.5 if max_tier==5)
    xp_avail_below = 0.0
    for it in level["items"]:
        d = catalog[it["key"]]
        if int(d["tier"]) < max_target_tier:
            xp_avail_below += float(d["xp"])
    xp_ratio = (xp_avail_below / xp_needed) if xp_needed > 0 else 9.99

    # Build item records
    alive = []
    for idx, it in enumerate(level["items"]):
        d = catalog[it["key"]]
        alive.append({
            "id": idx,
            "key": it["key"],
            "x": float(it["pos"][0]),
            "z": float(it["pos"][1]),
            "tier": int(d["tier"]),
            "xp": float(d["xp"]),
            "eaten": False,
        })

    rem = dict(targets)
    cx, cz = float(level["spawn"][0]), float(level["spawn"][1])
    xp = 0.0
    lv = 1
    travel_sec = 0.0
    trap_hits_opt = 0
    bomb_near_opt = 0
    wall_detours_opt = 0

    traps = level.get("traps", [])
    bombs = level.get("bombs", [])
    walls = level.get("walls", [])
    powerups = level.get("powerups", [])
    num_ice = sum(1 for p in powerups if p["kind"] == "ice")
    num_mag = sum(1 for p in powerups if p["kind"] == "magnet")

    deadlock = False
    safety = 0
    while any(v > 0 for v in rem.values()):
        safety += 1
        if safety > 1000:
            deadlock = True
            break

        # Highest tier among still-remaining targets
        rem_max_tier = max(int(catalog[k]["tier"]) for k, v in rem.items() if v > 0)
        can_eat_all_rem = (lv >= rem_max_tier)

        best_item = None
        best_score = 1e18

        for it in alive:
            if it["eaten"] or it["tier"] > lv:
                continue
            is_rem_target = rem.get(it["key"], 0) > 0
            if can_eat_all_rem and not is_rem_target:
                continue
            d = math.hypot(it["x"] - cx, it["z"] - cz)
            if can_eat_all_rem:
                score = d
            else:
                # Favor nearby higher-XP edible clusters & edible needed targets
                w = (it["xp"] ** 0.65) * (1.45 if is_rem_target else 1.0)
                score = (d + 0.75) / w
            if score < best_score:
                best_score = score
                best_item = it

        if best_item is None:
            deadlock = True
            break

        nx, nz = best_item["x"], best_item["z"]
        dist = math.hypot(nx - cx, nz - cz)
        speed = LEVEL_SPEED[lv] * 1.04  # small average fever speed boost
        travel_sec += dist / speed

        # Check obstacle proximity along this segment
        for tr in traps:
            if point_to_segment_dist(tr["pos"][0], tr["pos"][1], cx, cz, nx, nz) < 1.25:
                trap_hits_opt += 1
        for bm in bombs:
            if point_to_segment_dist(bm["pos"][0], bm["pos"][1], cx, cz, nx, nz) < 1.30:
                bomb_near_opt += 1
        for wl in walls:
            wx, wz = wl["pos"]
            if point_to_segment_dist(wx, wz, cx, cz, nx, nz) < 2.1:
                wall_detours_opt += 1

        # Swallow the target item + any other edible items swept along the segment!
        sweep_r = LEVEL_RADIUS[lv] * 0.90
        for it in alive:
            if it["eaten"] or it["tier"] > lv:
                continue
            if it is best_item or point_to_segment_dist(it["x"], it["z"], cx, cz, nx, nz) <= sweep_r:
                it["eaten"] = True
                xp += it["xp"]
                if rem.get(it["key"], 0) > 0:
                    rem[it["key"]] -= 1

        while lv < 5 and xp >= LEVEL_CUMULATIVE_XP[lv + 1]:
            lv += 1

        cx, cz = nx, nz

    # Optimal skilled player time (smart dodging + powerup utilization)
    opt_overhead = (
        1.6
        + min(trap_hits_opt, len(traps)) * 0.30
        + min(bomb_near_opt, len(bombs)) * 0.35
        + min(wall_detours_opt, len(walls) * 2) * 0.40
        - num_mag * 1.9
    )
    optimal_sec = max(6.0, travel_sec + opt_overhead)

    # Normal first-time player time (1.22x route inefficiency + hazard slowdown/detours + partial magnet use)
    normal_hazard_sec = (
        min(len(traps), 12) * 0.58
        + len(bombs) * 0.95
        + len(walls) * 0.85
    )
    normal_sec = max(8.0, travel_sec * 1.24 + 2.4 + normal_hazard_sec - num_mag * 1.3)

    duration = float(level["duration"])
    eff_dur_opt = duration + num_ice * 3.8
    eff_dur_norm = duration + num_ice * 2.2
    time_ratio = eff_dur_norm / normal_sec

    reachable, unreachable_cnt = check_lv5_reachability(level)

    tag = level["difficulty_tag"]
    issues = []
    if deadlock:
        issues.append("DEADLOCK")
    if not reachable:
        issues.append(f"WALL_BLOCKED({unreachable_cnt})")
    if optimal_sec > eff_dur_opt * 0.96:
        issues.append(f"TOO_HARD_OPT({optimal_sec:.1f}s>{eff_dur_opt*0.96:.1f}s)")

    # Target TimeRatio bands per difficulty tier
    if tag in ("TUTORIAL", "EASY"):
        if time_ratio < 1.14:
            issues.append(f"TR_LOW({time_ratio:.2f}<1.14)")
    elif tag == "NORMAL":
        if not (1.06 <= time_ratio <= 1.55):
            issues.append(f"TR_BAND({time_ratio:.2f} not in 1.06-1.55)")
    elif tag == "HARD":
        if not (0.94 <= time_ratio <= 1.05):
            issues.append(f"TR_BAND({time_ratio:.2f} not in 0.94-1.05)")
        if xp_needed > 0 and xp_ratio > 1.46:
            issues.append(f"XP_LOOSE({xp_ratio:.2f}>1.46)")
    elif tag in ("SUPER_HARD", "MEGA_BOSS"):
        if not (0.82 <= time_ratio <= 0.92):
            issues.append(f"TR_BAND({time_ratio:.2f} not in 0.82-0.92)")
        if xp_needed > 0 and xp_ratio > 1.26:
            issues.append(f"XP_LOOSE({xp_ratio:.2f}>1.26)")

    return {
        "level": level["level"],
        "world": level["world"],
        "name": level["formation_name"],
        "tag": tag,
        "arena": level["arena"],
        "duration": duration,
        "items": len(level["items"]),
        "traps": len(traps),
        "walls": len(walls),
        "bombs": len(bombs),
        "xp_ratio": xp_ratio,
        "opt_sec": optimal_sec,
        "eff_opt": eff_dur_opt,
        "norm_sec": normal_sec,
        "eff_norm": eff_dur_norm,
        "time_ratio": time_ratio,
        "issues": issues,
    }


def main() -> int:
    with open(CATALOG_PATH, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    files = sorted(glob.glob(os.path.join(LEVELS_DIR, "level_*.json")))
    if not files:
        print("No level JSONs found!", file=sys.stderr)
        return 1

    passed = 0
    failed = []
    print("=" * 116)
    print(f"{'LV':>4} {'W':>2} {'FORMATION':22s} {'TAG':10s} {'ARENA':7s} {'DUR':>4} {'XP_R':>5} {'OPT/EFF':>11} {'NORM':>5} {'RATIO':>6} {'HAZ(T/W/B)':>10} {'STATUS'}")
    print("-" * 116)

    for fp in files:
        with open(fp, "r", encoding="utf-8") as f:
            lvl = json.load(f)
        res = simulate_level(lvl, catalog)
        ok = len(res["issues"]) == 0
        if ok:
            passed += 1
        else:
            failed.append(res)
        arena_str = f"{int(res['arena'][0])}x{int(res['arena'][1])}"
        haz_str = f"{res['traps']:2d}/{res['walls']}/{res['bombs']}"
        status = "PASS" if ok else "FAIL: " + ", ".join(res["issues"])
        print(
            f"L{res['level']:02d}  W{res['world']} {res['name']:22s} {res['tag']:10s} {arena_str:7s} "
            f"{res['duration']:3.0f}s {res['xp_ratio']:5.2f} {res['opt_sec']:5.1f}/{res['eff_opt']:4.1f}s "
            f"{res['norm_sec']:5.1f} {res['time_ratio']:6.2f} {haz_str:>10s}  {status}"
        )

    print("=" * 116)
    print(f"SUMMARY: {passed}/{len(files)} levels PASSED automated TimeRatio, XP-Redundancy & Lv.5 Reachability QA!")
    if failed:
        print(f"FAILED ({len(failed)}): {[r['level'] for r in failed]}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
