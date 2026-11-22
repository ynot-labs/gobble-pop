"""
Gobble Pop! — Phase 2 H5 First-Pack 3D Asset Builder (13 GLB Models + Marble Tile Texture)
Designed for Blender 5.3.0 via MCP for Blender (execute_code).
Strictly enforces Google Sheet budgets:
  - Total First-Pack 3D Tris <= 5,692
  - Total First-Pack 3D Size <= 833 KB
  - 1 Material per asset (single DrawCall)
  - Origin at bottom-center (0, 0, 0), smooth normals, Y-up glTF 2.0 export
"""
import bpy
import bmesh
import math
import os
import json
import numpy as np
from mathutils import Vector, Matrix, Euler

ROOT = "/Users/unmercy/Documents/antig/hole"
CORE_OUT = os.path.join(ROOT, "assets/models/core")
W1_OUT = os.path.join(ROOT, "assets/models/world1")
TEX_OUT = os.path.join(ROOT, "assets/textures")
BLEND_OUT = os.path.join(ROOT, "assets/blender_src/first_pack_showcase.blend")
SHOWCASE_IMG = os.path.join(ROOT, "assets/refs_2d/blender_first_pack_showcase.png")

for d in (CORE_OUT, W1_OUT, TEX_OUT, os.path.dirname(BLEND_OUT)):
    os.makedirs(d, exist_ok=True)


# ---------------------------------------------------------------------------
# 1. Clean scene & procedural texture / shared color atlas generators
# ---------------------------------------------------------------------------
def clear_scene():
    # Clean scene data WITHOUT unloading Blender MCP addon!
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    for img in list(bpy.data.images):
        if img.users == 0 and img.name != "Render Result":
            bpy.data.images.remove(img)
    for light in list(bpy.data.lights):
        if light.users == 0:
            bpy.data.lights.remove(light)
    for cam in list(bpy.data.cameras):
        if cam.users == 0:
            bpy.data.cameras.remove(cam)


def srgb_to_linear(c):
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h, a=1.0):
    h = h.lstrip("#")
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, a)


PALETTE_COLORS = [
    # Row 0: Core Hole & Powerups
    "#35B6FF",  # 0: Hole Sky Blue
    "#F7C948",  # 1: Hole Warm Gold
    "#0B2569",  # 2: Vortex Deep Navy
    "#0AE0FF",  # 3: Vortex Bright Cyan
    "#FFE829",  # 4: XP Ring Bright Yellow
    "#57D9FF",  # 5: Ice Cube Translucent Cyan
    "#B8F3FF",  # 6: Ice Bubble White-Blue
    "#FF3B5C",  # 7: Magnet Candy Red
    "#3BA7FF",  # 8: Magnet Sky Blue
    "#EBF4FF",  # 9: Magnet Glowing Silver Tip
    "#FF47C2",  # 10: Fever Magenta
    "#52FF86",  # 11: Fever Lime
    "#FFD633",  # 12: Fever Sunny Yellow
    "#7B4DFF",  # 13: Fever Violet
    "#FFFFFF",  # 14: Pure White
    "#2B1B17",  # 15: Dark Espresso / Boba Pearl
    # Row 1: World 1 Sugar Rush Bakery
    "#FF4D94",  # 16: Sprinkle Hot Pink
    "#FFD93D",  # 17: Sprinkle Sunny Yellow
    "#4CC9F0",  # 18: Sprinkle Sky Blue
    "#FF2846",  # 19: Strawberry Glossy Red
    "#FFE259",  # 20: Strawberry Golden Seed
    "#2FD663",  # 21: Strawberry Emerald Leaf
    "#FF3860",  # 22: Gummy Bear Ruby Red
    "#52DF68",  # 23: Gummy Bear Apple Green
    "#FFCE2B",  # 24: Gummy Bear Lemon Yellow
    "#FF9EC4",  # 25: Macaron Pastel Pink
    "#C7A6FF",  # 26: Macaron Soft Lavender
    "#89E8C6",  # 27: Macaron Mint Green
    "#FFF8EE",  # 28: Whipped Cream / Macaron Filling
    "#E5A467",  # 29: Boba Caramel Milk Tea
    "#F5CFA0",  # 30: Donut Baked Golden Dough
    "#FF69A8",  # 31: Donut / Cake Pink Glaze
    # Row 2: Extra Accents
    "#4FC3F7",  # 32: Donut Sky Blue Glaze
    "#FF23A6",  # 33: Bubblegum Neon Hot Pink
    "#FF8CE0",  # 34: Bubblegum Gloss Highlight
    "#FFF2F6",  # 35: Cake Soft Frosting
    "#F9B8D0",  # 36: Boba Pastel Straw
    "#B9EDDD",  # 37: Mint Marble Tile
    "#FCF9F2",  # 38: Cream Marble Tile
    "#8BD8C4",  # 39: Mint Table Border
]


def build_palette_atlas(path, size=128):
    grid = 8  # 8x8 = 64 swatches, 16x16 px each
    cell = size // grid
    arr = np.ones((size, size, 4), dtype=np.float32)
    for idx, hx in enumerate(PALETTE_COLORS):
        r, g, b, a = hex_rgba(hx)
        row = idx // grid
        col = idx % grid
        y0, y1 = row * cell, (row + 1) * cell
        x0, x1 = col * cell, (col + 1) * cell
        arr[y0:y1, x0:x1, 0] = r
        arr[y0:y1, x0:x1, 1] = g
        arr[y0:y1, x0:x1, 2] = b
        arr[y0:y1, x0:x1, 3] = a

    img = bpy.data.images.new("W1PaletteAtlas", width=size, height=size, alpha=True)
    # Blender images are bottom-to-top; store directly
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def swatch_uv(idx, grid=8):
    row = idx // grid
    col = idx % grid
    return ((col + 0.5) / grid, (row + 0.5) / grid)


def build_marble_tile_texture(path, size=512):
    """W1-01 Mint & Cream Checkered Glossy Marble Tile (512x512)."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    cx = (x * 4.0).astype(np.int32) % 2
    cy = (y * 4.0).astype(np.int32) % 2
    checker = ((cx + cy) % 2).astype(np.float32)

    # Subtle seamless marble veining
    vein = (
        np.sin(x * math.tau * 2.0 + np.sin(y * math.tau * 2.0) * 1.6) * 0.5
        + np.sin((x + y) * math.tau * 3.0) * 0.25
    )
    vein = np.clip((vein + 0.75) * 0.5, 0.0, 1.0)
    vein_line = np.power(1.0 - np.abs(vein - 0.5) * 2.0, 5.0) * 0.065

    # Tile grout subtle bevel
    gx = np.abs(((x * 4.0) % 1.0) - 0.5) * 2.0
    gy = np.abs(((y * 4.0) % 1.0) - 0.5) * 2.0
    grout = np.clip((np.maximum(gx, gy) - 0.96) / 0.04, 0.0, 1.0) * 0.07

    mint = np.array([0.74, 0.94, 0.86], dtype=np.float32)
    cream = np.array([0.99, 0.97, 0.93], dtype=np.float32)
    rgb = mint[None, None, :] * (1.0 - checker[:, :, None]) + cream[None, None, :] * checker[:, :, None]
    rgb = np.clip(rgb - vein_line[:, :, None] - grout[:, :, None], 0.0, 1.0)

    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    img = bpy.data.images.new("W1MarbleTile", width=size, height=size, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def build_boba_texture(path, size=256):
    """Dedicated 256x256 texture for Boba Milk Tea Cup: caramel gradient + tapioca pearls + lid/straw band."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rgba = np.ones((size, size, 4), dtype=np.float32)

    # Top strip (y > 0.82): pastel pink straw & translucent lid white
    # Main cup body (0.0 .. 0.82): warm milk tea gradient
    grad = np.clip(y / 0.82, 0.0, 1.0)
    bot_col = np.array([0.76, 0.48, 0.25], dtype=np.float32)
    top_col = np.array([0.96, 0.83, 0.67], dtype=np.float32)
    rgb = bot_col[None, None, :] * (1.0 - grad[:, :, None]) + top_col[None, None, :] * grad[:, :, None]

    # Add two staggered rows of glossy dark brown tapioca pearls near the bottom (y in 0.04..0.28)
    for row_i, py in enumerate([0.10, 0.21]):
        cols = 10
        offset = 0.05 if row_i == 1 else 0.0
        for ci in range(cols):
            px = (ci / cols + offset) % 1.0
            dx = np.minimum(np.abs(x - px), 1.0 - np.abs(x - px))
            dy = y - py
            dist = np.sqrt((dx * 1.0) ** 2 + (dy * 1.1) ** 2)
            pearl = dist < 0.038
            spec = np.sqrt(((dx - 0.01) * 1.0) ** 2 + ((dy - 0.012) * 1.1) ** 2) < 0.011
            rgb[pearl] = np.array([0.14, 0.08, 0.06], dtype=np.float32)
            rgb[spec] = np.array([0.42, 0.30, 0.24], dtype=np.float32)

    # Lid glossy milky band (y in 0.82..0.91)
    lid_mask = (y >= 0.82) & (y < 0.91)
    rgb[lid_mask] = np.array([0.96, 0.97, 0.99], dtype=np.float32)
    # Straw pastel pink band (y >= 0.91)
    straw_mask = y >= 0.91
    rgb[straw_mask] = np.array([0.99, 0.68, 0.80], dtype=np.float32)

    rgba[:, :, :3] = rgb
    img = bpy.data.images.new("W1BobaTex", width=size, height=size, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def build_strawberry_texture(path, size=256):
    """Dedicated 256x256 glossy red strawberry texture with golden seeds + emerald leaf strip."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rgba = np.ones((size, size, 4), dtype=np.float32)

    # Bottom 0.0..0.82: rich red strawberry gradient (deeper crimson at bottom, brighter red on shoulder)
    grad = np.clip(y / 0.82, 0.0, 1.0)
    bot_c = np.array([0.82, 0.08, 0.16], dtype=np.float32)
    top_c = np.array([1.00, 0.22, 0.30], dtype=np.float32)
    rgb = bot_c[None, None, :] * (1.0 - grad[:, :, None]) + top_c[None, None, :] * grad[:, :, None]

    # Staggered golden seeds with tiny dark-red recessed halo
    for row_i, py in enumerate([0.22, 0.42, 0.62]):
        cols = 7 if row_i != 0 else 5
        off = 0.07 if row_i % 2 == 1 else 0.0
        for ci in range(cols):
            px = (ci / cols + off) % 1.0
            dx = np.minimum(np.abs(x - px), 1.0 - np.abs(x - px))
            dy = y - py
            d_outer = np.sqrt((dx * 1.15) ** 2 + (dy * 0.85) ** 2)
            d_seed = np.sqrt((dx * 1.45) ** 2 + (dy * 0.95) ** 2)
            rgb[d_outer < 0.032] = np.array([0.65, 0.06, 0.12], dtype=np.float32)
            rgb[d_seed < 0.021] = np.array([1.0, 0.88, 0.32], dtype=np.float32)

    # Top strip (y >= 0.82): vibrant emerald green for leaves & stem
    rgb[y >= 0.82] = np.array([0.18, 0.82, 0.36], dtype=np.float32)
    rgba[:, :, :3] = rgb

    img = bpy.data.images.new("W1StrawberryTex", width=size, height=size, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def build_vfx_m1_atlas(path, size=256):
    """VFX-M1: 256x256 4-in-1 pure-white transparent particle atlas (Star / Bubble / Glow / Sparkle)."""
    half = size // 2
    rgba = np.zeros((size, size, 4), dtype=np.float32)
    y, x = np.mgrid[0:half, 0:half].astype(np.float32) / half
    cx = (x - 0.5) * 2.0
    cy = (y - 0.5) * 2.0
    r = np.sqrt(cx * cx + cy * cy)
    ang = np.arctan2(cy, cx)

    # Q0 (top-left in UV -> row 1): Chubby 5-point star
    star_r = 0.56 + 0.24 * np.cos(ang * 5.0)
    star_a = np.clip((star_r - r) / 0.10, 0.0, 1.0)
    rgba[half:size, 0:half, :3] = 1.0
    rgba[half:size, 0:half, 3] = star_a

    # Q1 (top-right): Glossy bubble ring + specular dot
    rim = np.exp(-((r - 0.72) ** 2) / 0.015) * 0.85
    fill = np.clip(1.0 - r / 0.80, 0.0, 1.0) * 0.28
    spec = np.exp(-(((cx + 0.28) ** 2 + (cy - 0.28) ** 2) / 0.025)) * 0.95
    bub_a = np.clip(rim + fill + spec, 0.0, 1.0) * (r < 0.88)
    rgba[half:size, half:size, :3] = 1.0
    rgba[half:size, half:size, 3] = bub_a

    # Q2 (bottom-left): Soft radial halo glow
    glow_a = np.power(np.clip(1.0 - r, 0.0, 1.0), 2.2)
    rgba[0:half, 0:half, :3] = 1.0
    rgba[0:half, 0:half, 3] = glow_a

    # Q3 (bottom-right): 4-point diamond sparkle
    sp = np.power(np.abs(cx), 0.55) + np.power(np.abs(cy), 0.55)
    spark_a = np.clip((0.92 - sp) / 0.14, 0.0, 1.0)
    rgba[0:half, half:size, :3] = 1.0
    rgba[0:half, half:size, 3] = spark_a

    img = bpy.data.images.new("VFX_M1_Atlas", width=size, height=size, alpha=True)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def make_atlas_material(name, img, roughness=0.22, metallic=0.04, alpha=1.0, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest" if "Palette" in img.name else "Linear"

    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.55 if roughness < 0.35 else 0.1
        bsdf.inputs["Coat Roughness"].default_value = 0.12
    if alpha < 0.99:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else "OPAQUE"
    if emission_strength > 0.0 and "Emission Strength" in bsdf.inputs:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission_strength

    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


# ---------------------------------------------------------------------------
# 2. BMesh modeling helpers (assigning per-part palette UV cleanly)
# ---------------------------------------------------------------------------
def add_bm_part(bm, uv_layer, swatch_idx, build_fn):
    before = set(bm.faces)
    build_fn(bm)
    u, v = swatch_uv(swatch_idx)
    for f in bm.faces:
        if f not in before:
            f.smooth = True
            for loop in f.loops:
                loop[uv_layer].uv = (u, v)


def finalize_mesh(name, bm, mat, align_bottom=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if align_bottom and len(bm.verts) > 0:
        min_z = min(v.co.z for v in bm.verts)
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        cx = 0.5 * (min(xs) + max(xs))
        cy = 0.5 * (min(ys) + max(ys))
        for v in bm.verts:
            v.co.x -= cx
            v.co.y -= cy
            v.co.z -= min_z

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def make_lathe(bm, profile_rz, segs=16, cap_bottom=False, cap_top=True, offset=Vector((0, 0, 0))):
    """Create a revolved mesh from [(r, z), ...] points."""
    rings = []
    for r, z in profile_rz:
        if r <= 1e-5:
            v = bm.verts.new(Vector((0.0, 0.0, z)) + offset)
            rings.append([v])
        else:
            ring = []
            for s in range(segs):
                a = math.tau * s / segs
                ring.append(bm.verts.new(Vector((math.cos(a) * r, math.sin(a) * r, z)) + offset))
            rings.append(ring)

    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        if len(r0) == 1 and len(r1) > 1:
            for s in range(segs):
                bm.faces.new((r0[0], r1[(s + 1) % segs], r1[s]))
        elif len(r0) > 1 and len(r1) == 1:
            for s in range(segs):
                bm.faces.new((r0[s], r0[(s + 1) % segs], r1[0]))
        elif len(r0) > 1 and len(r1) > 1:
            for s in range(segs):
                bm.faces.new((r0[s], r0[(s + 1) % segs], r1[(s + 1) % segs], r1[s]))

    if cap_bottom and len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and len(rings[-1]) > 1:
        bm.faces.new(rings[-1])


def make_torus(bm, major_r, minor_r, maj_segs=20, min_segs=10, offset=Vector((0, 0, 0)), z_scale=1.0):
    rings = []
    for i in range(maj_segs):
        theta = math.tau * i / maj_segs
        ct, st = math.cos(theta), math.sin(theta)
        ring = []
        for j in range(min_segs):
            phi = math.tau * j / min_segs
            cp, sp = math.cos(phi), math.sin(phi)
            r = major_r + minor_r * cp
            x = r * ct
            y = r * st
            z = minor_r * sp * z_scale
            ring.append(bm.verts.new(Vector((x, y, z)) + offset))
        rings.append(ring)

    for i in range(maj_segs):
        r0 = rings[i]
        r1 = rings[(i + 1) % maj_segs]
        for j in range(min_segs):
            j1 = (j + 1) % min_segs
            bm.faces.new((r0[j], r1[j], r1[j1], r0[j1]))


# ---------------------------------------------------------------------------
# 3. Build all 13 H5 First-Pack 3D Assets
# ---------------------------------------------------------------------------
def build_core_01_hole(pal_mat, is_fever=False):
    name = "CORE_02_FeverHole" if is_fever else "CORE_01_BaseHole"
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 20

    # Outer gold base lip (low bevel)
    add_bm_part(bm, uv, 1, lambda b: make_lathe(b, [
        (1.02, 0.00), (1.04, 0.04), (1.00, 0.08), (0.96, 0.08)
    ], segs=segs, cap_top=False))

    # Main chunky rounded rim (Sky Blue or Rainbow per-segment)
    before = set(bm.faces)
    make_lathe(bm, [
        (0.98, 0.06), (0.98, 0.16), (0.93, 0.22), (0.81, 0.22), (0.76, 0.16), (0.76, 0.05)
    ], segs=segs, cap_top=False)
    rainbow_ids = [10, 13, 0, 3, 11, 12]
    for f in bm.faces:
        if f not in before:
            f.smooth = True
            if is_fever:
                c = f.calc_center_median()
                ang = (math.atan2(c.y, c.x) + math.pi) / math.tau
                idx = rainbow_ids[int(ang * len(rainbow_ids)) % len(rainbow_ids)]
            else:
                idx = 0
            u, v = swatch_uv(idx)
            for loop in f.loops:
                loop[uv].uv = (u, v)

    # Inner gold trim ring
    add_bm_part(bm, uv, 1, lambda b: make_lathe(b, [
        (0.77, 0.17), (0.74, 0.21), (0.70, 0.19), (0.69, 0.10)
    ], segs=segs, cap_top=False))

    # Swirling funnel interior
    add_bm_part(bm, uv, 10 if is_fever else 3, lambda b: make_lathe(b, [
        (0.69, 0.10), (0.56, 0.03), (0.36, -0.08)
    ], segs=segs, cap_top=False))
    add_bm_part(bm, uv, 13 if is_fever else 2, lambda b: make_lathe(b, [
        (0.36, -0.08), (0.16, -0.18), (0.0, -0.22)
    ], segs=segs, cap_top=False))

    return finalize_mesh(name, bm, pal_mat, align_bottom=False)


def build_core_03_ice_cube(ice_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Smooth chubby superellipsoid rounded ice cube (~240 tris)
    res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.40)
    for v in res["verts"]:
        p = v.co
        norm4 = (abs(p.x) ** 4 + abs(p.y) ** 4 + abs(p.z) ** 4) ** 0.25
        if norm4 > 1e-5:
            scale = 0.34 / norm4
            v.co = p * scale + Vector((0.0, 0.0, 0.34))
    for f in bm.faces:
        f.smooth = True
        u, v_uv = swatch_uv(5)
        for loop in f.loops:
            loop[uv].uv = (u, v_uv)
    return finalize_mesh("CORE_03_IceCube", bm, ice_mat)


def build_core_04_magnet(pal_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # Build chunky rounded U-shape swept along a 13-point horseshoe spine
    pts = []
    # Left leg (red side)
    pts.append((Vector((-0.28, -0.34, 0.14)), 9))  # Silver tip
    pts.append((Vector((-0.28, -0.20, 0.14)), 9))
    pts.append((Vector((-0.28, -0.02, 0.14)), 7))  # Red
    # U-bend arc (7 points from pi to 0)
    for k in range(7):
        ang = math.pi * (1.0 - k / 6.0)
        x = math.cos(ang) * 0.28
        y = 0.04 + math.sin(ang) * 0.28
        sw = 7 if k < 3 else 8  # Left Red, Right Sky Blue
        pts.append((Vector((x, y, 0.14)), sw))
    # Right leg (blue side)
    pts.append((Vector((0.28, -0.02, 0.14)), 8))
    pts.append((Vector((0.28, -0.20, 0.14)), 9))
    pts.append((Vector((0.28, -0.34, 0.14)), 9))  # Silver tip

    # Rectangular-rounded 8-vertex cross section
    sec = [
        (0.11, -0.06), (0.11, 0.06), (0.06, 0.11), (-0.06, 0.11),
        (-0.11, 0.06), (-0.11, -0.06), (-0.06, -0.11), (0.06, -0.11)
    ]
    rings = []
    for i, (p, sw) in enumerate(pts):
        if i == 0:
            tang = (pts[1][0] - p).normalized()
        elif i == len(pts) - 1:
            tang = (p - pts[i - 1][0]).normalized()
        else:
            tang = (pts[i + 1][0] - pts[i - 1][0]).normalized()
        up = Vector((0, 0, 1))
        right = tang.cross(up).normalized()
        ring = [bm.verts.new(p + right * rx + up * rz) for (rx, rz) in sec]
        rings.append((ring, sw))

    for i in range(len(rings) - 1):
        r0, sw0 = rings[i]
        r1, sw1 = rings[i + 1]
        sw = sw0 if i < len(rings) // 2 else sw1
        u, v = swatch_uv(sw)
        for j in range(len(sec)):
            j1 = (j + 1) % len(sec)
            f = bm.faces.new((r0[j], r0[j1], r1[j1], r1[j]))
            f.smooth = True
            for loop in f.loops:
                loop[uv].uv = (u, v)

    # Cap both silver magnetic tips
    for ring_idx, rev in [(0, True), (-1, False)]:
        r, sw = rings[ring_idx]
        f = bm.faces.new(list(reversed(r)) if rev else r)
        f.smooth = True
        u, v = swatch_uv(9)
        for loop in f.loops:
            loop[uv].uv = (u, v)

    return finalize_mesh("CORE_04_Magnet", bm, pal_mat)


def build_w1_01_tabletop(marble_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co.x *= 14.0
        v.co.y *= 20.0
        v.co.z = (v.co.z + 0.5) * 0.35
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.1 or e.verts[0].co.z > 0.2],
                    offset=0.22, segments=2, affect="EDGES", clamp_overlap=True)
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x * 0.25 + 0.5, co.y * 0.25 + 0.5)
    return finalize_mesh("W1_01_Tabletop", bm, marble_mat)


def build_w1_02_sprinkle(pal_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Chubby pill capsule oriented horizontally (total ~64 tris)
    add_bm_part(bm, uv, 16, lambda b: make_lathe(b, [
        (0.0, -0.22), (0.065, -0.20), (0.095, -0.14),
        (0.095, 0.14), (0.065, 0.20), (0.0, 0.22)
    ], segs=10, cap_top=False))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    return finalize_mesh("W1_02_Sprinkle", bm, pal_mat)


def build_w1_03_strawberry(berry_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Plump tapered strawberry body with cylindrical UV onto crisp painted seed texture (~140 tris)
    before = set(bm.faces)
    make_lathe(bm, [
        (0.0, 0.0), (0.12, 0.04), (0.24, 0.16), (0.29, 0.30),
        (0.25, 0.40), (0.15, 0.44), (0.0, 0.44)
    ], segs=12, cap_top=False)
    for f in bm.faces:
        if f not in before:
            f.smooth = True
            for loop in f.loops:
                co = loop.vert.co
                ang = (math.atan2(co.y, co.x) + math.pi) / math.tau
                v_coord = min(0.80, max(0.02, (co.z / 0.44) * 0.78))
                loop[uv].uv = (ang, v_coord)

    # 5 chunky diamond-petal emerald leaves + short stem (mapped to top emerald strip v=0.92, total ~220 tris)
    before2 = set(bm.faces)
    for i in range(5):
        ang = math.tau * i / 5.0
        rot = Matrix.Rotation(ang, 4, "Z") @ Matrix.Rotation(math.radians(20), 4, "Y")
        mat = Matrix.Translation((math.cos(ang) * 0.12, math.sin(ang) * 0.12, 0.43)) @ rot @ Matrix.Diagonal((0.15, 0.07, 0.032, 1.0))
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=4, radius1=1.0, radius2=0.35, depth=1.0, matrix=mat)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.034, radius2=0.025, depth=0.10,
                          matrix=Matrix.Translation((0, 0, 0.48)))
    for f in bm.faces:
        if f not in before2:
            f.smooth = True
            for loop in f.loops:
                loop[uv].uv = (0.5, 0.92)

    return finalize_mesh("W1_03_Strawberry", bm, berry_mat)


def build_w1_04_gummy_bear(gummy_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    def part(pos, scale, sub=1):
        m = Matrix.Translation(pos) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
        add_bm_part(bm, uv, 22, lambda b, mat=m, s=sub: bmesh.ops.create_icosphere(b, subdivisions=s, radius=1.0, matrix=mat))

    # Plump torso + cute chubby head
    part(Vector((0, 0, 0.21)), (0.17, 0.14, 0.17), sub=2)
    part(Vector((0, 0, 0.44)), (0.16, 0.15, 0.14), sub=2)
    # Snout
    part(Vector((0, -0.13, 0.41)), (0.065, 0.055, 0.05), sub=1)
    # Ears
    part(Vector((-0.11, 0.0, 0.55)), (0.055, 0.045, 0.055), sub=1)
    part(Vector((0.11, 0.0, 0.55)), (0.055, 0.045, 0.055), sub=1)
    # Arms
    part(Vector((-0.17, -0.05, 0.26)), (0.065, 0.08, 0.06), sub=1)
    part(Vector((0.17, -0.05, 0.26)), (0.065, 0.08, 0.06), sub=1)
    # Feet
    part(Vector((-0.10, -0.06, 0.075)), (0.075, 0.095, 0.07), sub=1)
    part(Vector((0.10, -0.06, 0.075)), (0.075, 0.095, 0.07), sub=1)

    return finalize_mesh("W1_04_GummyBear", bm, gummy_mat)


def build_w1_05_macaron(pal_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 15
    # Bottom shell
    add_bm_part(bm, uv, 25, lambda b: make_lathe(b, [
        (0.0, 0.0), (0.36, 0.0), (0.48, 0.04), (0.50, 0.11), (0.46, 0.14)
    ], segs=segs, cap_top=False))
    # Cream filling + subtle ruffled edge
    add_bm_part(bm, uv, 28, lambda b: make_lathe(b, [
        (0.46, 0.13), (0.49, 0.17), (0.49, 0.23), (0.46, 0.27)
    ], segs=segs, cap_top=False))
    # Top domed shell
    add_bm_part(bm, uv, 25, lambda b: make_lathe(b, [
        (0.46, 0.26), (0.50, 0.29), (0.48, 0.36), (0.34, 0.40), (0.0, 0.41)
    ], segs=segs, cap_top=False))
    return finalize_mesh("W1_05_Macaron", bm, pal_mat)


def build_w1_06_boba_tea(boba_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 18

    # Cup body + dome lid as one smooth lathe with cylindrical UV mapping matching boba_tex!
    profile = [
        (0.0, 0.0), (0.34, 0.0), (0.37, 0.05), (0.44, 0.62),
        (0.48, 0.65), (0.48, 0.69), (0.42, 0.70), (0.36, 0.84), (0.20, 0.94), (0.0, 0.96)
    ]
    before = set(bm.faces)
    make_lathe(bm, profile, segs=segs, cap_top=False)
    for f in bm.faces:
        if f not in before:
            f.smooth = True
            for loop in f.loops:
                co = loop.vert.co
                ang = (math.atan2(co.y, co.x) + math.pi) / math.tau
                v_coord = min(0.89, max(0.01, (co.z / 0.70) * 0.80)) if co.z <= 0.68 else 0.86
                loop[uv].uv = (ang, v_coord)

    # Thick tilted pastel straw mapped to top pink strip (v = 0.96)
    before2 = set(bm.faces)
    straw_mat = Matrix.Translation((0.06, 0.0, 0.98)) @ Matrix.Rotation(math.radians(10), 4, "Y")
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10,
                          radius1=0.068, radius2=0.068, depth=0.52, matrix=straw_mat)
    for f in bm.faces:
        if f not in before2:
            f.smooth = True
            for loop in f.loops:
                loop[uv].uv = (0.5, 0.96)

    return finalize_mesh("W1_06_BobaTea", bm, boba_mat)


def build_w1_07_donut(pal_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # Plump golden baked donut base (16x8 = 256 tris)
    add_bm_part(bm, uv, 30, lambda b: make_torus(
        b, major_r=0.56, minor_r=0.25, maj_segs=16, min_segs=8,
        offset=Vector((0, 0, 0.22)), z_scale=0.88))

    # Glossy wavy strawberry-pink frosting cap (16x4 = 128 tris, cleanly shows golden dough bottom)
    before = set(bm.faces)
    maj_segs, min_segs = 16, 5
    rings = []
    for i in range(maj_segs):
        theta = math.tau * i / maj_segs
        ct, st = math.cos(theta), math.sin(theta)
        drip = math.sin(theta * 4.0) * 0.04
        ring = []
        for j in range(min_segs):
            phi = 0.05 + (math.pi - 0.10) * (j / (min_segs - 1))
            cp, sp = math.cos(phi), math.sin(phi)
            r = 0.56 + 0.268 * cp
            z = 0.24 + 0.268 * sp * 0.88 + (drip if (j == 0 or j == min_segs - 1) else 0.0)
            ring.append(bm.verts.new(Vector((r * ct, r * st, z))))
        rings.append(ring)
    for i in range(maj_segs):
        r0 = rings[i]
        r1 = rings[(i + 1) % maj_segs]
        for j in range(min_segs - 1):
            bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
    u, v = swatch_uv(31)
    for f in bm.faces:
        if f not in before:
            f.smooth = True
            for loop in f.loops:
                loop[uv].uv = (u, v)

    # 8 chunky colorful candy sprinkles (8x12 = 96 tris -> total ~480 <= 520)
    sprinkle_colors = [17, 18, 16, 21, 26]
    for i in range(8):
        ang = math.tau * i / 8.0 + 0.2
        r_pos = 0.56 + (0.06 if i % 2 == 0 else -0.05)
        pos = Vector((math.cos(ang) * r_pos, math.sin(ang) * r_pos, 0.47))
        rot = Matrix.Rotation(ang + 0.7, 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")
        mat = Matrix.Translation(pos) @ rot @ Matrix.Diagonal((0.032, 0.032, 0.11, 1.0))
        add_bm_part(bm, uv, sprinkle_colors[i % len(sprinkle_colors)],
                    lambda b, m=mat: bmesh.ops.create_cube(b, size=1.0, matrix=m))

    return finalize_mesh("W1_07_Donut", bm, pal_mat)


def build_w1_08_cake(pal_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 20

    # Tier 1 lower cake cylinder (soft cream)
    add_bm_part(bm, uv, 35, lambda b: make_lathe(b, [
        (0.0, 0.0), (1.18, 0.0), (1.20, 0.08), (1.18, 0.70), (1.12, 0.75), (0.0, 0.75)
    ], segs=segs, cap_top=False))

    # Tier 1 pink glaze crown + wavy drip ring
    add_bm_part(bm, uv, 31, lambda b: make_lathe(b, [
        (1.22, 0.56), (1.23, 0.71), (1.14, 0.78), (0.80, 0.78)
    ], segs=segs, cap_top=False))

    # Tier 2 upper cake cylinder
    add_bm_part(bm, uv, 35, lambda b: make_lathe(b, [
        (0.84, 0.74), (0.85, 0.80), (0.83, 1.30), (0.77, 1.36), (0.0, 1.36)
    ], segs=segs, cap_top=False))

    # Tier 2 pink glaze top
    add_bm_part(bm, uv, 31, lambda b: make_lathe(b, [
        (0.87, 1.18), (0.88, 1.32), (0.78, 1.39), (0.0, 1.39)
    ], segs=segs, cap_top=False))

    # Whipped cream rosettes around tier 2 collar (8) and top crown (6)
    for ring_r, ring_z, count, rad in [(0.88, 0.81, 8, 0.13), (0.48, 1.43, 6, 0.13)]:
        for i in range(count):
            a = math.tau * i / count
            p = Vector((math.cos(a) * ring_r, math.sin(a) * ring_r, ring_z))
            add_bm_part(bm, uv, 28, lambda b, pos=p, r=rad: bmesh.ops.create_icosphere(
                b, subdivisions=1, radius=r, matrix=Matrix.Translation(pos)))

    # 3 glossy red strawberries crowning the cake top
    for i in range(3):
        a = math.tau * i / 3.0 + 0.3
        p = Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 1.56))
        rot = Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.radians(18), 4, "Y")
        m = Matrix.Translation(p) @ rot @ Matrix.Diagonal((0.15, 0.15, 0.20, 1.0))
        add_bm_part(bm, uv, 19, lambda b, mat=m: bmesh.ops.create_icosphere(b, subdivisions=1, radius=1.0, matrix=mat))

    # 6 pastel macaron medallions decorating the bottom base
    mac_colors = [27, 17, 26, 25, 27, 17]
    for i in range(6):
        a = math.tau * i / 6.0
        p = Vector((math.cos(a) * 1.22, math.sin(a) * 1.22, 0.20))
        rot = Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "Y")
        m = Matrix.Translation(p) @ rot @ Matrix.Diagonal((0.19, 0.19, 0.09, 1.0))
        add_bm_part(bm, uv, mac_colors[i], lambda b, mat=m: bmesh.ops.create_icosphere(b, subdivisions=1, radius=1.0, matrix=mat))

    return finalize_mesh("W1_08_Cake", bm, pal_mat)


def build_w1_09_bubblegum(gum_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col_layer = bm.loops.layers.color.new("Col")

    # Smooth organic gooey bubblegum puddle (32 radial segments x 3 rings -> super smooth curved lobes!)
    segs = 32
    rings_radii = [0.34, 0.72, 0.96]
    center_v = bm.verts.new(Vector((0, 0, 0.09)))
    rings = []
    for ri, base_r in enumerate(rings_radii):
        ring = []
        for s in range(segs):
            a = math.tau * s / segs
            wobble = 1.0 + (0.16 * math.sin(a * 4.0 + 0.4) + 0.10 * math.cos(a * 3.0)) * ((ri + 1) / 3.0)
            r = base_r * wobble
            z = 0.085 if ri == 0 else (0.062 if ri == 1 else 0.012)
            ring.append(bm.verts.new(Vector((math.cos(a) * r, math.sin(a) * r, z))))
        rings.append(ring)

    for s in range(segs):
        bm.faces.new((center_v, rings[0][s], rings[0][(s + 1) % segs]))
    for ri in range(len(rings) - 1):
        for s in range(segs):
            s1 = (s + 1) % segs
            bm.faces.new((rings[ri][s], rings[ri + 1][s], rings[ri + 1][s1], rings[ri][s1]))

    # 3 glossy smooth bubblegum bubbles rising from the puddle
    bubbles = [
        (Vector((0.20, 0.16, 0.11)), 0.24),
        (Vector((-0.26, -0.05, 0.09)), 0.16),
        (Vector((-0.05, -0.30, 0.08)), 0.12),
    ]
    for pos, rad in bubbles:
        bmesh.ops.create_icosphere(bm, subdivisions=2 if rad > 0.18 else 1, radius=rad,
                                   matrix=Matrix.Translation(pos) @ Matrix.Diagonal((1.0, 1.0, 0.78, 1.0)))

    u, v = swatch_uv(33)
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            loop[uv].uv = (u, v)
            w = min(1.0, Vector((loop.vert.co.x, loop.vert.co.y)).length / 0.96)
            loop[col_layer] = (w, w, w, 1.0)

    return finalize_mesh("W1_09_Bubblegum", bm, gum_mat)


# ---------------------------------------------------------------------------
# 4. Export & Automated QA Verification
# ---------------------------------------------------------------------------
def count_tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export_glb(obj, out_path):
    bpy.ops.object.select_all(action="DESELECT")
    orig_loc = obj.location.copy()
    obj.location = Vector((0.0, 0.0, 0.0))
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_image_format="WEBP",
        export_image_quality=80,
        export_normals=True,
        export_texcoords=True,
    )
    obj.location = orig_loc
    return os.path.getsize(out_path) / 1024.0


def run():
    clear_scene()

    # Build textures (incl. W1-03 painted seeds & VFX-M1 4-in-1 particle atlas)
    pal_img = build_palette_atlas(os.path.join(TEX_OUT, "w1_palette_atlas.png"), size=128)
    marble_img = build_marble_tile_texture(os.path.join(TEX_OUT, "w1_01_marble_tile.png"), size=512)
    boba_img = build_boba_texture(os.path.join(TEX_OUT, "w1_06_boba_tex.png"), size=256)
    berry_img = build_strawberry_texture(os.path.join(TEX_OUT, "w1_03_strawberry_tex.png"), size=256)
    build_vfx_m1_atlas(os.path.join(TEX_OUT, "vfx_m1_atlas.png"), size=256)

    # Materials (strictly 1 material per object)
    pal_mat = make_atlas_material("M_GlossyVinylAtlas", pal_img, roughness=0.22, metallic=0.04)
    ice_mat = make_atlas_material("M_IceCrystal", pal_img, roughness=0.08, metallic=0.05, alpha=0.82, emission_strength=0.18)
    gummy_mat = make_atlas_material("M_GummyJelly", pal_img, roughness=0.12, metallic=0.02, alpha=0.88)
    gum_mat = make_atlas_material("M_Bubblegum", pal_img, roughness=0.15, metallic=0.03)
    marble_mat = make_atlas_material("M_W1Marble", marble_img, roughness=0.28, metallic=0.02)
    boba_mat = make_atlas_material("M_W1Boba", boba_img, roughness=0.20, metallic=0.02)
    berry_mat = make_atlas_material("M_W1Strawberry", berry_img, roughness=0.18, metallic=0.03)

    assets_spec = [
        ("CORE-01", build_core_01_hole(pal_mat, False), os.path.join(CORE_OUT, "core_01_base_hole.glb"), 650, 85),
        ("CORE-02", build_core_01_hole(pal_mat, True),  os.path.join(CORE_OUT, "core_02_fever_hole.glb"), 700, 90),
        ("CORE-03", build_core_03_ice_cube(ice_mat),    os.path.join(CORE_OUT, "core_03_ice_cube.glb"), 320, 35),
        ("CORE-04", build_core_04_magnet(pal_mat),      os.path.join(CORE_OUT, "core_04_magnet.glb"), 420, 40),
        ("W1-01",   build_w1_01_tabletop(marble_mat),   os.path.join(W1_OUT,   "w1_01_tabletop.glb"), 120, 65),
        ("W1-02",   build_w1_02_sprinkle(pal_mat),      os.path.join(W1_OUT,   "w1_02_sprinkle.glb"), 80, 12),
        ("W1-03",   build_w1_03_strawberry(berry_mat),  os.path.join(W1_OUT,   "w1_03_strawberry.glb"), 260, 28),
        ("W1-04",   build_w1_04_gummy_bear(gummy_mat),  os.path.join(W1_OUT,   "w1_04_gummy_bear.glb"), 380, 38),
        ("W1-05",   build_w1_05_macaron(pal_mat),       os.path.join(W1_OUT,   "w1_05_macaron.glb"), 320, 32),
        ("W1-06",   build_w1_06_boba_tea(boba_mat),     os.path.join(W1_OUT,   "w1_06_boba_tea.glb"), 450, 45),
        ("W1-07",   build_w1_07_donut(pal_mat),         os.path.join(W1_OUT,   "w1_07_donut.glb"), 520, 58),
        ("W1-08",   build_w1_08_cake(pal_mat),          os.path.join(W1_OUT,   "w1_08_cake.glb"), 980, 95),
        ("W1-09",   build_w1_09_bubblegum(gum_mat),     os.path.join(W1_OUT,   "w1_09_bubblegum.glb"), 480, 42),
    ]

    qa_report = []
    total_tris = 0
    total_kb = 0.0

    for aid, obj, out_path, max_tris, max_kb in assets_spec:
        tris = count_tris(obj)
        mats = len(obj.data.materials)
        kb = export_glb(obj, out_path)
        total_tris += tris
        total_kb += kb
        qa_report.append({
            "id": aid,
            "name": obj.name,
            "tris": tris,
            "max_tris": max_tris,
            "tris_ok": tris <= max_tris,
            "materials": mats,
            "kb": round(kb, 1),
            "max_kb": max_kb,
            "kb_ok": kb <= max_kb,
        })

    # Arrange all models neatly on a bright showcase grid in Blender viewport (hide huge W1-01 beneath)
    grid_objs = [spec[1] for spec in assets_spec if spec[0] != "W1-01"]
    table_obj = [spec[1] for spec in assets_spec if spec[0] == "W1-01"][0]
    table_obj.location = Vector((0.0, 0.0, -0.36))

    for idx, obj in enumerate(grid_objs):
        col = idx % 4
        row = idx // 4
        obj.location = Vector(((col - 1.5) * 2.8, (1.0 - row) * 2.8, 0.0))

    # Bright studio lighting + showcase camera
    world = bpy.data.worlds.new("StudioWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.93, 0.97, 0.95, 1.0)
        bg.inputs["Strength"].default_value = 0.85

    sun_data = bpy.data.lights.new("KeySun", type="SUN")
    sun_data.energy = 2.8
    sun_obj = bpy.data.objects.new("KeySun", sun_data)
    bpy.context.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = Euler((math.radians(48), math.radians(15), math.radians(32)))

    cam_data = bpy.data.cameras.new("ShowcaseCam")
    cam_data.lens = 42.0
    cam_obj = bpy.data.objects.new("ShowcaseCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_obj.location = Vector((0.0, -9.8, 8.6))
    direction = Vector((0.0, 0.2, 0.3)) - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam_obj

    # Render fast showcase preview with EEVEE
    scene = bpy.context.scene
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.filepath = SHOWCASE_IMG
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

    summary = {
        "total_3d_assets": len(qa_report),
        "total_tris": total_tris,
        "budget_tris": 5692,
        "total_kb": round(total_kb, 1),
        "budget_kb": 833,
        "all_pass": all(r["tris_ok"] and r["kb_ok"] and r["materials"] == 1 for r in qa_report),
        "items": qa_report,
    }
    print("QA_REPORT_JSON:" + json.dumps(summary, ensure_ascii=False))


run()
