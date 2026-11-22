#!/usr/bin/env python3
"""
Upgrade World 1 whipped cream & frosting on w1_06_boba_tea.glb, w1_08_cake.glb, and w1_05_macaron.glb
so there are NO pure-white cream tops blending into the light mint-cream marble tabletop!
- w1_06_boba_tea.glb: Remaps cream dome UVs to planar polar swirl + paints rich multi-color
  strawberry/mango/sky-candy swirled cream with chocolate drizzle & rainbow sprinkles (512x512 WebP).
- w1_08_cake.glb: Alternates the 14 whipped-cream rosettes across vibrant candy frosting colors
  and warms the sponge tiers to golden-peach buttercream.
- w1_05_macaron.glb: Deepens macaron shell to vibrant candy rose + golden vanilla filling.
"""
import json
import math
import os
import struct
import subprocess
import tempfile
import zlib

W1_DIR = "/Users/unmercy/Documents/antig/hole/assets/models/world1"


def encode_png_from_rgb(w, h, rgb_bytes):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    stride = w * 3
    rows = [b"\x00" + rgb_bytes[y * stride:(y + 1) * stride] for y in range(h)]
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"".join(rows), 7)) + chunk(b"IEND", b"")


def unpack_glb(path):
    data = open(path, "rb").read()
    jlen, _ = struct.unpack_from("<II", data, 12)
    gltf = json.loads(data[20:20 + jlen].decode("utf-8"))
    blen, _ = struct.unpack_from("<II", data, 20 + jlen)
    bin_data = bytearray(data[20 + jlen + 8:20 + jlen + 8 + blen])
    return gltf, bin_data


def pack_glb(path, gltf, bin_data):
    # Pad BIN to 4-byte boundary with 0x00
    while len(bin_data) % 4 != 0:
        bin_data.append(0)
    gltf["buffers"][0]["byteLength"] = len(bin_data)
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


def replace_image_buffer(gltf, bin_data, img_bv_idx, new_webp_bytes):
    bv = gltf["bufferViews"][img_bv_idx]
    old_off = bv.get("byteOffset", 0)
    old_len = bv["byteLength"]
    # Confirm image bufferView is at the end (or relocate safely to end of bin_data)
    if old_off + old_len >= len(bin_data) - 4:
        del bin_data[old_off:]
    while len(bin_data) % 4 != 0:
        bin_data.append(0)
    new_off = len(bin_data)
    bin_data.extend(new_webp_bytes)
    bv["byteOffset"] = new_off
    bv["byteLength"] = len(new_webp_bytes)


def lerp3(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def build_colorful_boba_texture(size=512):
    """
    512x512 RGB texture for w1_06_boba_tea (glTF top-down image coords: v=0 top, v=1 bottom):
    - v in [0.00, 0.06]: Bright glossy strawberry-pink striped straw
    - v in [0.06, 0.24]: Planar top-down colorful swirled whipped cream / sundae frosting!
      (Strawberry pink + sunny mango gold + cotton-candy sky + lavender 6-lobe soft-serve swirl
       with rich chocolate drizzle & rainbow candy sprinkles)
    - v in [0.24, 1.00]: Rich caramel milk tea cup + glossy dark espresso tapioca pearls
    """
    buf = bytearray(size * size * 3)

    # Pre-place crisp colorful sprinkles in normalized polar dome space (dx, dz in [-0.88, 0.88])
    sprinkles = [
        (0.42, 0.24, 0.5, (255, 58, 128)),
        (-0.38, 0.30, 1.8, (255, 224, 52)),
        (0.18, -0.48, 2.3, (46, 206, 255)),
        (-0.52, -0.22, 0.9, (68, 228, 120)),
        (0.62, -0.15, 2.6, (255, 118, 42)),
        (-0.15, 0.58, 0.3, (186, 98, 255)),
        (0.45, -0.45, 1.2, (255, 236, 74)),
        (-0.46, 0.52, 2.1, (255, 72, 148)),
        (0.08, 0.36, 1.5, (52, 212, 255)),
        (-0.24, -0.46, 0.7, (255, 92, 132)),
        (0.66, 0.26, 2.9, (74, 232, 134)),
        (-0.68, 0.08, 1.4, (255, 214, 58)),
    ]

    for py in range(size):
        v = (py + 0.5) / size  # glTF UV.y (0 = top, 1 = bottom)
        for px in range(size):
            u = (px + 0.5) / size

            if v < 0.062:
                # Cute candy-striped strawberry straw
                stripe = math.sin((u * 14.0 + v * 36.0) * math.tau)
                col = (255, 92, 158) if stripe > -0.15 else (255, 222, 236)
            elif v < 0.245:
                # Planar top-down colorful marbled soft-serve cream!
                dx = (u - 0.5) / 0.44
                dz = (v - 0.152) / 0.086
                r = math.hypot(dx, dz)
                ang = math.atan2(dz, dx)

                # Smooth 3-flavor candy swirl (Strawberry Rose, Mango Gold, Berry-Sky Pastel)
                swirl_phase = ang * 3.0 - r * 5.2
                s1 = 0.5 + 0.5 * math.sin(swirl_phase)
                s2 = 0.5 + 0.5 * math.sin(swirl_phase + 2.094)
                s3 = 0.5 + 0.5 * math.sin(swirl_phase + 4.188)
                # Sharpen swirl ribbons slightly for delicious distinct colorful bands
                w1 = s1 ** 1.35
                w2 = s2 ** 1.35
                w3 = s3 ** 1.35
                wsum = w1 + w2 + w3 + 1e-5
                c_pink = (255.0, 108.0, 174.0)   # Strawberry frosting
                c_mango = (255.0, 206.0, 82.0)   # Sunny mango buttercream
                c_sky = (118.0, 206.0, 255.0)    # Cotton-candy blue-lavender swirl
                cr = (c_pink[0] * w1 + c_mango[0] * w2 + c_sky[0] * w3) / wsum
                cg = (c_pink[1] * w1 + c_mango[1] * w2 + c_sky[1] * w3) / wsum
                cb = (c_pink[2] * w1 + c_mango[2] * w2 + c_sky[2] * w3) / wsum

                # Subtle piped-cream spiral ridge shading for 3D scoop depth
                ridge = 0.88 + 0.14 * math.cos(ang * 6.0 - r * 7.5)
                # Soft warm caramel rim collar around outer edge (r > 0.84) for crisp silhouette!
                rim_t = max(0.0, min(1.0, (r - 0.82) / 0.16))
                cr = cr * ridge * (1.0 - rim_t) + 216.0 * rim_t
                cg = cg * ridge * (1.0 - rim_t) + 124.0 * rim_t
                cb = cb * ridge * (1.0 - rim_t) + 64.0 * rim_t

                # Thin glossy chocolate/berry syrup spiral drizzle line
                drizzle = abs(math.sin(ang * 2.0 - r * 8.5))
                if 0.16 < r < 0.86 and drizzle < 0.085:
                    dt = 1.0 - drizzle / 0.085
                    cr = cr * (1.0 - dt * 0.78) + 112.0 * (dt * 0.78)
                    cg = cg * (1.0 - dt * 0.78) + 46.0 * (dt * 0.78)
                    cb = cb * (1.0 - dt * 0.78) + 34.0 * (dt * 0.78)

                # Glossy rainbow candy sprinkles on the swirled cream
                for sx, sz, sang, scol in sprinkles:
                    lx = dx - sx
                    lz = dz - sz
                    ca, sa = math.cos(sang), math.sin(sang)
                    rx = lx * ca + lz * sa
                    rz = -lx * sa + lz * ca
                    if abs(rx) < 0.085 and abs(rz) < 0.032:
                        cr, cg, cb = scol[0], scol[1], scol[2]
                        break

                col = (int(max(0, min(255, cr))), int(max(0, min(255, cg))), int(max(0, min(255, cb))))
            else:
                # Caramel milk tea cup body (v in 0.245 .. 1.0)
                t = (v - 0.245) / 0.755  # 0 at cup top, 1 at cup bottom
                top_c = (242.0, 198.0, 142.0)
                bot_c = (186.0, 112.0, 56.0)
                c = lerp3(top_c, bot_c, t)
                # Subtle brown-sugar tiger stripes on cup
                tiger = 0.5 + 0.5 * math.sin(u * math.tau * 5.0 + t * 9.0)
                if t > 0.35 and tiger > 0.80:
                    c = lerp3(c, (124.0, 62.0, 28.0), 0.38)
                # Two rows of glossy espresso tapioca pearls near bottom (t in 0.68..0.95)
                for row_i, pt in enumerate((0.76, 0.88)):
                    cols = 10
                    off = 0.05 if row_i == 1 else 0.0
                    for ci in range(cols):
                        pu = (ci / cols + off) % 1.0
                        du = min(abs(u - pu), 1.0 - abs(u - pu))
                        dv = t - pt
                        d = math.hypot(du * 1.0, dv * 0.85)
                        if d < 0.038:
                            c = (38.0, 20.0, 14.0)
                            if math.hypot((du - 0.01) * 1.0, (dv + 0.012) * 0.85) < 0.011:
                                c = (118.0, 82.0, 62.0)
                col = (int(c[0]), int(c[1]), int(c[2]))

            idx = (py * size + px) * 3
            buf[idx] = col[0]
            buf[idx + 1] = col[1]
            buf[idx + 2] = col[2]

    return encode_png_from_rgb(size, size, bytes(buf))


def upgrade_boba_glb():
    glb_path = os.path.join(W1_DIR, "w1_06_boba_tea.glb")
    gltf, bin_data = unpack_glb(glb_path)

    # Read POSITION and TEXCOORD_0
    bvs = gltf["bufferViews"]
    accs = gltf["accessors"]
    pos_bv = bvs[accs[0]["bufferView"]]
    uv_bv = bvs[accs[2]["bufferView"]]
    pos_off = pos_bv.get("byteOffset", 0) + accs[0].get("byteOffset", 0)
    uv_off = uv_bv.get("byteOffset", 0) + accs[2].get("byteOffset", 0)
    count = accs[0]["count"]

    remapped = 0
    for i in range(count):
        x, y, z = struct.unpack_from("<fff", bin_data, pos_off + i * 12)
        u, v = struct.unpack_from("<ff", bin_data, uv_off + i * 8)
        # Dome lid vertices had v ~ 0.14 (y in 0.69..0.96, excluding straw which has v ~ 0.04)
        if 0.08 < v < 0.22:
            new_u = max(0.06, min(0.94, 0.5 + (x / 0.48) * 0.44))
            new_v = max(0.068, min(0.238, 0.152 + (z / 0.48) * 0.086))
            struct.pack_into("<ff", bin_data, uv_off + i * 8, new_u, new_v)
            remapped += 1

    png_bytes = build_colorful_boba_texture(512)
    gltf["images"][0]["mimeType"] = "image/png"
    replace_image_buffer(gltf, bin_data, gltf["images"][0]["bufferView"], png_bytes)
    pack_glb(glb_path, gltf, bin_data)
    print(f"Upgraded w1_06_boba_tea.glb: remapped {remapped} cream-dome verts + wrote {len(png_bytes)/1024:.1f} KB swirled candy cream PNG")


def build_enriched_w1_palette_webp(cake_mode=False, macaron_mode=False):
    """Build 128x128 8x8 palette atlas WebP (glTF top-down Y: row 0 = bottom in Blender -> y=7 in glTF!)."""
    PALETTE = [
        "#35B6FF", "#F7C948", "#0B2569", "#0AE0FF", "#FFE829", "#57D9FF", "#B8F3FF", "#FF3B5C",
        "#3BA7FF", "#EBF4FF", "#FF47C2", "#52FF86", "#FFD633", "#7B4DFF", "#FFFFFF", "#2B1B17",
        "#FF4D94", "#FFD93D", "#4CC9F0", "#FF2846", "#FFE259", "#2FD663", "#FF3860", "#52DF68",
        "#FFCE2B", "#FF9EC4", "#C7A6FF", "#89E8C6", "#FFF8EE", "#E5A467", "#F5CFA0", "#FF69A8",
        "#4FC3F7", "#FF23A6", "#FF8CE0", "#FFF2F6", "#F9B8D0", "#B9EDDD", "#FCF9F2", "#8BD8C4",
    ]
    if cake_mode:
        # Warm golden-mango buttercream for rosettes (28) & rich peach-strawberry sponge (35)
        PALETTE[28] = "#FFD659"
        PALETTE[35] = "#FFCBA4"
        PALETTE[31] = "#FF4E98"
    if macaron_mode:
        # Richer berry-pink shell (25) & sunny buttercream filling (28) so macarons pop crisply!
        PALETTE[25] = "#FF70AE"
        PALETTE[28] = "#FFE27A"

    size = 128
    cell = 16
    buf = bytearray(size * size * 3)
    for i in range(size * size):
        buf[i * 3:i * 3 + 3] = b"\xff\xff\xff"

    for idx, hx in enumerate(PALETTE):
        h = hx.lstrip("#")
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        b_row = idx // 8
        col = idx % 8
        # Blender row 0 is at the BOTTOM of the image -> glTF top-down row = 7 - b_row
        g_row = 7 - b_row
        for dy in range(cell):
            y = g_row * cell + dy
            for dx in range(cell):
                x = col * cell + dx
                off = (y * size + x) * 3
                buf[off] = r
                buf[off + 1] = g
                buf[off + 2] = b
    return encode_png_from_rgb(size, size, bytes(buf))


def upgrade_cake_and_macaron():
    # 1. Cake: alternate the 14 whipped cream rosettes across vibrant candy frosting swatches + warm peach sponge
    cake_glb = os.path.join(W1_DIR, "w1_08_cake.glb")
    gltf, bin_data = unpack_glb(cake_glb)
    bvs = gltf["bufferViews"]
    accs = gltf["accessors"]
    pos_off = bvs[accs[0]["bufferView"]].get("byteOffset", 0) + accs[0].get("byteOffset", 0)
    uv_off = bvs[accs[2]["bufferView"]].get("byteOffset", 0) + accs[2].get("byteOffset", 0)
    count = accs[0]["count"]

    # Swatch 28 in Blender (row=3, col=4) -> glTF UV = ((4.5)/8, 1.0 - (3.5)/8) = (0.5625, 0.5625)
    # Paint rosettes by angle into alternating rainbow candy frosting swatches: 16(hot pink), 17(mango), 18(sky), 26(lavender), 21(mint)
    rosette_swatches = [17, 18, 26, 21, 16, 17, 18, 26]
    rosette_verts = 0
    for i in range(count):
        x, y, z = struct.unpack_from("<fff", bin_data, pos_off + i * 12)
        u, v = struct.unpack_from("<ff", bin_data, uv_off + i * 8)
        if abs(u - 0.5625) < 0.03 and abs(v - 0.5625) < 0.03:
            ang = (math.atan2(z, x) + math.pi) / math.tau
            sw = rosette_swatches[int(ang * 8.0) % len(rosette_swatches)]
            nu = (sw % 8 + 0.5) / 8.0
            nv = 1.0 - (sw // 8 + 0.5) / 8.0
            struct.pack_into("<ff", bin_data, uv_off + i * 8, nu, nv)
            rosette_verts += 1

    cake_png = build_enriched_w1_palette_webp(cake_mode=True)
    gltf["images"][0]["mimeType"] = "image/png"
    replace_image_buffer(gltf, bin_data, gltf["images"][0]["bufferView"], cake_png)
    pack_glb(cake_glb, gltf, bin_data)
    print(f"Upgraded w1_08_cake.glb: painted {rosette_verts} cream-rosette verts with alternating rainbow candy frosting")

    # 2. Macaron: richer berry-rose shell + golden buttercream filling
    mac_glb = os.path.join(W1_DIR, "w1_05_macaron.glb")
    m_gltf, m_bin = unpack_glb(mac_glb)
    mac_png = build_enriched_w1_palette_webp(macaron_mode=True)
    m_gltf["images"][0]["mimeType"] = "image/png"
    replace_image_buffer(m_gltf, m_bin, m_gltf["images"][0]["bufferView"], mac_png)
    pack_glb(mac_glb, m_gltf, m_bin)
    print("Upgraded w1_05_macaron.glb: richer berry-rose shell + warm buttercream filling")


if __name__ == "__main__":
    upgrade_boba_glb()
    upgrade_cake_and_macaron()
