"""
Gobble Pop! — World 3 (Neon Bento Street) + World 4 (Cozy Alchemist Desk) + CORE-05 Time Bomb
Blender 5.3.0 Asset Builder & Automated QA Gate.
Strictly enforces Google Sheet budgets:
  - World 3 (6 assets): <= 2,640 Tris, <= 332 KB
  - World 4 (7 assets): <= 3,010 Tris, <= 373 KB
  - CORE-05 Time Bomb:  <= 260 Tris, <= 24 KB
  - 1 Material per asset (single DrawCall), bottom-center origin, smooth normals
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
W3_OUT = os.path.join(ROOT, "assets/models/world3")
W4_OUT = os.path.join(ROOT, "assets/models/world4")
TEX_OUT = os.path.join(ROOT, "assets/textures")
SHOWCASE_W3 = os.path.join(ROOT, "assets/refs_2d/blender_world3_showcase.png")
SHOWCASE_W4 = os.path.join(ROOT, "assets/refs_2d/blender_world4_showcase.png")

for d in (CORE_OUT, W3_OUT, W4_OUT, TEX_OUT):
    os.makedirs(d, exist_ok=True)


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for col in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for item in list(col):
            if item.users == 0:
                col.remove(item)
    for img in list(bpy.data.images):
        if img.users == 0 and img.name != "Render Result":
            bpy.data.images.remove(img)


def hex_rgba(h, a=1.0):
    h = h.lstrip("#")
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, a)


PALETTE_W34 = [
    # Row 0: World 3 Neon Bento Street + Bomb
    "#FFFDF7",  # 0: Sushi Rice / Ceramic White
    "#1E293B",  # 1: Nori Seaweed / Lacquer Black / Bomb Body
    "#FF6B3D",  # 2: Glossy Salmon Orange
    "#FFD166",  # 3: Tamago Egg / Ramen Broth Gold
    "#B5651D",  # 4: Takoyaki Golden Crust
    "#5C2C16",  # 5: Glossy Teriyaki Sauce
    "#FFF3C4",  # 6: Creamy Mayo Drizzle
    "#22C55E",  # 7: Green Scallion / Nori Flake
    "#E11D48",  # 8: Lacquer Red Trim / Narutomaki / Bomb Danger Band
    "#C2410C",  # 9: Chashu Pork Brown
    "#FF9F1C",  # 10: Egg Yolk Deep Orange / Fuse Spark
    "#FFC300",  # 11: Melted Cheddar Cheese Gold
    "#FFF1A8",  # 12: Cheese Specular Highlight
    "#FF3B30",  # 13: Bomb Glowing Red Fuse Tip
    "#94A3B8",  # 14: Bomb Metallic Collar
    "#FB7185",  # 15: Pink Narutomaki / Tempura Accent
    # Row 1: World 4 Cozy Alchemist Desk
    "#8B5CF6",  # 16: Crystal D20 Violet-Blue / Spellbook Leather
    "#38BDF8",  # 17: Potion Blue / Slime Cyan
    "#F472B6",  # 18: Potion Pink / Slime Pink
    "#FACC15",  # 19: Gold Trim / Slime Yellow
    "#D97706",  # 20: Cork Stopper Warm Brown
    "#E0F2FE",  # 21: Glass Bottle Rim Tint
    "#2DD4BF",  # 22: Spellbook Turquoise Gem
    "#4C1D95",  # 23: Alchemy Cauldron Deep Pearl Purple
    "#A855F7",  # 24: Bubbling Magic Violet Potion
    "#E9D5FF",  # 25: Magic Potion Foam Highlight
    "#39FF14",  # 26: Neon Green Slime Puddle
    "#C8FFBE",  # 27: Slime Highlight
    "#FEF9C3",  # 28: Book Pages Cream
    "#0F172A",  # 29: Slime Cute Dark Eyes
    "#FFFFFF",  # 30: Pure White Specular
    "#FF8FA3",  # 31: Slime Cheek Blush
]


def build_palette(path, size=128):
    grid = 8
    cell = size // grid
    arr = np.ones((size, size, 4), dtype=np.float32)
    for idx, hx in enumerate(PALETTE_W34):
        r, g, b, a = hex_rgba(hx)
        row, col = idx // grid, idx % grid
        arr[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell] = (r, g, b, a)
    img = bpy.data.images.new("W34PaletteAtlas", width=size, height=size, alpha=True)
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def sw_uv(idx, grid=8):
    return ((idx % grid + 0.5) / grid, (idx // grid + 0.5) / grid)


def build_checker_tex(name, path, col_a, col_b, seam_dark=0.06, size=512, velvet=False):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    cx = (x * 4.0).astype(np.int32) % 2
    cy = (y * 4.0).astype(np.int32) % 2
    chk = ((cx + cy) % 2).astype(np.float32)
    a = np.array(col_a, dtype=np.float32)
    b = np.array(col_b, dtype=np.float32)
    rgb = a[None, None, :] * (1.0 - chk[:, :, None]) + b[None, None, :] * chk[:, :, None]

    if velvet:
        # Cozy subtle diagonal woven velvet sheen
        weave = (np.sin((x + y) * math.tau * 24.0) * 0.015 + np.cos((x - y) * math.tau * 24.0) * 0.015)
        rgb = np.clip(rgb + weave[:, :, None], 0.0, 1.0)
    else:
        # Lacquer gloss subtle woodgrain streak
        grain = np.sin(y * math.tau * 12.0 + np.sin(x * math.tau * 3.0) * 0.5) * 0.018
        rgb = np.clip(rgb + grain[:, :, None], 0.0, 1.0)

    gx = np.abs(((x * 4.0) % 1.0) - 0.5) * 2.0
    gy = np.abs(((y * 4.0) % 1.0) - 0.5) * 2.0
    seam = np.clip((np.maximum(gx, gy) - 0.96) / 0.04, 0.0, 1.0) * seam_dark
    rgb = np.clip(rgb - seam[:, :, None], 0.0, 1.0)

    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    img = bpy.data.images.new(name, width=size, height=size, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def make_mat(name, img, roughness=0.20, metallic=0.04, alpha=1.0, emission=0.0):
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
        bsdf.inputs["Coat Weight"].default_value = 0.60 if roughness < 0.35 else 0.1
    if alpha < 0.99:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
    if emission > 0.0 and "Emission Strength" in bsdf.inputs:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def add_part(bm, uv, sw_idx, fn):
    before = set(bm.faces)
    fn(bm)
    u, v = sw_uv(sw_idx)
    for f in bm.faces:
        if f not in before:
            f.smooth = True
            for loop in f.loops:
                loop[uv].uv = (u, v)


def make_lathe(bm, profile_rz, segs=16, offset=Vector((0, 0, 0))):
    rings = []
    for r, z in profile_rz:
        if r <= 1e-5:
            rings.append([bm.verts.new(Vector((0.0, 0.0, z)) + offset)])
        else:
            ring = [bm.verts.new(Vector((math.cos(math.tau * s / segs) * r,
                                         math.sin(math.tau * s / segs) * r, z)) + offset) for s in range(segs)]
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


def finalize(name, bm, mat):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if len(bm.verts) > 0:
        min_z = min(v.co.z for v in bm.verts)
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        cx, cy = 0.5 * (min(xs) + max(xs)), 0.5 * (min(ys) + max(ys))
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


# ---------------------------------------------------------------------------
# CORE-05: Candy Time Bomb Hazard (World 3 & 4, -3s penalty!)
# ---------------------------------------------------------------------------
def build_core_05_bomb(pal_mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Glossy charcoal sphere body
    add_part(bm, uv, 1, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=0.38, matrix=Matrix.Translation((0, 0, 0.38))))
    # Red warning band around equator
    add_part(bm, uv, 8, lambda b: bmesh.ops.create_cone(
        b, cap_ends=False, cap_tris=False, segments=14, radius1=0.395, radius2=0.395, depth=0.11,
        matrix=Matrix.Translation((0, 0, 0.38))))
    # Metallic fuse collar
    add_part(bm, uv, 14, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=10, radius1=0.14, radius2=0.12, depth=0.12,
        matrix=Matrix.Translation((0, 0, 0.76))))
    # Curved spark fuse + glowing red-gold tip
    add_part(bm, uv, 6, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=6, radius1=0.035, radius2=0.03, depth=0.22,
        matrix=Matrix.Translation((0.05, 0, 0.89)) @ Matrix.Rotation(math.radians(22), 4, "Y")))
    add_part(bm, uv, 13, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=0.095, matrix=Matrix.Translation((0.10, 0, 1.00))))
    return finalize("CORE_05_TimeBomb", bm, pal_mat)


# ---------------------------------------------------------------------------
# WORLD 3: NEON BENTO STREET (6 assets, <= 2,640 Tris, <= 332 KB)
# ---------------------------------------------------------------------------
def build_table_slab(name, mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co.x *= 20.0
        v.co.y *= 24.0
        v.co.z = (v.co.z + 0.5) * 0.35
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.18, segments=1, affect="EDGES", clamp_overlap=True)
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co.x * 0.2 + 0.5, loop.vert.co.y * 0.2 + 0.5)
    return finalize(name, bm, mat)


def build_w3_02_sushi(pal_mat):
    """Chunky glossy salmon nigiri sushi (<= 280 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Rounded rice pillow
    add_part(bm, uv, 0, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((0, 0, 0.14)) @ Matrix.Diagonal((0.36, 0.22, 0.15, 1.0))))
    # Plump glossy salmon topping
    add_part(bm, uv, 2, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=1.0,
        matrix=Matrix.Translation((0, 0, 0.27)) @ Matrix.Diagonal((0.42, 0.25, 0.10, 1.0))))
    # Crisp dark nori seaweed belt
    add_part(bm, uv, 1, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.20)) @ Matrix.Diagonal((0.14, 0.48, 0.34, 1.0))))
    return finalize("W3_02_Sushi", bm, pal_mat)


def build_w3_03_takoyaki(pal_mat):
    """Plump glazed takoyaki ball with teriyaki cap & mayo ribbons (<= 260 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Golden fried ball
    add_part(bm, uv, 4, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=0.32, matrix=Matrix.Translation((0, 0, 0.30))))
    # Glossy brown teriyaki sauce cap
    add_part(bm, uv, 5, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((0, 0, 0.50)) @ Matrix.Diagonal((0.26, 0.26, 0.12, 1.0))))
    # 2 creamy mayo zig-zag stripes + green nori flecks
    for sy in (-0.08, 0.08):
        add_part(bm, uv, 6, lambda b, y=sy: bmesh.ops.create_cube(
            b, size=1.0, matrix=Matrix.Translation((0, y, 0.60)) @ Matrix.Diagonal((0.38, 0.05, 0.04, 1.0))))
    add_part(bm, uv, 7, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.63)) @ Matrix.Diagonal((0.12, 0.12, 0.03, 1.0))))
    return finalize("W3_03_Takoyaki", bm, pal_mat)


def build_w3_04_ramen(pal_mat):
    """Chunky ceramic ramen bowl with golden broth, chashu, soft egg & narutomaki (<= 580 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 16
    # Outer red-and-black ceramic bowl
    add_part(bm, uv, 8, lambda b: make_lathe(b, [
        (0.0, 0.0), (0.36, 0.0), (0.40, 0.10), (0.64, 0.42), (0.70, 0.62), (0.64, 0.64)
    ], segs=segs))
    # Rich golden broth surface
    add_part(bm, uv, 3, lambda b: make_lathe(b, [(0.64, 0.54), (0.0, 0.54)], segs=segs))
    # Soft-boiled egg half (white + orange yolk)
    add_part(bm, uv, 0, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((-0.24, -0.14, 0.57)) @ Matrix.Diagonal((0.18, 0.22, 0.07, 1.0))))
    add_part(bm, uv, 10, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((-0.24, -0.14, 0.62)) @ Matrix.Diagonal((0.10, 0.11, 0.05, 1.0))))
    # 2 Chashu pork slices
    for ang, ox, oy in [(0.3, 0.24, -0.10), (-0.4, 0.18, 0.22)]:
        add_part(bm, uv, 9, lambda b, a=ang, x=ox, y=oy: bmesh.ops.create_cone(
            b, cap_ends=True, cap_tris=False, segments=8, radius1=0.18, radius2=0.18, depth=0.06,
            matrix=Matrix.Translation((x, y, 0.58)) @ Matrix.Rotation(a, 4, "Z")))
    # Pink narutomaki fishcake + green scallions + nori sheet
    add_part(bm, uv, 15, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=8, radius1=0.13, radius2=0.13, depth=0.06,
        matrix=Matrix.Translation((-0.14, 0.26, 0.58))))
    add_part(bm, uv, 7, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=0.11, matrix=Matrix.Translation((0.02, 0.04, 0.58))))
    add_part(bm, uv, 1, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0.0, 0.52, 0.72)) @ Matrix.Rotation(math.radians(-18), 4, "X") @ Matrix.Diagonal((0.36, 0.04, 0.34, 1.0))))
    return finalize("W3_04_Ramen", bm, pal_mat)


def build_w3_05_bento(pal_mat):
    """Lv.4-5 Boss: Giant Deluxe Black-Red Lacquer Bento Box full of colorful dishes (<= 920 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Glossy black outer lacquer box + red inner rim & cross dividers
    add_part(bm, uv, 1, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.34)) @ Matrix.Diagonal((2.50, 2.10, 0.68, 1.0))))
    add_part(bm, uv, 8, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.68)) @ Matrix.Diagonal((2.32, 1.92, 0.08, 1.0))))
    add_part(bm, uv, 8, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.74)) @ Matrix.Diagonal((2.28, 0.12, 0.14, 1.0))))
    add_part(bm, uv, 8, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.74)) @ Matrix.Diagonal((0.12, 1.88, 0.14, 1.0))))

    # Quadrant 1 (Top-Left): White rice bed + red pickled plum (umeboshi)
    add_part(bm, uv, 0, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((-0.58, 0.48, 0.75)) @ Matrix.Diagonal((0.96, 0.76, 0.16, 1.0))))
    add_part(bm, uv, 8, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=0.18, matrix=Matrix.Translation((-0.58, 0.48, 0.88))))

    # Quadrant 2 (Top-Right): 3 Salmon Sushi pieces
    for sx in (-0.28, 0.0, 0.28):
        add_part(bm, uv, 2, lambda b, x=sx: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=1.0,
            matrix=Matrix.Translation((0.58 + x, 0.48, 0.84)) @ Matrix.Diagonal((0.16, 0.32, 0.14, 1.0))))

    # Quadrant 3 (Bottom-Left): Golden Tamago egg blocks + crisp green broccoli/edamame
    for sy in (-0.22, 0.18):
        add_part(bm, uv, 3, lambda b, y=sy: bmesh.ops.create_cube(
            b, size=1.0, matrix=Matrix.Translation((-0.72, -0.48 + y, 0.80)) @ Matrix.Diagonal((0.56, 0.28, 0.22, 1.0))))
    for by in (-0.26, 0.0, 0.26):
        add_part(bm, uv, 7, lambda b, y=by: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.14, matrix=Matrix.Translation((-0.26, -0.48 + y, 0.84))))

    # Quadrant 4 (Bottom-Right): 2 Crispy Tempura Shrimp + Takoyaki
    for sy in (-0.20, 0.20):
        add_part(bm, uv, 10, lambda b, y=sy: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=1.0,
            matrix=Matrix.Translation((0.56, -0.48 + y, 0.84)) @ Matrix.Diagonal((0.40, 0.16, 0.15, 1.0))))
        add_part(bm, uv, 15, lambda b, y=sy: bmesh.ops.create_cone(
            b, cap_ends=True, cap_tris=False, segments=4, radius1=0.14, radius2=0.04, depth=0.22,
            matrix=Matrix.Translation((0.96, -0.48 + y, 0.86)) @ Matrix.Rotation(math.radians(90), 4, "Y")))

    return finalize("W3_05_Bento", bm, pal_mat)


def build_sticky_puddle(name, mat, sw_idx):
    """Shared stretchy radial puddle for W3-06 Melted Cheese & W4-07 Slime Trap (<= 300 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    segs = 28
    radii = [0.34, 0.72, 0.98]
    cv = bm.verts.new(Vector((0, 0, 0.09)))
    rings = []
    for ri, br in enumerate(radii):
        ring = []
        for s in range(segs):
            a = math.tau * s / segs
            wob = 1.0 + (0.17 * math.sin(a * 4.0 + 0.7) + 0.10 * math.cos(a * 3.0)) * ((ri + 1) / 3.0)
            r = br * wob
            z = 0.085 if ri == 0 else (0.06 if ri == 1 else 0.012)
            ring.append(bm.verts.new(Vector((math.cos(a) * r, math.sin(a) * r, z))))
        rings.append(ring)
    for s in range(segs):
        bm.faces.new((cv, rings[0][s], rings[0][(s + 1) % segs]))
    for ri in range(len(rings) - 1):
        for s in range(segs):
            s1 = (s + 1) % segs
            bm.faces.new((rings[ri][s], rings[ri + 1][s], rings[ri + 1][s1], rings[ri][s1]))
    for pos, rad in [(Vector((0.22, 0.14, 0.11)), 0.22), (Vector((-0.24, -0.10, 0.09)), 0.15)]:
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=rad,
                                   matrix=Matrix.Translation(pos) @ Matrix.Diagonal((1.0, 1.0, 0.75, 1.0)))
    u, v = sw_uv(sw_idx)
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            loop[uv].uv = (u, v)
            w = min(1.0, Vector((loop.vert.co.x, loop.vert.co.y)).length / 0.98)
            loop[col] = (w, w, w, 1.0)
    return finalize(name, bm, mat)


# ---------------------------------------------------------------------------
# WORLD 4: COZY ALCHEMIST DESK (7 assets, <= 3,010 Tris, <= 373 KB)
# ---------------------------------------------------------------------------
def build_w4_02_d20(crystal_mat):
    """Faceted crystal icosahedron D20 die (20 tris -> ultra crisp!)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_part(bm, uv, 16, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=0.34, matrix=Matrix.Translation((0, 0, 0.32))))
    obj = finalize("W4_02_CrystalD20", bm, crystal_mat)
    # Keep crystal D20 crisp flat-faceted!
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def build_w4_03_slime(jelly_mat):
    """Cute chubby kawaii jelly slime with dark glossy eyes (<= 320 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Squishy dome teardrop body
    add_part(bm, uv, 17, lambda b: make_lathe(b, [
        (0.0, 0.0), (0.34, 0.0), (0.42, 0.12), (0.38, 0.30), (0.24, 0.44), (0.08, 0.50), (0.0, 0.52)
    ], segs=16))
    # Cute dark eyes & pink cheeks
    for sx in (-0.13, 0.13):
        add_part(bm, uv, 29, lambda b, x=sx: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.055, matrix=Matrix.Translation((x, -0.36, 0.24))))
        add_part(bm, uv, 31, lambda b, x=sx: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.045, matrix=Matrix.Translation((x * 1.45, -0.34, 0.18))))
    return finalize("W4_03_Slime", bm, jelly_mat)


def build_w4_04_potion(pal_mat):
    """Round chunky glowing magic potion flask with cork stopper (<= 440 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 14
    # Glowing potion bulb (pink default, tinted blue for variant 2)
    add_part(bm, uv, 18, lambda b: make_lathe(b, [
        (0.0, 0.0), (0.28, 0.02), (0.44, 0.22), (0.46, 0.42), (0.36, 0.62), (0.16, 0.72)
    ], segs=segs))
    # Glass neck & flared lip
    add_part(bm, uv, 21, lambda b: make_lathe(b, [
        (0.16, 0.70), (0.16, 0.88), (0.23, 0.92), (0.23, 0.98), (0.15, 0.98)
    ], segs=segs))
    # Rounded cork stopper
    add_part(bm, uv, 20, lambda b: make_lathe(b, [
        (0.14, 0.94), (0.17, 1.12), (0.12, 1.18), (0.0, 1.19)
    ], segs=10))
    return finalize("W4_04_Potion", bm, pal_mat)


def build_w4_05_spellbook(pal_mat):
    """Thick chunky purple leather spellbook with gold clasps & glowing turquoise gem (<= 520 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Cream page block
    add_part(bm, uv, 28, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0.04, 0, 0.22)) @ Matrix.Diagonal((1.16, 1.42, 0.34, 1.0))))
    # Purple leather top/bottom covers & spine
    for cz in (0.04, 0.40):
        add_part(bm, uv, 16, lambda b, z=cz: bmesh.ops.create_cube(
            b, size=1.0, matrix=Matrix.Translation((0, 0, z)) @ Matrix.Diagonal((1.30, 1.56, 0.08, 1.0))))
    add_part(bm, uv, 16, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((-0.62, 0, 0.22)) @ Matrix.Diagonal((0.12, 1.56, 0.44, 1.0))))
    # Gold corner brackets + center frame
    for gx in (-0.54, 0.54):
        for gy in (-0.66, 0.66):
            add_part(bm, uv, 19, lambda b, x=gx, y=gy: bmesh.ops.create_cube(
                b, size=1.0, matrix=Matrix.Translation((x, y, 0.45)) @ Matrix.Diagonal((0.24, 0.24, 0.06, 1.0))))
    add_part(bm, uv, 19, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=8, radius1=0.34, radius2=0.30, depth=0.06,
        matrix=Matrix.Translation((0.04, 0, 0.45))))
    # Glowing turquoise center gem
    add_part(bm, uv, 22, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((0.04, 0, 0.51)) @ Matrix.Diagonal((0.22, 0.28, 0.12, 1.0))))
    return finalize("W4_05_Spellbook", bm, pal_mat)


def build_w4_06_cauldron(pal_mat):
    """Lv.4-5 Boss: Gold-trimmed purple pearl alchemy cauldron with bubbling glowing brew (<= 950 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 20
    # Plump deep pearl-purple cauldron belly
    add_part(bm, uv, 23, lambda b: make_lathe(b, [
        (0.0, 0.14), (0.70, 0.18), (1.18, 0.52), (1.34, 0.96), (1.22, 1.42), (0.98, 1.66)
    ], segs=segs))
    # Gleaming gold rim collar + belly band
    add_part(bm, uv, 19, lambda b: make_lathe(b, [
        (0.96, 1.64), (1.16, 1.72), (1.16, 1.88), (0.94, 1.88), (0.90, 1.66)
    ], segs=segs))
    # 3 chunky golden cauldron feet
    for i in range(3):
        a = math.tau * i / 3.0
        add_part(bm, uv, 19, lambda b, ang=a: bmesh.ops.create_cone(
            b, cap_ends=True, cap_tris=False, segments=8, radius1=0.24, radius2=0.18, depth=0.34,
            matrix=Matrix.Translation((math.cos(ang) * 0.72, math.sin(ang) * 0.72, 0.17))))
    # Glowing violet bubbling potion surface + rising foam bubbles
    add_part(bm, uv, 24, lambda b: make_lathe(b, [(0.92, 1.72), (0.0, 1.74)], segs=segs))
    for bx, by, bz, br in [(0.0, 0.0, 1.92, 0.34), (-0.42, 0.25, 1.86, 0.22), (0.44, -0.18, 1.88, 0.25),
                           (-0.22, -0.44, 1.82, 0.18), (0.28, 0.42, 1.84, 0.20)]:
        add_part(bm, uv, 25 if br < 0.24 else 24, lambda b, x=bx, y=by, z=bz, r=br: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=r, matrix=Matrix.Translation((x, y, z))))
    return finalize("W4_06_Cauldron", bm, pal_mat)


def count_tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export_glb(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    orig = obj.location.copy()
    obj.location = Vector((0, 0, 0))
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_materials="EXPORT", export_image_format="WEBP",
        export_image_quality=80, export_normals=True, export_texcoords=True,
    )
    obj.location = orig
    return os.path.getsize(path) / 1024.0


def render_showcase(table_obj, props, bg_col, out_img):
    table_obj.location = Vector((0, 0, -0.36))
    for i, obj in enumerate(props):
        col = i % 4
        row = i // 4
        obj.location = Vector(((col - 1.5) * 3.4, (0.6 - row) * 3.6, 0.0))

    world = bpy.data.worlds.new("ShowWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = bg_col
        bg.inputs["Strength"].default_value = 0.9

    sd = bpy.data.lights.new("Sun", type="SUN")
    sd.energy = 3.0
    so = bpy.data.objects.new("Sun", sd)
    bpy.context.collection.objects.link(so)
    so.rotation_euler = Euler((math.radians(46), math.radians(18), math.radians(30)))

    cd = bpy.data.cameras.new("Cam")
    cd.lens = 40.0
    co = bpy.data.objects.new("Cam", cd)
    bpy.context.collection.objects.link(co)
    co.location = Vector((0, -11.5, 9.2))
    co.rotation_euler = (Vector((0, 0, 0.6)) - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co

    sc = bpy.context.scene
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.render.filepath = out_img
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


def run():
    clear_scene()
    pal_img = build_palette(os.path.join(TEX_OUT, "w34_palette_atlas.png"), size=128)
    w3_tile = build_checker_tex("W3LacquerTile", os.path.join(TEX_OUT, "w3_01_table_tile.png"),
                                (0.98, 0.56, 0.42), (0.99, 0.95, 0.88), seam_dark=0.07, velvet=False)
    w4_tile = build_checker_tex("W4VelvetTile", os.path.join(TEX_OUT, "w4_01_desk_tile.png"),
                                (0.78, 0.72, 0.96), (0.98, 0.96, 0.94), seam_dark=0.05, velvet=True)

    pal_mat = make_mat("M_W34Vinyl", pal_img, roughness=0.18, metallic=0.05)
    crystal_mat = make_mat("M_W4Crystal", pal_img, roughness=0.08, metallic=0.06, alpha=0.86, emission=0.12)
    jelly_mat = make_mat("M_W4Jelly", pal_img, roughness=0.10, metallic=0.02, alpha=0.88)
    w3_tmat = make_mat("M_W3Table", w3_tile, roughness=0.22, metallic=0.03)
    w4_tmat = make_mat("M_W4Desk", w4_tile, roughness=0.52, metallic=0.0)

    # --- Build World 3 + CORE-05 Bomb ---
    w3_specs = [
        ("W3-01", build_table_slab("W3_01_Tabletop", w3_tmat), os.path.join(W3_OUT, "w3_01_tabletop.glb"), 120, 62),
        ("W3-02", build_w3_02_sushi(pal_mat),                  os.path.join(W3_OUT, "w3_02_sushi.glb"),    280, 34),
        ("W3-03", build_w3_03_takoyaki(pal_mat),               os.path.join(W3_OUT, "w3_03_takoyaki.glb"), 260, 32),
        ("W3-04", build_w3_04_ramen(pal_mat),                  os.path.join(W3_OUT, "w3_04_ramen.glb"),    580, 64),
        ("W3-05", build_w3_05_bento(pal_mat),                  os.path.join(W3_OUT, "w3_05_bento.glb"),    920, 96),
        ("W3-06", build_sticky_puddle("W3_06_Cheese", pal_mat, 11), os.path.join(W3_OUT, "w3_06_cheese.glb"), 480, 44),
        ("CORE-05", build_core_05_bomb(pal_mat),               os.path.join(CORE_OUT, "core_05_bomb.glb"), 260, 24),
    ]
    qa3 = []
    for aid, obj, path, mt, mk in w3_specs:
        t, kb = count_tris(obj), export_glb(obj, path)
        qa3.append({"id": aid, "tris": t, "max_tris": mt, "tris_ok": t <= mt, "kb": round(kb, 1), "max_kb": mk, "kb_ok": kb <= mk})
    render_showcase(w3_specs[0][1], [s[1] for s in w3_specs[1:]], (1.0, 0.90, 0.85, 1.0), SHOWCASE_W3)

    # Clear W3 objects before building W4 showcase
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    # --- Build World 4 ---
    w4_specs = [
        ("W4-01", build_table_slab("W4_01_Desk", w4_tmat),          os.path.join(W4_OUT, "w4_01_tabletop.glb"),   120, 62),
        ("W4-02", build_w4_02_d20(crystal_mat),                     os.path.join(W4_OUT, "w4_02_d20.glb"),        180, 26),
        ("W4-03", build_w4_03_slime(jelly_mat),                     os.path.join(W4_OUT, "w4_03_slime.glb"),      320, 35),
        ("W4-04", build_w4_04_potion(pal_mat),                      os.path.join(W4_OUT, "w4_04_potion.glb"),     440, 48),
        ("W4-05", build_w4_05_spellbook(pal_mat),                   os.path.join(W4_OUT, "w4_05_spellbook.glb"),  520, 60),
        ("W4-06", build_w4_06_cauldron(pal_mat),                    os.path.join(W4_OUT, "w4_06_cauldron.glb"),   950, 98),
        ("W4-07", build_sticky_puddle("W4_07_SlimeTrap", pal_mat, 26), os.path.join(W4_OUT, "w4_07_slime_trap.glb"), 480, 44),
    ]
    qa4 = []
    for aid, obj, path, mt, mk in w4_specs:
        t, kb = count_tris(obj), export_glb(obj, path)
        qa4.append({"id": aid, "tris": t, "max_tris": mt, "tris_ok": t <= mt, "kb": round(kb, 1), "max_kb": mk, "kb_ok": kb <= mk})
    render_showcase(w4_specs[0][1], [s[1] for s in w4_specs[1:]], (0.93, 0.90, 1.0, 1.0), SHOWCASE_W4)

    summary = {
        "w3_tris": sum(r["tris"] for r in qa3 if r["id"].startswith("W3")),
        "w3_kb": round(sum(r["kb"] for r in qa3 if r["id"].startswith("W3")), 1),
        "w4_tris": sum(r["tris"] for r in qa4),
        "w4_kb": round(sum(r["kb"] for r in qa4), 1),
        "all_pass": all(r["tris_ok"] and r["kb_ok"] for r in qa3 + qa4),
        "w3": qa3,
        "w4": qa4,
    }
    print("W34_QA_JSON:" + json.dumps(summary, ensure_ascii=False))


run()
