#!/usr/bin/env python3
"""
Gobble Pop! — World 5 ("PIXEL ARCADE") Parametric 3D GLB Asset Builder
Generates 6 crisp, colorful, Option-2 glossy toy-grade gaming 3D GLB models in assets/models/world5/:
  1. w5_02_pixel_coin.glb   (Tier 1: Golden Game Coin Token with raised star emblem)
  2. w5_03_cartridge.glb    (Tier 1: Retro Coral/Cyan Game Cartridge with pixel label)
  3. w5_04_gamepad.glb      (Tier 2: Ergonomic Pro Gamepad with D-pad & candy A/B/X/Y buttons)
  4. w5_05_handheld.glb     (Tier 3: Dual-Tone Handheld Console with glowing pixel screen)
  5. w5_06_vr_headset.glb   (Tier 4: Futuristic Pearl & Neon-Cyan VR Gaming Headset)
  6. w5_07_arcade_boss.glb  (Tier 5: Giant Retro Arcade Boss Cabinet with joystick & glowing marquee)
Zero external dependencies (pure Python glTF 2.0 binary + PNG palette encoder).
"""
import json
import math
import os
import struct
import zlib

OUT_DIR = "/Users/unmercy/Documents/antig/hole/assets/models/world5"
os.makedirs(OUT_DIR, exist_ok=True)

# 8x8 Candy Gaming Palette Atlas (index 0..31)
PALETTE = [
    "#FFD53D",  # 0: Coin Bright Gold
    "#E59A18",  # 1: Coin Deep Gold Rim
    "#FFF5A8",  # 2: Coin Star Specular
    "#FF477E",  # 3: Cartridge / Joy-Con Hot Pink-Coral
    "#22D3EE",  # 4: Electric Cyan / Left Joy-Con
    "#3B82F6",  # 5: Arcade Bright Royal Blue
    "#7C3AED",  # 6: Arcade Cabinet Vibrant Purple
    "#4C1D95",  # 7: Deep Indigo Shadow / Cabinet Trim
    "#DDD6FE",  # 8: Glossy Retro SNES Lavender-Pearl Shell (high contrast on sky-blue arcade tile!)
    "#E2E8F0",  # 9: Soft Cool Grey Accent
    "#1E293B",  # 10: Dark Slate Screen Bezel / D-Pad
    "#0EA5E9",  # 11: Glowing Screen Sky Blue
    "#38BDF8",  # 12: Glowing Screen Highlight
    "#25CF65",  # 13: Candy Emerald Button (A)
    "#F43F5E",  # 14: Candy Ruby Button / Joystick Ball (B)
    "#FACC15",  # 15: Candy Sunny Button / Marquee (Y)
    "#A855F7",  # 16: Candy Violet Button (X)
    "#FF8A2B",  # 17: Arcade Orange Accent
    "#06B6D4",  # 18: VR Visor Deep Cyan
    "#EC4899",  # 19: VR Visor Magenta Glow
    "#10B981",  # 20: Screen Pixel Lime
    "#6366F1",  # 21: Strap Periwinkle
    "#334155",  # 22: Charcoal Grip
    "#FDE047",  # 23: Bright Marquee Yellow
]


def encode_palette_png():
    size = 128
    cell = 16
    buf = bytearray(size * size * 3)
    for idx, hx in enumerate(PALETTE):
        h = hx.lstrip("#")
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        row = idx // 8
        col = idx % 8
        for dy in range(cell):
            y = row * cell + dy
            for dx in range(cell):
                x = col * cell + dx
                off = (y * size + x) * 3
                buf[off] = r
                buf[off + 1] = g
                buf[off + 2] = b

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    stride = size * 3
    rows = [b"\x00" + bytes(buf[y * stride:(y + 1) * stride]) for y in range(size)]
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"".join(rows), 7)) + chunk(b"IEND", b"")


PALETTE_PNG = encode_palette_png()


def swatch_uv(idx):
    row = idx // 8
    col = idx % 8
    return ((col + 0.5) / 8.0, (row + 0.5) / 8.0)


def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def v_norm(v):
    l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if l < 1e-8:
        return (0.0, 1.0, 0.0)
    return (v[0] / l, v[1] / l, v[2] / l)


def rot_x(p, rad):
    c, s = math.cos(rad), math.sin(rad)
    return (p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c)


def rot_y(p, rad):
    c, s = math.cos(rad), math.sin(rad)
    return (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)


def rot_z(p, rad):
    c, s = math.cos(rad), math.sin(rad)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])


class MeshBuilder:
    def __init__(self):
        self.pos = []
        self.nrm = []
        self.uv = []
        self.idx = []

    def add_tri(self, p0, p1, p2, sw_idx, n0=None, n1=None, n2=None):
        base = len(self.pos)
        u, v = swatch_uv(sw_idx)
        if n0 is None:
            fn = v_norm(v_cross(v_sub(p1, p0), v_sub(p2, p0)))
            n0 = n1 = n2 = fn
        self.pos.extend([p0, p1, p2])
        self.nrm.extend([n0, n1, n2])
        self.uv.extend([(u, v), (u, v), (u, v)])
        self.idx.extend([base, base + 1, base + 2])

    def add_quad(self, p0, p1, p2, p3, sw_idx, smooth_n=None):
        if smooth_n:
            self.add_tri(p0, p1, p2, sw_idx, smooth_n[0], smooth_n[1], smooth_n[2])
            self.add_tri(p0, p2, p3, sw_idx, smooth_n[0], smooth_n[2], smooth_n[3])
        else:
            self.add_tri(p0, p1, p2, sw_idx)
            self.add_tri(p0, p2, p3, sw_idx)

    def add_box(self, center, size, sw_idx, rx=0.0, ry=0.0, rz=0.0):
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        corners = [
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
            (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz),
        ]
        pts = []
        for c in corners:
            p = rot_z(rot_y(rot_x(c, rx), ry), rz)
            pts.append((p[0] + center[0], p[1] + center[1], p[2] + center[2]))
        faces = [
            (0, 3, 2, 1),  # -Z
            (4, 5, 6, 7),  # +Z
            (0, 1, 5, 4),  # -Y
            (3, 7, 6, 2),  # +Y
            (0, 4, 7, 3),  # -X
            (1, 2, 6, 5),  # +X
        ]
        for a, b, c, d in faces:
            self.add_quad(pts[a], pts[b], pts[c], pts[d], sw_idx)

    def add_cyl(self, center, r_bot, r_top, height, sw_idx, segs=16, rx=0.0, ry=0.0, rz=0.0):
        hy = height * 0.5

        def xform(p):
            q = rot_z(rot_y(rot_x(p, rx), ry), rz)
            return (q[0] + center[0], q[1] + center[1], q[2] + center[2])

        def xform_n(n):
            return v_norm(rot_z(rot_y(rot_x(n, rx), ry), rz))

        bot_ring = []
        top_ring = []
        side_n = []
        for i in range(segs):
            a = math.tau * i / segs
            ca, sa = math.cos(a), math.sin(a)
            bot_ring.append(xform((ca * r_bot, -hy, sa * r_bot)))
            top_ring.append(xform((ca * r_top, hy, sa * r_top)))
            side_n.append(xform_n((ca, 0.0, sa)))

        c_bot = xform((0.0, -hy, 0.0))
        c_top = xform((0.0, hy, 0.0))
        n_bot = xform_n((0.0, -1.0, 0.0))
        n_top = xform_n((0.0, 1.0, 0.0))

        for i in range(segs):
            j = (i + 1) % segs
            self.add_quad(bot_ring[i], top_ring[i], top_ring[j], bot_ring[j], sw_idx,
                          (side_n[i], side_n[i], side_n[j], side_n[j]))
            self.add_tri(c_top, top_ring[j], top_ring[i], sw_idx, n_top, n_top, n_top)
            self.add_tri(c_bot, bot_ring[i], bot_ring[j], sw_idx, n_bot, n_bot, n_bot)

    def add_sphere(self, center, radii, sw_idx, rings=8, segs=14):
        rx, ry, rz = radii
        grid = []
        for r in range(rings + 1):
            phi = math.pi * r / rings
            sp, cp = math.sin(phi), math.cos(phi)
            row = []
            for s in range(segs):
                th = math.tau * s / segs
                ct, st = math.cos(th), math.sin(th)
                p = (center[0] + rx * sp * ct, center[1] + ry * cp, center[2] + rz * sp * st)
                n = v_norm((sp * ct / max(rx, 1e-4), cp / max(ry, 1e-4), sp * st / max(rz, 1e-4)))
                row.append((p, n))
            grid.append(row)
        for r in range(rings):
            for s in range(segs):
                s1 = (s + 1) % segs
                p00, n00 = grid[r][s]
                p01, n01 = grid[r][s1]
                p10, n10 = grid[r + 1][s]
                p11, n11 = grid[r + 1][s1]
                if r > 0:
                    self.add_tri(p00, p01, p11, sw_idx, n00, n01, n11)
                if r < rings - 1:
                    self.add_tri(p00, p11, p10, sw_idx, n00, n11, n10)

    def normalize_bottom_center(self):
        xs = [p[0] for p in self.pos]
        ys = [p[1] for p in self.pos]
        zs = [p[2] for p in self.pos]
        cx = 0.5 * (min(xs) + max(xs))
        cz = 0.5 * (min(zs) + max(zs))
        miny = min(ys)
        self.pos = [(p[0] - cx, p[1] - miny, p[2] - cz) for p in self.pos]

    def export_glb(self, path, name, roughness=0.22, metallic=0.10):
        self.normalize_bottom_center()
        nverts = len(self.pos)
        nidx = len(self.idx)

        pos_bytes = bytearray()
        nrm_bytes = bytearray()
        uv_bytes = bytearray()
        min_p = [1e9, 1e9, 1e9]
        max_p = [-1e9, -1e9, -1e9]
        for p, n, u in zip(self.pos, self.nrm, self.uv):
            pos_bytes += struct.pack("<fff", *p)
            nrm_bytes += struct.pack("<fff", *n)
            uv_bytes += struct.pack("<ff", *u)
            for k in range(3):
                if p[k] < min_p[k]: min_p[k] = p[k]
                if p[k] > max_p[k]: max_p[k] = p[k]

        idx_bytes = bytearray()
        for i in self.idx:
            idx_bytes += struct.pack("<H", i)
        while len(idx_bytes) % 4 != 0:
            idx_bytes += b"\x00"

        bin_data = bytearray()
        def add_bv(data, target=None):
            while len(bin_data) % 4 != 0:
                bin_data.append(0)
            off = len(bin_data)
            bin_data.extend(data)
            bv = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
            if target is not None:
                bv["target"] = target
            return bv

        bvs = [
            add_bv(pos_bytes, 34962),
            add_bv(nrm_bytes, 34962),
            add_bv(uv_bytes, 34962),
            add_bv(idx_bytes, 34963),
            add_bv(PALETTE_PNG, None),
        ]
        while len(bin_data) % 4 != 0:
            bin_data.append(0)

        gltf = {
            "asset": {"version": "2.0", "generator": "GobblePop-W5-Builder"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"mesh": 0, "name": name}],
            "meshes": [{
                "name": name,
                "primitives": [{
                    "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                    "indices": 3,
                    "material": 0,
                }],
            }],
            "materials": [{
                "name": "M_" + name,
                "doubleSided": True,
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "metallicFactor": metallic,
                    "roughnessFactor": roughness,
                },
            }],
            "textures": [{"sampler": 0, "source": 0}],
            "samplers": [{"magFilter": 9728, "minFilter": 9728}],
            "images": [{"bufferView": 4, "mimeType": "image/png", "name": "w5_palette_atlas"}],
            "accessors": [
                {"bufferView": 0, "componentType": 5126, "count": nverts, "type": "VEC3", "min": min_p, "max": max_p},
                {"bufferView": 1, "componentType": 5126, "count": nverts, "type": "VEC3"},
                {"bufferView": 2, "componentType": 5126, "count": nverts, "type": "VEC2"},
                {"bufferView": 3, "componentType": 5123, "count": nidx, "type": "SCALAR"},
            ],
            "bufferViews": bvs,
            "buffers": [{"byteLength": len(bin_data)}],
        }

        jbytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(jbytes) % 4 != 0:
            jbytes += b" "
        total_len = 12 + 8 + len(jbytes) + 8 + len(bin_data)
        out = bytearray()
        out += struct.pack("<4sII", b"glTF", 2, total_len)
        out += struct.pack("<II", len(jbytes), 0x4E4F534A)
        out += jbytes
        out += struct.pack("<II", len(bin_data), 0x004E4942)
        out += bin_data
        with open(path, "wb") as f:
            f.write(out)
        print(f"Built {os.path.basename(path):24s} -> {nidx // 3:4d} tris  ({len(out) / 1024.0:5.1f} KB)")


def build_w5_02_pixel_coin():
    mb = MeshBuilder()
    # Chunky upright tilted golden coin with beveled rim & embossed bright star center
    mb.add_cyl((0, 0.30, 0), 0.28, 0.28, 0.10, 1, segs=18, rx=math.radians(72))
    mb.add_cyl((0, 0.30, 0), 0.22, 0.22, 0.12, 0, segs=16, rx=math.radians(72))
    mb.add_box((0, 0.31, 0), (0.09, 0.20, 0.15), 2, rx=math.radians(-18))
    mb.add_box((0, 0.31, 0), (0.20, 0.09, 0.15), 2, rx=math.radians(-18))
    mb.export_glb(os.path.join(OUT_DIR, "w5_02_pixel_coin.glb"), "W5_02_PixelCoin", roughness=0.16, metallic=0.35)


def build_w5_03_cartridge():
    mb = MeshBuilder()
    # Cute chunky Retro Game Cartridge (coral-red body, grip ridges, vibrant cyan-gold art sticker, gold connector pins)
    mb.add_box((0, 0.28, 0), (0.56, 0.48, 0.18), 3)
    # Top lip & left/right shoulder notch
    mb.add_box((0, 0.54, 0), (0.52, 0.08, 0.16), 3)
    mb.add_box((0, 0.52, 0.08), (0.42, 0.04, 0.04), 14)
    # Vibrant game art label sticker on front & top face
    mb.add_box((0, 0.28, 0.095), (0.42, 0.30, 0.025), 4)
    mb.add_box((0, 0.33, 0.105), (0.34, 0.12, 0.02), 15)
    mb.add_box((0, 0.21, 0.105), (0.28, 0.08, 0.02), 6)
    # Bottom golden pins
    mb.add_box((0, 0.03, 0), (0.42, 0.06, 0.10), 0)
    mb.export_glb(os.path.join(OUT_DIR, "w5_03_cartridge.glb"), "W5_03_Cartridge", roughness=0.20, metallic=0.08)


def build_w5_04_gamepad():
    mb = MeshBuilder()
    # Iconic chunky Gamepad lying slightly tilted toward top-down camera so D-pad & rainbow buttons shine!
    # Main central bridge + twin rounded side grips
    mb.add_box((0, 0.18, 0), (0.86, 0.20, 0.50), 8)
    mb.add_cyl((-0.44, 0.18, 0.06), 0.27, 0.25, 0.22, 8, segs=16)
    mb.add_cyl((0.44, 0.18, 0.06), 0.27, 0.25, 0.22, 8, segs=16)
    # Shoulder bumpers (L/R electric cyan & hot pink)
    mb.add_box((-0.34, 0.20, -0.25), (0.26, 0.14, 0.09), 4)
    mb.add_box((0.34, 0.20, -0.25), (0.26, 0.14, 0.09), 3)
    # Crisp D-pad on left
    mb.add_box((-0.42, 0.31, 0.02), (0.24, 0.06, 0.08), 10)
    mb.add_box((-0.42, 0.31, 0.02), (0.08, 0.06, 0.24), 10)
    # 4 Colorful Candy A/B/X/Y Buttons on right!
    mb.add_cyl((0.42, 0.31, -0.09), 0.065, 0.06, 0.06, 16, segs=12)  # X purple
    mb.add_cyl((0.42, 0.31, 0.11), 0.065, 0.06, 0.06, 13, segs=12)   # A green
    mb.add_cyl((0.32, 0.31, 0.01), 0.065, 0.06, 0.06, 15, segs=12)   # Y yellow
    mb.add_cyl((0.52, 0.31, 0.01), 0.065, 0.06, 0.06, 14, segs=12)   # B red
    # Center glowing cyan Start/Select bar
    mb.add_box((-0.07, 0.30, 0.04), (0.09, 0.04, 0.04), 5)
    mb.add_box((0.07, 0.30, 0.04), (0.09, 0.04, 0.04), 5)
    mb.export_glb(os.path.join(OUT_DIR, "w5_04_gamepad.glb"), "W5_04_Gamepad", roughness=0.18, metallic=0.06)


def build_w5_05_handheld():
    mb = MeshBuilder()
    # Chunky Switch-style Handheld Game Console (Electric Cyan Left Grip + Glowing Pixel Screen + Hot Pink Right Grip)
    # Center slate screen body
    mb.add_box((0, 0.22, 0), (0.98, 0.22, 0.68), 10)
    # Luminous pixel sky-blue screen + cute pixel blocks inside screen
    mb.add_box((0, 0.34, 0), (0.84, 0.03, 0.54), 11)
    mb.add_box((-0.18, 0.36, -0.06), (0.16, 0.02, 0.16), 15)  # Pixel star/coin on screen
    mb.add_box((0.18, 0.36, 0.08), (0.22, 0.02, 0.14), 20)    # Pixel green platform
    mb.add_box((0.02, 0.36, -0.10), (0.14, 0.02, 0.14), 3)    # Pixel character
    # Left Electric-Cyan Joy-Con Grip + thumbstick
    mb.add_box((-0.66, 0.22, 0), (0.34, 0.24, 0.68), 4)
    mb.add_cyl((-0.66, 0.37, -0.12), 0.09, 0.085, 0.08, 10, segs=12)
    mb.add_box((-0.66, 0.36, 0.14), (0.14, 0.04, 0.05), 8)
    mb.add_box((-0.66, 0.36, 0.14), (0.05, 0.04, 0.14), 8)
    # Right Hot-Pink Joy-Con Grip + thumbstick + buttons
    mb.add_box((0.66, 0.22, 0), (0.34, 0.24, 0.68), 3)
    mb.add_cyl((0.66, 0.37, 0.12), 0.09, 0.085, 0.08, 10, segs=12)
    mb.add_cyl((0.66, 0.36, -0.18), 0.045, 0.045, 0.05, 15, segs=10)
    mb.add_cyl((0.66, 0.36, -0.06), 0.045, 0.045, 0.05, 13, segs=10)
    mb.add_cyl((0.59, 0.36, -0.12), 0.045, 0.045, 0.05, 16, segs=10)
    mb.add_cyl((0.73, 0.36, -0.12), 0.045, 0.045, 0.05, 4, segs=10)
    mb.export_glb(os.path.join(OUT_DIR, "w5_05_handheld.glb"), "W5_05_Handheld", roughness=0.16, metallic=0.08)


def build_w5_06_vr_headset():
    mb = MeshBuilder()
    # Futuristic Pearl-White & Neon-Cyan/Magenta VR Gaming Headset!
    # Main sleek visor housing
    mb.add_box((0, 0.44, 0.32), (1.32, 0.68, 0.62), 8)
    # Curved glowing cyan-magenta visor glass front
    mb.add_box((0, 0.44, 0.64), (1.18, 0.52, 0.10), 18)
    mb.add_box((-0.26, 0.46, 0.69), (0.48, 0.34, 0.05), 12)
    mb.add_box((0.28, 0.42, 0.69), (0.44, 0.30, 0.05), 19)
    # Glowing LED rim accents on sides & top
    mb.add_box((0, 0.79, 0.32), (1.10, 0.06, 0.14), 4)
    mb.add_cyl((-0.68, 0.44, 0.24), 0.16, 0.16, 0.12, 6, segs=14, rz=math.radians(90))
    mb.add_cyl((0.68, 0.44, 0.24), 0.16, 0.16, 0.12, 6, segs=14, rz=math.radians(90))
    # Rear cushioned headstrap ring (sky-periwinkle + hot pink rear pad)
    mb.add_box((-0.62, 0.44, -0.26), (0.14, 0.22, 0.96), 21)
    mb.add_box((0.62, 0.44, -0.26), (0.14, 0.22, 0.96), 21)
    mb.add_box((0, 0.44, -0.72), (1.28, 0.34, 0.18), 3)
    # Top strap arch
    mb.add_box((0, 0.86, -0.20), (0.24, 0.12, 0.98), 21)
    mb.export_glb(os.path.join(OUT_DIR, "w5_06_vr_headset.glb"), "W5_06_VRHeadset", roughness=0.15, metallic=0.14)


def build_w5_07_arcade_boss():
    mb = MeshBuilder()
    # Giant Retro Arcade Boss Cabinet (Royal Purple + Golden Trim + Glowing Cyan Screen + Joystick Deck + Marquee!)
    # Lower sturdy pedestal base
    mb.add_box((0, 0.55, 0.0), (1.52, 1.10, 1.24), 6)
    # Twin golden coin slots on lower front
    mb.add_box((0, 0.52, 0.63), (0.58, 0.46, 0.06), 7)
    mb.add_box((-0.14, 0.56, 0.67), (0.14, 0.20, 0.04), 17)
    mb.add_box((0.14, 0.56, 0.67), (0.14, 0.20, 0.04), 17)

    # Jutting Control Deck (bright sky-blue deck with red ball joystick & colorful buttons!)
    mb.add_box((0, 1.16, 0.36), (1.58, 0.20, 0.84), 5)
    # Red ball-top Joystick
    mb.add_cyl((-0.38, 1.36, 0.52), 0.04, 0.04, 0.24, 9, segs=10)
    mb.add_sphere((-0.38, 1.50, 0.52), (0.12, 0.12, 0.12), 14, rings=6, segs=12)
    # 6 Vibrant Rainbow Arcade Buttons on right deck
    btn_specs = [
        (0.10, 0.44, 15), (0.30, 0.44, 13), (0.50, 0.44, 4),
        (0.10, 0.62, 3),  (0.30, 0.62, 16), (0.50, 0.62, 17),
    ]
    for bx, bz, sw in btn_specs:
        mb.add_cyl((bx, 1.29, bz), 0.075, 0.07, 0.07, sw, segs=10)

    # Upper CRT Monitor Housing (slanted glowing cyan-magenta screen!)
    mb.add_box((0, 1.72, -0.14), (1.52, 0.98, 0.96), 6)
    # Golden side T-molding stripes
    mb.add_box((-0.78, 1.12, 0.0), (0.08, 2.24, 1.18), 0)
    mb.add_box((0.78, 1.12, 0.0), (0.08, 2.24, 1.18), 0)
    # Screen recess & vibrant glowing arcade screen
    mb.add_box((0, 1.72, 0.35), (1.24, 0.78, 0.06), 10)
    mb.add_box((0, 1.72, 0.39), (1.10, 0.66, 0.04), 11)
    # Cute pixel boss sprite glowing on screen
    mb.add_box((0, 1.78, 0.42), (0.36, 0.22, 0.03), 19)
    mb.add_box((-0.26, 1.58, 0.42), (0.24, 0.10, 0.03), 20)
    mb.add_box((0.26, 1.58, 0.42), (0.24, 0.10, 0.03), 15)

    # Top Glowing Golden Marquee Crown Banner!
    mb.add_box((0, 2.34, 0.04), (1.56, 0.34, 0.94), 7)
    mb.add_box((0, 2.34, 0.52), (1.38, 0.24, 0.06), 23)
    mb.add_box((0, 2.34, 0.56), (0.96, 0.12, 0.03), 3)
    # Crown star ornament right on top of marquee so it pops even from top-down!
    mb.add_box((0, 2.58, 0.06), (0.64, 0.16, 0.26), 0)
    mb.add_box((0, 2.60, 0.06), (0.26, 0.16, 0.64), 4)

    mb.export_glb(os.path.join(OUT_DIR, "w5_07_arcade_boss.glb"), "W5_07_ArcadeBoss", roughness=0.18, metallic=0.12)


if __name__ == "__main__":
    build_w5_02_pixel_coin()
    build_w5_03_cartridge()
    build_w5_04_gamepad()
    build_w5_05_handheld()
    build_w5_06_vr_headset()
    build_w5_07_arcade_boss()
    print(f"DONE! Built all 6 World 5 Pixel Arcade 3D GLB assets into {OUT_DIR}")
