#!/usr/bin/env python3
"""
Gobble Pop! V2.0 — High-CTR CrazyGames & Multi-Store Cover & Icon Builder.
Composites our tight-matted glossy 3D "GOBBLE POP!" sticker logo + vibrant arcade sunburst
glow onto our real 4x-MSAA Godot V2.0 Kenney All-Worlds Floating Island 3D Hero Plates:
  - 1:1 Square Icons (1024x1024, 512x512, 800x800, assets/web/app_icon.png)
  - 16:9 Landscape CrazyGames Hero Banner (1920x1080)
  - 2.05:1 Google Play Feature Graphic (1024x500)
  - 2:3 Portrait CrazyGames Mobile Card (800x1200)
  - 3:4 H5 Splash Loading Card (900x1200)
"""
import collections
import math
import os
import subprocess

FFMPEG = "/opt/homebrew/bin/ffmpeg"
ROOT_DIR = "/Users/unmercy/Documents/antig/hole"
STORE_DIR = os.path.join(ROOT_DIR, "build", "store_assets")
LOGO_SRC = "/Users/unmercy/.gemini/antigravity/brain/05ca6bad-84af-41dd-8dfd-980d8db739f2/gobble_pop_square_v2_1795407926236.jpg"
PLATES_DIR = "/Users/unmercy/.gemini/antigravity/brain/3be651bd-193c-44b0-a17f-2db6960914a9/scratch"

PLATE_SQUARE = os.path.join(PLATES_DIR, "v2_plate_square_1024.png")
PLATE_LANDSCAPE = os.path.join(PLATES_DIR, "v2_plate_landscape_1920.png")
PLATE_PORTRAIT = os.path.join(PLATES_DIR, "v2_plate_portrait_800x1200.png")
PLATE_SPLASH = os.path.join(PLATES_DIR, "v2_plate_splash_9x16.png")


def load_rgb(path: str, w: int, h: int) -> bytes:
    cmd = [
        FFMPEG, "-v", "error", "-i", path,
        "-vf", f"scale={w}:{h}:flags=lanczos",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-"
    ]
    return subprocess.check_output(cmd)


def save_rgb(raw: bytes, w: int, h: int, out_path: str) -> None:
    cmd = [
        FFMPEG, "-y", "-v", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}",
        "-i", "-",
        "-frames:v", "1",
        out_path
    ]
    subprocess.run(cmd, input=raw, check=True)


def box_blur_float(grid: list, w: int, h: int, radius: int) -> list:
    if radius <= 0:
        return list(grid)
    tmp = [0.0] * (w * h)
    out = [0.0] * (w * h)
    for y in range(h):
        row_off = y * w
        for x in range(w):
            x0 = max(0, x - radius)
            x1 = min(w - 1, x + radius)
            s = 0.0
            for xx in range(x0, x1 + 1):
                s += grid[row_off + xx]
            tmp[row_off + x] = s / (x1 - x0 + 1)
    for x in range(w):
        for y in range(h):
            y0 = max(0, y - radius)
            y1 = min(h - 1, y + radius)
            s = 0.0
            for yy in range(y0, y1 + 1):
                s += tmp[yy * w + x]
            out[y * w + x] = s / (y1 - y0 + 1)
    return out


def extract_logo_rgba_patch(src_rgb: bytes, src_w: int, src_h: int):
    x0, y0, x1, y1 = 240, 45, 780, 360
    pw, ph = x1 - x0, y1 - y0
    pixels = []
    for py in range(ph):
        y = y0 + py
        for px in range(pw):
            x = x0 + px
            idx = (y * src_w + x) * 3
            pixels.append((float(src_rgb[idx]), float(src_rgb[idx + 1]), float(src_rgb[idx + 2])))

    top_b = [pixels[px] for px in range(pw)]
    bot_b = [pixels[(ph - 1) * pw + px] for px in range(pw)]

    bg_est = []
    for py in range(ph):
        t_y = py / max(1.0, float(ph - 1))
        left_c = pixels[py * pw]
        right_c = pixels[py * pw + pw - 1]
        for px in range(pw):
            t_x = px / max(1.0, float(pw - 1))
            wt = 1.0 / max(1e-3, t_y)
            wb = 1.0 / max(1e-3, 1.0 - t_y)
            wl = 1.0 / max(1e-3, t_x)
            wr = 1.0 / max(1e-3, 1.0 - t_x)
            ws = wt + wb + wl + wr
            tc, bc = top_b[px], bot_b[px]
            bg_est.append((
                (tc[0] * wt + bc[0] * wb + left_c[0] * wl + right_c[0] * wr) / ws,
                (tc[1] * wt + bc[1] * wb + left_c[1] * wl + right_c[1] * wr) / ws,
                (tc[2] * wt + bc[2] * wb + left_c[2] * wl + right_c[2] * wr) / ws,
            ))

    exterior = [False] * (pw * ph)
    q = collections.deque()

    def is_bg(px: int, py: int, prev_rgb):
        i = py * pw + px
        r, g, b = pixels[i]
        mx, mn = max(r, g, b), min(r, g, b)
        sat = mx - mn
        # 1. Protect the crisp pure-white sticker rim around GOBBLE POP! (and its soft light-grey rim shadow)
        if r > 228.0 and g > 228.0 and b > 232.0 and sat < 18.0:
            return False
        # 2. Protect dark outlines & saturated letter interiors
        if mn < 130.0:
            return False
        # 3. Protect warm sparkles & letters (pink, yellow, orange, lavender)
        if r > b + 8.0 or (r > 165.0 and b > 165.0 and g < min(r, b) - 10.0):
            return False
        # 4. Cool pastel sky-cyan (B >= G >= R, bright B > 200) or pale sky-cream gradient -> 100% exterior sky!
        if b >= r + 6.0 and b > 195.0 and g > 190.0:
            return True
        if mn > 202.0 and sat < 34.0 and r < 236.0:
            return True
        return False

    for px in range(pw):
        for py in (0, ph - 1):
            i = py * pw + px
            exterior[i] = True
            q.append((px, py))
    for py in range(ph):
        for px in (0, pw - 1):
            i = py * pw + px
            if not exterior[i]:
                exterior[i] = True
                q.append((px, py))

    while q:
        cx, cy = q.popleft()
        c_rgb = pixels[cy * pw + cx]
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < pw and 0 <= ny < ph:
                ni = ny * pw + nx
                if not exterior[ni] and is_bg(nx, ny, c_rgb):
                    exterior[ni] = True
                    q.append((nx, ny))

    raw_alpha = [0.0 if exterior[i] else 1.0 for i in range(pw * ph)]
    alpha = box_blur_float(raw_alpha, pw, ph, 1)

    fg_pixels = []
    for i in range(pw * ph):
        a = alpha[i]
        r, g, b = pixels[i]
        if 0.02 < a < 0.95:
            br, bg, bb = bg_est[i]
            r = max(0.0, min(255.0, (r - (1.0 - a) * br) / a))
            g = max(0.0, min(255.0, (g - (1.0 - a) * bg) / a))
            b = max(0.0, min(255.0, (b - (1.0 - a) * bb) / a))
        fg_pixels.append((r, g, b))

    return pw, ph, fg_pixels, alpha


def sample_bilinear(patch, u: float, v: float):
    pw, ph, fg_pixels, alpha = patch
    x0 = max(0, min(pw - 1, int(u)))
    y0 = max(0, min(ph - 1, int(v)))
    x1 = min(pw - 1, x0 + 1)
    y1 = min(ph - 1, y0 + 1)
    fx, fy = u - x0, v - y0
    i00, i10, i01, i11 = y0 * pw + x0, y0 * pw + x1, y1 * pw + x0, y1 * pw + x1
    w00, w10, w01, w11 = (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy
    p00, p10, p01, p11 = fg_pixels[i00], fg_pixels[i10], fg_pixels[i01], fg_pixels[i11]
    return (
        p00[0] * w00 + p10[0] * w10 + p01[0] * w01 + p11[0] * w11,
        p00[1] * w00 + p10[1] * w10 + p01[1] * w01 + p11[1] * w11,
        p00[2] * w00 + p10[2] * w10 + p01[2] * w01 + p11[2] * w11,
        alpha[i00] * w00 + alpha[i10] * w10 + alpha[i01] * w01 + alpha[i11] * w11,
    )


def add_sky_sunburst_and_logo(plate_rgb: bytes, w: int, h: int, logo_patch, logo_rect: tuple, burst_center: tuple) -> bytes:
    """Adds subtle energetic radiant sky sunburst rays + crisp elevated drop-shadow + glossy 3D GOBBLE POP! logo."""
    buf = bytearray(plate_rgb)
    bcx, bcy = burst_center
    max_r = math.hypot(w, h) * 0.72

    # 1. Subtle radiant sky sunburst beams ONLY on blue sky pixels (never washes out wood/food/clouds!)
    for y in range(h):
        dy = y - bcy
        row_off = y * w * 3
        for x in range(w):
            idx = row_off + x * 3
            r, g, b = buf[idx], buf[idx + 1], buf[idx + 2]
            # Sky detector: vibrant blue-dominant pixel (b > r + 45)
            if b > r + 42 and b > 170:
                dx = x - bcx
                ang = math.atan2(dy, dx)
                ray = 0.5 + 0.5 * math.sin(ang * 14.0)
                dist = math.hypot(dx, dy)
                falloff = max(0.0, 1.0 - dist / max_r)
                boost = ray * falloff * 24.0
                buf[idx] = min(255, int(r + boost * 1.15))
                buf[idx + 1] = min(255, int(g + boost * 1.05))
                buf[idx + 2] = min(255, int(b + boost * 0.70))

    # 2. Stamp soft elevated navy drop shadow beneath logo + crisp glossy logo!
    pw, ph = logo_patch[0], logo_patch[1]
    dx0, dy0, dw, dh = logo_rect
    sh_off_y = max(6, int(dh * 0.045))

    # Pass A: Drop shadow
    for dy in range(dh):
        y = dy0 + dy + sh_off_y
        if y < 0 or y >= h:
            continue
        v = dy * (ph - 1) / max(1, dh - 1)
        for dx in range(dw):
            x = dx0 + dx
            if x < 0 or x >= w:
                continue
            u = dx * (pw - 1) / max(1, dw - 1)
            _, _, _, a = sample_bilinear(logo_patch, u, v)
            if a <= 0.05:
                continue
            sa = a * 0.34
            idx = (y * w + x) * 3
            buf[idx] = int(buf[idx] * (1.0 - sa) + 12.0 * sa)
            buf[idx + 1] = int(buf[idx + 1] * (1.0 - sa) + 34.0 * sa)
            buf[idx + 2] = int(buf[idx + 2] * (1.0 - sa) + 72.0 * sa)

    # Pass B: Crisp 3D Logo Sticker
    for dy in range(dh):
        y = dy0 + dy
        if y < 0 or y >= h:
            continue
        v = dy * (ph - 1) / max(1, dh - 1)
        for dx in range(dw):
            x = dx0 + dx
            if x < 0 or x >= w:
                continue
            u = dx * (pw - 1) / max(1, dw - 1)
            pr, pg, pb, a = sample_bilinear(logo_patch, u, v)
            if a <= 0.005:
                continue
            idx = (y * w + x) * 3
            buf[idx] = max(0, min(255, int(round(a * pr + (1.0 - a) * buf[idx]))))
            buf[idx + 1] = max(0, min(255, int(round(a * pg + (1.0 - a) * buf[idx + 1]))))
            buf[idx + 2] = max(0, min(255, int(round(a * pb + (1.0 - a) * buf[idx + 2]))))

    return bytes(buf)


def main():
    icons_dir = os.path.join(STORE_DIR, "icons")
    covers_dir = os.path.join(STORE_DIR, "covers")
    os.makedirs(icons_dir, exist_ok=True)
    os.makedirs(covers_dir, exist_ok=True)

    logo_src_rgb = load_rgb(LOGO_SRC, 1024, 1024)
    logo_patch = extract_logo_rgba_patch(logo_src_rgb, 1024, 1024)

    # 1. Square 1:1 High-CTR Icon & Square Cover (1024x1024 -> 800, 512, app_icon)
    sq_plate = load_rgb(PLATE_SQUARE, 1024, 1024)
    sq_final = add_sky_sunburst_and_logo(
        sq_plate, 1024, 1024, logo_patch,
        logo_rect=(152, 34, 720, 420),
        burst_center=(512, 620)
    )
    sq_1024_path = os.path.join(icons_dir, "icon_1024x1024_no_alpha.png")
    save_rgb(sq_final, 1024, 1024, sq_1024_path)

    for sz, out_p in [
        (512, os.path.join(icons_dir, "icon_512x512_no_alpha.png")),
        (512, os.path.join(ROOT_DIR, "assets", "web", "app_icon.png")),
        (800, os.path.join(covers_dir, "crazygames_square_800x800.png")),
        (800, os.path.join(covers_dir, "crazygames_square_800x800.jpg")),
    ]:
        subprocess.run([
            FFMPEG, "-y", "-v", "error", "-i", sq_1024_path,
            "-vf", f"scale={sz}:{sz}:flags=lanczos,format=rgb24",
            out_p
        ], check=True)

    # 2. Landscape 16:9 CrazyGames Hero Banner (1920x1080)
    land_plate = load_rgb(PLATE_LANDSCAPE, 1920, 1080)
    land_final = add_sky_sunburst_and_logo(
        land_plate, 1920, 1080, logo_patch,
        logo_rect=(95, 255, 790, 460),
        burst_center=(1280, 560)
    )
    for ext in ("png", "jpg"):
        save_rgb(land_final, 1920, 1080, os.path.join(covers_dir, f"crazygames_landscape_1920x1080.{ext}"))

    # 3. Google Play Feature Graphic (1024x500) from Landscape plate
    feat_plate = load_rgb(PLATE_LANDSCAPE, 1024, 500)
    feat_final = add_sky_sunburst_and_logo(
        feat_plate, 1024, 500, logo_patch,
        logo_rect=(46, 118, 420, 245),
        burst_center=(685, 260)
    )
    save_rgb(feat_final, 1024, 500, os.path.join(covers_dir, "google_play_feature_graphic_1024x500.png"))

    # 4. Portrait 2:3 CrazyGames Mobile Cover (800x1200)
    port_plate = load_rgb(PLATE_PORTRAIT, 800, 1200)
    port_final = add_sky_sunburst_and_logo(
        port_plate, 800, 1200, logo_patch,
        logo_rect=(80, 96, 640, 374),
        burst_center=(400, 740)
    )
    for ext in ("png", "jpg"):
        save_rgb(port_final, 800, 1200, os.path.join(covers_dir, f"crazygames_portrait_800x1200.{ext}"))

    # 5. Fullscreen 9:16 Mobile Splash Screen (1080x1920) — Hero title + floating island dead-center!
    splash_src = PLATE_SPLASH if os.path.isfile(PLATE_SPLASH) else PLATE_PORTRAIT
    splash_plate = load_rgb(splash_src, 1080, 1920)
    splash_final = add_sky_sunburst_and_logo(
        splash_plate, 1080, 1920, logo_patch,
        logo_rect=(120, 295, 840, 490),
        burst_center=(540, 1040)
    )
    save_rgb(splash_final, 1080, 1920, os.path.join(ROOT_DIR, "assets", "web", "cover_splash.jpg"))
    save_rgb(splash_final, 1080, 1920, os.path.join(ROOT_DIR, "build", "h5", "cover_splash.jpg"))

    print("All V2.0 High-CTR Kenney 3D Diorama covers & icons built successfully!")


if __name__ == "__main__":
    main()
