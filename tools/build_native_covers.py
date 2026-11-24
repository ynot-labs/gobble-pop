#!/usr/bin/env python3
"""
Gobble Pop! V2.1 — Concept 1 ("Pixar-Toy Vortex Feast") Unified Store Art & Splash Builder.
Generates exact-resolution, zero-crop-defect icons, covers, and fullscreen mobile splash
directly from the 4 native aspect-ratio Concept 1 master illustrations:
  - 9:16 Fullscreen Mobile Splash -> assets/web/cover_splash.jpg, build/h5/cover_splash.jpg (1080x1920)
  - 1:1 Square Master            -> icon_1024x1024_no_alpha.png, icon_512x512_no_alpha.png,
                                    assets/web/app_icon.png, crazygames_square_800x800.{png,jpg}
  - 16:9 Landscape Master        -> crazygames_landscape_1920x1080.{png,jpg},
                                    google_play_feature_graphic_1024x500.png
  - 2:3 Portrait Master          -> crazygames_portrait_800x1200.{png,jpg}
"""
import os
import subprocess

FFMPEG = "/opt/homebrew/bin/ffmpeg"
ROOT_DIR = "/Users/unmercy/Documents/antig/hole"
STORE_DIR = os.path.join(ROOT_DIR, "build", "store_assets")
ART_DIR = "/Users/unmercy/.gemini/antigravity/brain/3be651bd-193c-44b0-a17f-2db6960914a9"

SRC_SPLASH_9X16 = os.path.join(ART_DIR, "splash_concept_1_tornado_feast_1795476162082.jpg")
SRC_SQUARE_1X1 = os.path.join(ART_DIR, "concept1_icon_square_1x1_1795482158490.jpg")
SRC_LANDSCAPE_16X9 = os.path.join(ART_DIR, "concept1_landscape_16x9_1795482170955.jpg")
SRC_PORTRAIT_2X3 = os.path.join(ART_DIR, "concept1_portrait_2x3_1795482201539.jpg")


def run_ff(src: str, vf: str, dst: str, extra: list = None) -> None:
    if not os.path.isfile(src):
        raise FileNotFoundError(f"Missing Concept 1 master artwork: {src}")
    cmd = [FFMPEG, "-y", "-v", "error", "-i", src, "-vf", vf]
    if extra:
        cmd.extend(extra)
    cmd.append(dst)
    subprocess.run(cmd, check=True)


def main():
    icons_dir = os.path.join(STORE_DIR, "icons")
    covers_dir = os.path.join(STORE_DIR, "covers")
    os.makedirs(icons_dir, exist_ok=True)
    os.makedirs(covers_dir, exist_ok=True)

    # 1. 1:1 Square Icons & CrazyGames Square Cover (24-bit RGB, zero alpha)
    run_ff(SRC_SQUARE_1X1, "scale=1024:1024:flags=lanczos,format=rgb24", os.path.join(icons_dir, "icon_1024x1024_no_alpha.png"))
    run_ff(SRC_SQUARE_1X1, "scale=512:512:flags=lanczos,format=rgb24", os.path.join(icons_dir, "icon_512x512_no_alpha.png"))
    run_ff(SRC_SQUARE_1X1, "scale=512:512:flags=lanczos,format=rgb24", os.path.join(ROOT_DIR, "assets", "web", "app_icon.png"))
    run_ff(SRC_SQUARE_1X1, "scale=800:800:flags=lanczos,format=rgb24", os.path.join(covers_dir, "crazygames_square_800x800.png"))
    run_ff(SRC_SQUARE_1X1, "scale=800:800:flags=lanczos,format=rgb24", os.path.join(covers_dir, "crazygames_square_800x800.jpg"), ["-q:v", "2"])

    # 2. 16:9 CrazyGames Landscape Hero Banner (1920x1080) & Google Play Feature Graphic (1024x500)
    run_ff(SRC_LANDSCAPE_16X9, "scale=1920:1080:flags=lanczos,format=rgb24", os.path.join(covers_dir, "crazygames_landscape_1920x1080.png"))
    run_ff(SRC_LANDSCAPE_16X9, "scale=1920:1080:flags=lanczos,format=rgb24", os.path.join(covers_dir, "crazygames_landscape_1920x1080.jpg"), ["-q:v", "2"])
    # 1024x500 (2.048:1) from 16:9 (1.778:1): gentle center-crop keeps 100% of logo & island cleanly uncut
    run_ff(
        SRC_LANDSCAPE_16X9,
        "scale=1024:576:flags=lanczos,crop=1024:500:0:38,format=rgb24",
        os.path.join(covers_dir, "google_play_feature_graphic_1024x500.png")
    )

    # 3. 2:3 CrazyGames Mobile Portrait Card (800x1200)
    run_ff(SRC_PORTRAIT_2X3, "scale=800:1200:flags=lanczos,format=rgb24", os.path.join(covers_dir, "crazygames_portrait_800x1200.png"))
    run_ff(SRC_PORTRAIT_2X3, "scale=800:1200:flags=lanczos,format=rgb24", os.path.join(covers_dir, "crazygames_portrait_800x1200.jpg"), ["-q:v", "2"])

    # 4. 9:16 Fullscreen Mobile Loading Splash (1080x1920)
    for dst in (
        os.path.join(ROOT_DIR, "assets", "web", "cover_splash.jpg"),
        os.path.join(ROOT_DIR, "build", "h5", "cover_splash.jpg"),
    ):
        run_ff(SRC_SPLASH_9X16, "scale=1080:1920:flags=lanczos,format=rgb24", dst, ["-q:v", "2"])

    print("All V2.1 Concept 1 ('Pixar-Toy Vortex Feast') store covers, icons & fullscreen splash built cleanly!")


if __name__ == "__main__":
    main()
