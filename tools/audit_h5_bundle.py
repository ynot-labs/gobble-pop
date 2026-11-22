#!/usr/bin/env python3
"""Audit H5 export bundle sizes (raw + gzip + asset breakdown) against YouTube Playables & CrazyGames specs."""
import gzip
import os

H5_DIR = "/Users/unmercy/Documents/antig/hole/build/h5"
ASSETS_3D = [
    "/Users/unmercy/Documents/antig/hole/assets/models/core",
    "/Users/unmercy/Documents/antig/hole/assets/models/world1",
]
ASSETS_TEX = "/Users/unmercy/Documents/antig/hole/assets/textures"
ASSETS_AUDIO = "/Users/unmercy/Documents/antig/hole/assets/audio"


def dir_size_kb(path):
    total = 0
    for root, _, files in os.walk(path):
        for fn in files:
            if fn.endswith(".import"):
                continue
            total += os.path.getsize(os.path.join(root, fn))
    return total / 1024.0


def main():
    kb_3d = sum(dir_size_kb(d) for d in ASSETS_3D)
    kb_tex = dir_size_kb(ASSETS_TEX)
    kb_audio = dir_size_kb(ASSETS_AUDIO)
    print("=== PURE FIRST-PACK SOURCE ASSETS ===")
    print(f"  3D GLB Models (13 items): {kb_3d:7.1f} KB  (Budget <= 833 KB)")
    print(f"  Textures & VFX Atlas:     {kb_tex:7.1f} KB")
    print(f"  Audio (13 SFX + 1 BGM):   {kb_audio:7.1f} KB  (Budget <= 563 KB)")
    print(f"  Total Pure Assets:        {kb_3d + kb_tex + kb_audio:7.1f} KB ({(kb_3d + kb_tex + kb_audio)/1024.0:.2f} MB / 1.36 MB budget)")

    if not os.path.isdir(H5_DIR):
        print("H5 build directory not found yet.")
        return

    print("\n=== H5 EXPORT BUNDLE (build/h5) ===")
    raw_total = 0
    gz_total = 0
    for fn in sorted(os.listdir(H5_DIR)):
        p = os.path.join(H5_DIR, fn)
        if not os.path.isfile(p):
            continue
        raw = os.path.getsize(p)
        with open(p, "rb") as f:
            gz = len(gzip.compress(f.read(), compresslevel=6))
        raw_total += raw
        gz_total += gz
        print(f"  {fn:34s} | raw: {raw/1024:8.1f} KB | gzip: {gz/1024:8.1f} KB")
    print(f"  TOTAL H5 BUNDLE                   | raw: {raw_total/(1024*1024):6.2f} MB | gzip: {gz_total/(1024*1024):6.2f} MB")
    print(f"  YouTube Playables (<15 MiB rec):  {'PASS' if gz_total < 15*1024*1024 else 'CHECK'}")
    print(f"  CrazyGames Mobile (<=20 MB):      {'PASS' if gz_total <= 20*1024*1024 else 'CHECK'}")


if __name__ == "__main__":
    main()
