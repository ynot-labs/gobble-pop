"""
Gobble Pop! — World 2 "Gacha Toybox" 3D Asset Builder (8 GLB Models + Butter-Yellow Playmat Texture)
Blender 5.3.0 headless / MCP-compatible (never calls read_factory_settings).
Strictly enforces Google Sheet budgets:
  - Total World 2 Tris <= 3,850
  - Total World 2 Size <= 442 KB
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
W2_OUT = os.path.join(ROOT, "assets/models/world2")
TEX_OUT = os.path.join(ROOT, "assets/textures")
BLEND_OUT = os.path.join(ROOT, "assets/blender_src/world2_showcase.blend")
SHOWCASE_IMG = os.path.join(ROOT, "assets/refs_2d/blender_world2_showcase.png")

for d in (W2_OUT, TEX_OUT, os.path.dirname(BLEND_OUT)):
    os.makedirs(d, exist_ok=True)


def clear_scene():
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


def hex_rgba(h, a=1.0):
    h = h.lstrip("#")
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, a)


W2_PALETTE = [
    "#FF6B9D",  # 0: Block Coral Pink / Unicorn Mane
    "#4CC9F0",  # 1: Block Sky Blue / Duck Wing
    "#6EE7B7",  # 2: Block Mint Green
    "#C084FC",  # 3: Block Lavender / Figurine Body
    "#FF92C2",  # 4: Duck Soft Pink Body
    "#FF9F1C",  # 5: Duck Orange Beak / Gold Trim
    "#1E293B",  # 6: Glossy Dark Eye / Arcade Bezel
    "#FFFFFF",  # 7: Pure White Pearl / Eye Highlight
    "#38BDF8",  # 8: Arcade Cabinet Cyan Shell
    "#1D4ED8",  # 9: Arcade Deep Blue Side
    "#22D3EE",  # 10: Arcade Glowing Neon Screen
    "#F43F5E",  # 11: Arcade Joystick Ball Red
    "#FDE047",  # 12: Arcade Button Yellow / Unicorn Horn Gold
    "#FDF2F8",  # 13: Unicorn Pearlescent White-Pink
    "#F59E0B",  # 14: Golden Gacha Deep Gold
    "#FFE566",  # 15: Golden Gacha Bright Gold Highlight
    "#E0F2FE",  # 16: Golden Gacha Clear Dome Tint
    "#A855F7",  # 17: Rubber Band Vivid Purple-Coral
    "#FB7185",  # 18: Rubber Band Peg Coral
    "#FEF08A",  # 19: Figurine Cream Face
    "#F472B6",  # 20: Figurine Pink Hat/Accents
    "#FBBF24",  # 21: Figurine Pedestal Gold
]


def build_w2_palette(path, size=128):
    grid = 8
    cell = size // grid
    arr = np.ones((size, size, 4), dtype=np.float32)
    for idx, hx in enumerate(W2_PALETTE):
        r, g, b, a = hex_rgba(hx)
        row, col = idx // grid, idx % grid
        arr[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell] = (r, g, b, a)
    img = bpy.data.images.new("W2PaletteAtlas", width=size, height=size, alpha=True)
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def swatch_uv(idx, grid=8):
    return ((idx % grid + 0.5) / grid, (idx // grid + 0.5) / grid)


def build_playmat_texture(path, size=512):
    """W2-01 Butter-Yellow Soft Vinyl Playmat with playful subtle geometric grid & pastel dots."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    cx = (x * 4.0).astype(np.int32) % 2
    cy = (y * 4.0).astype(np.int32) % 2
    checker = ((cx + cy) % 2).astype(np.float32)

    butter_a = np.array([0.99, 0.91, 0.58], dtype=np.float32)  # Warm butter yellow
    butter_b = np.array([1.00, 0.96, 0.78], dtype=np.float32)  # Soft vanilla cream
    rgb = butter_a[None, None, :] * (1.0 - checker[:, :, None]) + butter_b[None, None, :] * checker[:, :, None]

    # Playful faint embossed dots at tile centers
    fx = ((x * 4.0) % 1.0) - 0.5
    fy = ((y * 4.0) % 1.0) - 0.5
    dot = (fx * fx + fy * fy) < (0.075 ** 2)
    rgb[dot] = np.clip(rgb[dot] - 0.045, 0.0, 1.0)

    # Crisp subtle mat grid seam
    gx = np.abs(fx) * 2.0
    gy = np.abs(fy) * 2.0
    seam = np.clip((np.maximum(gx, gy) - 0.955) / 0.045, 0.0, 1.0) * 0.06
    rgb = np.clip(rgb - seam[:, :, None], 0.0, 1.0)

    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    img = bpy.data.images.new("W2PlaymatTile", width=size, height=size, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def make_mat(name, img, roughness=0.20, metallic=0.04, emission_strength=0.0):
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
        bsdf.inputs["Coat Weight"].default_value = 0.65 if roughness < 0.3 else 0.15
        bsdf.inputs["Coat Roughness"].default_value = 0.10
    if emission_strength > 0.0 and "Emission Strength" in bsdf.inputs:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def add_part(bm, uv, sw_idx, fn):
    before = set(bm.faces)
    fn(bm)
    u, v = swatch_uv(sw_idx)
    for f in bm.faces:
        if f not in before:
            f.smooth = True
            for loop in f.loops:
                loop[uv].uv = (u, v)


def make_lathe(bm, profile_rz, segs=14, cap_top=False, offset=Vector((0, 0, 0))):
    rings = []
    for r, z in profile_rz:
        if r <= 1e-5:
            rings.append([bm.verts.new(Vector((0.0, 0.0, z)) + offset)])
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
    if cap_top and len(rings[-1]) > 1:
        bm.faces.new(rings[-1])


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
# Build all 8 World 2 Assets
# ---------------------------------------------------------------------------
def build_w2_01_tabletop(playmat_mat):
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
    return finalize("W2_01_Playmat", bm, playmat_mat)


def build_w2_02_block(pal_mat):
    """Chunky 2x2 interlocking stud toy brick (<= 160 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_part(bm, uv, 1, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.14)) @ Matrix.Diagonal((0.46, 0.46, 0.26, 1.0))))
    for sx in (-0.11, 0.11):
        for sy in (-0.11, 0.11):
            add_part(bm, uv, 1, lambda b, x=sx, y=sy: bmesh.ops.create_cone(
                b, cap_ends=True, cap_tris=False, segments=8, radius1=0.075, radius2=0.075, depth=0.08,
                matrix=Matrix.Translation((x, y, 0.30))))
    return finalize("W2_02_Block", bm, pal_mat)


def build_w2_03_duck(pal_mat):
    """Adorable chubby pink-blue gradient vinyl rubber duck (<= 460 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Plump duck body (pink)
    add_part(bm, uv, 4, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=1.0,
        matrix=Matrix.Translation((0, 0.04, 0.24)) @ Matrix.Diagonal((0.36, 0.44, 0.25, 1.0))))
    # Tail flick (sky blue)
    add_part(bm, uv, 1, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=6, radius1=0.14, radius2=0.03, depth=0.22,
        matrix=Matrix.Translation((0, 0.42, 0.34)) @ Matrix.Rotation(math.radians(-42), 4, "X")))
    # Cute side wings (sky blue)
    for side in (-1, 1):
        add_part(bm, uv, 1, lambda b, s=side: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=1.0,
            matrix=Matrix.Translation((s * 0.34, 0.05, 0.26)) @ Matrix.Diagonal((0.09, 0.22, 0.14, 1.0))))
    # Big round head (pink)
    add_part(bm, uv, 4, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=0.26, matrix=Matrix.Translation((0, -0.22, 0.56))))
    # Chubby orange duck beak
    add_part(bm, uv, 5, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((0, -0.46, 0.52)) @ Matrix.Diagonal((0.14, 0.13, 0.075, 1.0))))
    # Glossy dark eyes
    for side in (-1, 1):
        add_part(bm, uv, 6, lambda b, s=side: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.045, matrix=Matrix.Translation((s * 0.13, -0.41, 0.62))))
    return finalize("W2_03_Duck", bm, pal_mat)


def build_w2_04_figurine(pal_mat):
    """Chibi big-headed blind-box vinyl figurine on round gold pedestal (<= 620 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Round gold pedestal
    add_part(bm, uv, 21, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=14, radius1=0.38, radius2=0.35, depth=0.09,
        matrix=Matrix.Translation((0, 0, 0.045))))
    # Chunky lavender hoodie torso
    add_part(bm, uv, 3, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=12, radius1=0.25, radius2=0.18, depth=0.36,
        matrix=Matrix.Translation((0, 0, 0.27))))
    # Cute rounded arms
    for side in (-1, 1):
        add_part(bm, uv, 3, lambda b, s=side: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=1.0,
            matrix=Matrix.Translation((s * 0.24, -0.02, 0.32)) @ Matrix.Diagonal((0.08, 0.08, 0.13, 1.0))))
    # Oversized vinyl head (cream face)
    add_part(bm, uv, 19, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=0.30, matrix=Matrix.Translation((0, 0, 0.68))))
    # Pink bunny/cat blind-box hood cap + ears
    add_part(bm, uv, 20, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((0, 0.04, 0.78)) @ Matrix.Diagonal((0.31, 0.28, 0.22, 1.0))))
    for side in (-1, 1):
        add_part(bm, uv, 20, lambda b, s=side: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=1.0,
            matrix=Matrix.Translation((s * 0.16, 0.02, 1.02)) @ Matrix.Diagonal((0.08, 0.07, 0.16, 1.0))))
    # Cute eyes
    for side in (-1, 1):
        add_part(bm, uv, 6, lambda b, s=side: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.04, matrix=Matrix.Translation((s * 0.11, -0.27, 0.68))))
    return finalize("W2_04_Figurine", bm, pal_mat)


def build_w2_05_arcade(pal_mat):
    """Chunky retro mini tabletop arcade cabinet with glowing neon screen & joystick (<= 720 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Base cabinet body (sky cyan)
    add_part(bm, uv, 8, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0.08, 0.56)) @ Matrix.Diagonal((0.88, 0.74, 1.12, 1.0))))
    # Deep blue side trim panels
    for side in (-1, 1):
        add_part(bm, uv, 9, lambda b, s=side: bmesh.ops.create_cube(
            b, size=1.0, matrix=Matrix.Translation((s * 0.46, 0.08, 0.58)) @ Matrix.Diagonal((0.08, 0.78, 1.16, 1.0))))
    # Top glowing marquee header (hot pink)
    add_part(bm, uv, 0, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, -0.02, 1.10)) @ Matrix.Diagonal((0.86, 0.62, 0.20, 1.0))))
    # Glowing neon CRT screen tilted slightly up for top-down visibility!
    add_part(bm, uv, 10, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, -0.22, 0.76)) @ Matrix.Rotation(math.radians(24), 4, "X") @ Matrix.Diagonal((0.68, 0.10, 0.46, 1.0))))
    # Control deck shelf protruding forward
    add_part(bm, uv, 9, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, -0.44, 0.46)) @ Matrix.Diagonal((0.86, 0.42, 0.14, 1.0))))
    # Oversized candy joystick (red ball + stem)
    add_part(bm, uv, 7, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=6, radius1=0.025, radius2=0.025, depth=0.14,
        matrix=Matrix.Translation((-0.20, -0.46, 0.58))))
    add_part(bm, uv, 11, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=0.095, matrix=Matrix.Translation((-0.20, -0.46, 0.68))))
    # 3 chunky arcade buttons (yellow, pink, mint)
    for bx, by, sw in [(0.08, -0.42, 12), (0.22, -0.48, 0), (0.28, -0.36, 2)]:
        add_part(bm, uv, sw, lambda b, x=bx, y=by: bmesh.ops.create_cone(
            b, cap_ends=True, cap_tris=False, segments=8, radius1=0.065, radius2=0.06, depth=0.06,
            matrix=Matrix.Translation((x, y, 0.55))))
    return finalize("W2_05_Arcade", bm, pal_mat)


def build_w2_06_unicorn(pal_mat):
    """Cute plump pearlescent gacha unicorn toy figurine (<= 850 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Plump pearlescent white-pink body
    add_part(bm, uv, 13, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=1.0,
        matrix=Matrix.Translation((0, 0.08, 0.54)) @ Matrix.Diagonal((0.52, 0.68, 0.42, 1.0))))
    # 4 chubby legs
    for lx in (-0.28, 0.28):
        for ly in (-0.30, 0.36):
            add_part(bm, uv, 13, lambda b, x=lx, y=ly: bmesh.ops.create_cone(
                b, cap_ends=True, cap_tris=False, segments=8, radius1=0.13, radius2=0.15, depth=0.38,
                matrix=Matrix.Translation((x, y, 0.19))))
    # Big cute unicorn head
    add_part(bm, uv, 13, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=2, radius=1.0,
        matrix=Matrix.Translation((0, -0.52, 1.06)) @ Matrix.Diagonal((0.40, 0.48, 0.38, 1.0))))
    # Golden unicorn horn!
    add_part(bm, uv, 12, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=8, radius1=0.10, radius2=0.015, depth=0.42,
        matrix=Matrix.Translation((0, -0.66, 1.48)) @ Matrix.Rotation(math.radians(-22), 4, "X")))
    # Pastel rainbow mane puffs (pink, lavender, cyan)
    for idx, (mz, my, sw) in enumerate([(1.32, -0.28, 0), (1.10, -0.14, 3), (0.88, 0.02, 1)]):
        add_part(bm, uv, sw, lambda b, z=mz, y=my: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.22, matrix=Matrix.Translation((0, y, z))))
    # Fluffy pink tail
    add_part(bm, uv, 0, lambda b: bmesh.ops.create_icosphere(
        b, subdivisions=1, radius=1.0,
        matrix=Matrix.Translation((0, 0.80, 0.62)) @ Matrix.Diagonal((0.20, 0.26, 0.28, 1.0))))
    # Glossy eyes
    for side in (-1, 1):
        add_part(bm, uv, 6, lambda b, s=side: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.065, matrix=Matrix.Translation((s * 0.28, -0.78, 1.12))))
    return finalize("W2_06_Unicorn", bm, pal_mat)


def build_w2_07_golden_gacha(gold_mat):
    """Lv.5 Boss Target: Giant Shiny Brushed-Gold Gacha Capsule (<= 680 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs = 20
    # Lower metallic deep gold hemisphere
    add_part(bm, uv, 14, lambda b: make_lathe(b, [
        (0.0, 0.0), (0.48, 0.06), (0.85, 0.28), (1.06, 0.62), (1.12, 0.94), (1.15, 1.00)
    ], segs=segs))
    # Bright white-gold equatorial latch ring
    add_part(bm, uv, 7, lambda b: make_lathe(b, [
        (1.15, 0.98), (1.18, 1.06), (1.15, 1.14)
    ], segs=segs))
    # Upper gleaming champagne-gold dome
    add_part(bm, uv, 15, lambda b: make_lathe(b, [
        (1.12, 1.12), (1.04, 1.46), (0.82, 1.78), (0.46, 1.98), (0.0, 2.06)
    ], segs=segs))
    # Raised bright golden star emblem crowning the top for instant 60-deg top-down readability!
    add_part(bm, uv, 12, lambda b: bmesh.ops.create_cone(
        b, cap_ends=True, cap_tris=False, segments=5, radius1=0.46, radius2=0.14, depth=0.20,
        matrix=Matrix.Translation((0, 0, 2.04))))
    return finalize("W2_07_GoldenGacha", bm, gold_mat)


def build_w2_08_rubber_wall(pal_mat):
    """Elastic Rubber Band Barrier Wall pinned between 2 chunky rounded pastel pegs (<= 240 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Left & Right chunky rounded coral pegs (4.0m span)
    for sx in (-1.9, 1.9):
        add_part(bm, uv, 18, lambda b, x=sx: bmesh.ops.create_cone(
            b, cap_ends=True, cap_tris=False, segments=10, radius1=0.28, radius2=0.24, depth=0.76,
            matrix=Matrix.Translation((x, 0, 0.38))))
        add_part(bm, uv, 12, lambda b, x=sx: bmesh.ops.create_icosphere(
            b, subdivisions=1, radius=0.22, matrix=Matrix.Translation((x, 0, 0.76))))
    # Smooth wide stretched coral-purple elastic rubber band wall (clean low-poly!)
    add_part(bm, uv, 17, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.42)) @ Matrix.Diagonal((3.72, 0.14, 0.44, 1.0))))
    # Top bright pink-coral trim stripe for high contrast
    add_part(bm, uv, 0, lambda b: bmesh.ops.create_cube(
        b, size=1.0, matrix=Matrix.Translation((0, 0, 0.64)) @ Matrix.Diagonal((3.72, 0.16, 0.08, 1.0))))
    return finalize("W2_08_RubberWall", bm, pal_mat)


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
    pal_img = build_w2_palette(os.path.join(TEX_OUT, "w2_palette_atlas.png"), size=128)
    mat_img = build_playmat_texture(os.path.join(TEX_OUT, "w2_01_playmat_tile.png"), size=512)

    pal_mat = make_mat("M_W2VinylAtlas", pal_img, roughness=0.18, metallic=0.04)
    gold_mat = make_mat("M_W2GoldGacha", pal_img, roughness=0.15, metallic=0.82)
    playmat_mat = make_mat("M_W2Playmat", mat_img, roughness=0.30, metallic=0.02)

    specs = [
        ("W2-01", build_w2_01_tabletop(playmat_mat),   os.path.join(W2_OUT, "w2_01_tabletop.glb"),     120, 60),
        ("W2-02", build_w2_02_block(pal_mat),          os.path.join(W2_OUT, "w2_02_block.glb"),        160, 18),
        ("W2-03", build_w2_03_duck(pal_mat),           os.path.join(W2_OUT, "w2_03_duck.glb"),         460, 45),
        ("W2-04", build_w2_04_figurine(pal_mat),       os.path.join(W2_OUT, "w2_04_figurine.glb"),     620, 68),
        ("W2-05", build_w2_05_arcade(pal_mat),         os.path.join(W2_OUT, "w2_05_arcade.glb"),       720, 75),
        ("W2-06", build_w2_06_unicorn(pal_mat),        os.path.join(W2_OUT, "w2_06_unicorn.glb"),      850, 82),
        ("W2-07", build_w2_07_golden_gacha(gold_mat),  os.path.join(W2_OUT, "w2_07_golden_gacha.glb"), 680, 72),
        ("W2-08", build_w2_08_rubber_wall(pal_mat),    os.path.join(W2_OUT, "w2_08_rubber_wall.glb"),  240, 22),
    ]

    qa = []
    tot_tris = 0
    tot_kb = 0.0
    for aid, obj, path, max_t, max_kb in specs:
        t = count_tris(obj)
        m = len(obj.data.materials)
        kb = export_glb(obj, path)
        tot_tris += t
        tot_kb += kb
        qa.append({"id": aid, "name": obj.name, "tris": t, "max_tris": max_t, "tris_ok": t <= max_t,
                   "materials": m, "kb": round(kb, 1), "max_kb": max_kb, "kb_ok": kb <= max_kb})

    # Arrange studio showcase on Butter-Yellow Playmat
    table_obj = specs[0][1]
    table_obj.location = Vector((0, 0, -0.36))
    for i, s in enumerate(specs[1:]):
        col = i % 4
        row = i // 4
        s[1].location = Vector(((col - 1.5) * 3.4, (0.6 - row) * 3.6, 0.0))

    world = bpy.data.worlds.new("W2Studio")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (1.0, 0.97, 0.88, 1.0)
        bg.inputs["Strength"].default_value = 0.9

    sun_d = bpy.data.lights.new("Sun", type="SUN")
    sun_d.energy = 3.0
    sun = bpy.data.objects.new("Sun", sun_d)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = Euler((math.radians(46), math.radians(18), math.radians(30)))

    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = 40.0
    cam = bpy.data.objects.new("Cam", cam_d)
    bpy.context.collection.objects.link(cam)
    cam.location = Vector((0.0, -11.5, 9.2))
    cam.rotation_euler = (Vector((0.0, 0.0, 0.6)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.filepath = SHOWCASE_IMG
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

    print("W2_QA_JSON:" + json.dumps({
        "total_tris": tot_tris, "budget_tris": 3850,
        "total_kb": round(tot_kb, 1), "budget_kb": 442,
        "all_pass": all(r["tris_ok"] and r["kb_ok"] and r["materials"] == 1 for r in qa),
        "items": qa
    }, ensure_ascii=False))


run()
