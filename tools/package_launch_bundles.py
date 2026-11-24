#!/usr/bin/env python3
"""
Gobble Pop! — One-Click Multi-Platform Launch Packager & Store Asset Generator (v1.1.0)
Generates and audits:
  1. build/releases/gobble_pop_v1.1.0_crazygames.zip        (CrazyGames SDK v3 injected)
  2. build/releases/gobble_pop_v1.1.0_youtube_playables.zip (YouTube Playables SDK v1 injected)
  3. build/releases/gobble_pop_v1.1.0_web_standalone.zip    (Itch.io / Self-Hosted clean H5)
  4. build/store_assets/                                    (Icons, Covers, Screenshots, Trailers, Copy)
"""
import gzip
import os
import re
import shutil
import subprocess
import zipfile

ROOT_DIR = "/Users/unmercy/Documents/antig/hole"
H5_DIR = os.path.join(ROOT_DIR, "build", "h5")
RELEASES_DIR = os.path.join(ROOT_DIR, "build", "releases")
STORE_DIR = os.path.join(ROOT_DIR, "build", "store_assets")
FFMPEG = "/opt/homebrew/bin/ffmpeg"

RUNTIME_FILES = [
    "index.html",
    "index.js",
    "index.pck",
    "index.wasm",
    "index.audio.worklet.js",
    "index.audio.position.worklet.js",
    "index.icon.png",
    "index.apple-touch-icon.png",
    "index.png",
    "cover_splash.jpg",
]

MARKER = "<!-- $PLATFORM_SDK_HEAD_INJECT -->"
CG_SCRIPT = '<script src="https://sdk.crazygames.com/crazygames-sdk-v3.js"></script>'
YT_SCRIPT = '<script src="https://www.youtube.com/game_api/v1"></script>\n\t<script>window._gpSplitWasm=true;</script>'


def inject_sdk(html_text: str, sdk_tag: str) -> str:
    if not sdk_tag:
        return html_text.replace(f"\t{MARKER}\n", "").replace(MARKER, "")
    if MARKER in html_text:
        return html_text.replace(MARKER, sdk_tag)
    # Fallback: insert right after <head>
    return html_text.replace("<head>", f"<head>\n\t{sdk_tag}", 1)


def build_channel_zip(zip_name: str, sdk_tag: str, channel_label: str) -> dict:
    os.makedirs(RELEASES_DIR, exist_ok=True)
    zip_path = os.path.join(RELEASES_DIR, zip_name)

    with open(os.path.join(H5_DIR, "index.html"), "r", encoding="utf-8") as f:
        base_html = f.read()

    patched_html = inject_sdk(base_html, sdk_tag)
    is_youtube = "youtube" in zip_name

    raw_total = 0
    gz_total = 0

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for fn in RUNTIME_FILES:
            src_path = os.path.join(H5_DIR, fn)
            if not os.path.isfile(src_path):
                raise FileNotFoundError(f"Missing required H5 export file: {src_path}")
            if fn == "index.html":
                data = patched_html.encode("utf-8")
                zf.writestr(fn, data)
                raw_total += len(data)
                gz_total += len(gzip.compress(data, compresslevel=6))
            elif fn == "index.wasm" and is_youtube:
                # Per YouTube Playables Stability Requirement §3:
                # "Every individual file within the game MUST be less than 30 MiB."
                # Split 35.94 MiB index.wasm into two 17.97 MiB parts transparently reassembled by window.fetch!
                with open(src_path, "rb") as rf:
                    wasm_bytes = rf.read()
                mid = len(wasm_bytes) // 2
                part1 = wasm_bytes[:mid]
                part2 = wasm_bytes[mid:]
                zf.writestr("index.wasm.part1", part1)
                zf.writestr("index.wasm.part2", part2)
                raw_total += len(wasm_bytes)
                gz_total += len(gzip.compress(part1, compresslevel=6)) + len(gzip.compress(part2, compresslevel=6))
            else:
                with open(src_path, "rb") as rf:
                    data = rf.read()
                zf.writestr(fn, data)
                raw_total += len(data)
                gz_total += len(gzip.compress(data, compresslevel=6))

    zip_size = os.path.getsize(zip_path)

    # Also output an unzipped directory for portals like CrazyGames that require dragging raw files directly
    if "crazygames" in zip_name:
        cg_raw_dir = os.path.join(RELEASES_DIR, "crazygames_upload_files")
        if os.path.isdir(cg_raw_dir):
            shutil.rmtree(cg_raw_dir)
        os.makedirs(cg_raw_dir, exist_ok=True)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(cg_raw_dir)

    # Pre-flight QA Audit of the generated zip
    with zipfile.ZipFile(zip_path, "r") as zf:
        names = zf.namelist()
        assert "index.html" in names, f"[{channel_label}] index.html missing at zip root!"
        assert not any("/" in n for n in names), f"[{channel_label}] Subfolders found in zip root!"
        html_check = zf.read("index.html").decode("utf-8")
        if sdk_tag:
            assert sdk_tag.splitlines()[0] in html_check, f"[{channel_label}] SDK tag missing from index.html!"
        if is_youtube:
            # Verify every single file in zip is < 30 MiB (YouTube Playables Stability §3)
            for info in zf.infolist():
                assert info.file_size < 30 * 1024 * 1024, (
                    f"[{channel_label}] File {info.filename} ({info.file_size/(1024*1024):.2f} MiB) exceeds 30 MiB limit!"
                )
            # Verify zero external http(s) URLs in index.html except youtube game_api
            urls = re.findall(r"https?://[^\s\"'<>]+", html_check)
            forbidden = [u for u in urls if not u.startswith("https://www.youtube.com/game_api/v1")]
            assert not forbidden, f"[{channel_label}] Forbidden external URLs found: {forbidden}"

    return {
        "channel": channel_label,
        "zip_name": zip_name,
        "zip_path": zip_path,
        "raw_mb": raw_total / (1024 * 1024),
        "gz_mb": gz_total / (1024 * 1024),
        "zip_mb": zip_size / (1024 * 1024),
    }


def generate_store_assets() -> None:
    import build_native_covers
    build_native_covers.main()

    shots_dir = os.path.join(STORE_DIR, "screenshots")
    video_dir = os.path.join(STORE_DIR, "video")
    for d in (shots_dir, video_dir):
        os.makedirs(d, exist_ok=True)

    promo_mp4 = os.path.join(ROOT_DIR, "build", "promo", "gobble_pop_ua_promo.mp4")

    # 3. High-Resolution 1080x1920 Vertical Store Screenshots & Video Trailers
    if os.path.isfile(promo_mp4):
        # Copy 9:16 portrait trailer
        portrait_dst = os.path.join(video_dir, "gobble_pop_trailer_portrait_1080x1920.mp4")
        shutil.copy2(promo_mp4, portrait_dst)

        # Generate 16:9 landscape trailer (1920x1080) for CrazyGames / YouTube / Steam-style portals
        landscape_dst = os.path.join(video_dir, "gobble_pop_trailer_landscape_1920x1080.mp4")
        subprocess.run([
            FFMPEG, "-y", "-v", "error", "-i", promo_mp4,
            "-filter_complex",
            "[0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=32:4[bg];"
            "[0:v]scale=-1:1080:flags=lanczos[fg];"
            "[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p[v]",
            "-map", "[v]", "-map", "0:a?",
            "-c:v", "libx264", "-preset", "fast", "-crf", "21",
            "-c:a", "copy",
            landscape_dst
        ], check=True)

        # Extract 5 key 1080x1920 vertical store screenshots at peak gameplay timestamps
        shot_specs = [
            ("2.2", "01_sweet_bakery_asmr_1080x1920.png"),
            ("11.2", "02_gacha_toybox_sticky_gum_1080x1920.png"),
            ("16.5", "03_fever_magnet_mega_combo_1080x1920.png"),
            ("23.8", "04_three_star_victory_rewards_1080x1920.png"),
            ("26.5", "05_home_lobby_worlds_and_skins_1080x1920.png"),
        ]
        for ts, fn in shot_specs:
            subprocess.run([
                FFMPEG, "-y", "-v", "error", "-ss", ts, "-i", promo_mp4,
                "-frames:v", "1", "-vf", "format=rgb24",
                os.path.join(shots_dir, fn)
            ], check=True)


def main():
    print("=== PACKAGING H5 LAUNCH SUBMISSION BUNDLES (v2.2.0) ===")
    results = [
        build_channel_zip("gobble_pop_v2.2.0_crazygames.zip", CG_SCRIPT, "CrazyGames SDK v3"),
        build_channel_zip("gobble_pop_v2.2.0_youtube_playables.zip", YT_SCRIPT, "YouTube Playables v1"),
        build_channel_zip("gobble_pop_v2.2.0_web_standalone.zip", "", "Standalone Web / Itch.io"),
    ]
    for r in results:
        print(
            f"  [PASS] {r['channel']:25s} -> {r['zip_name']:38s} "
            f"| zip: {r['zip_mb']:5.2f} MB | gzip: {r['gz_mb']:5.2f} MB | raw: {r['raw_mb']:5.2f} MB"
        )
    print("\n=== GENERATING STORE ICONS, COVERS, SCREENSHOTS & TRAILERS ===")
    generate_store_assets()
    print("  [PASS] Store assets generated in build/store_assets/")


if __name__ == "__main__":
    main()
