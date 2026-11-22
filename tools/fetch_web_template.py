#!/usr/bin/env python3
"""
Fast HTTP-Range extractor using macOS curl: fetches ONLY web_nothreads_release.zip &
web_nothreads_debug.zip (~25 MB) from Godot_v4.6.1-stable_export_templates.tpz.
"""
import os
import re
import struct
import subprocess
import zlib

URL = "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"
TARGETS = {
    "templates/web_nothreads_release.zip",
    "templates/web_nothreads_debug.zip",
    "templates/version.txt",
}
OUT_DIRS = [
    "/tmp/godot_home/Library/Application Support/Godot/export_templates/4.6.1.stable",
    "/Users/unmercy/Library/Application Support/Godot/export_templates/4.6.1.stable",
]


def get_size(url):
    out = subprocess.check_output(["curl", "-sIL", url]).decode("utf-8", errors="replace")
    sizes = re.findall(r"(?i)^content-length:\s*(\d+)", out, flags=re.M)
    if not sizes:
        raise RuntimeError("Could not determine Content-Length")
    return int(sizes[-1])


def http_range(url, start, end):
    return subprocess.check_output(["curl", "-sSL", "-r", f"{start}-{end}", url])


def main():
    total_size = get_size(URL)
    print(f"TPZ total size: {total_size / (1024*1024):.1f} MB")

    tail_len = min(65536, total_size)
    tail = http_range(URL, total_size - tail_len, total_size - 1)
    eocd_pos = tail.rfind(b"PK\x05\x06")
    if eocd_pos < 0:
        raise RuntimeError("Could not find ZIP EOCD")
    cd_size, cd_offset = struct.unpack_from("<II", tail, eocd_pos + 12)
    print(f"Central Directory: offset={cd_offset}, size={cd_size}")

    cd_data = http_range(URL, cd_offset, cd_offset + cd_size - 1)
    pos = 0
    found = {}
    while pos < len(cd_data):
        if cd_data[pos:pos + 4] != b"PK\x01\x02":
            break
        comp_method = struct.unpack_from("<H", cd_data, pos + 10)[0]
        comp_size, uncomp_size = struct.unpack_from("<II", cd_data, pos + 20)
        fname_len, extra_len, cmt_len = struct.unpack_from("<HHH", cd_data, pos + 28)
        local_offset = struct.unpack_from("<I", cd_data, pos + 42)[0]
        fname = cd_data[pos + 46:pos + 46 + fname_len].decode("utf-8", errors="replace")
        pos += 46 + fname_len + extra_len + cmt_len
        base = os.path.basename(fname)
        if base in ("web_nothreads_release.zip", "web_nothreads_debug.zip", "version.txt"):
            found[fname] = (comp_method, comp_size, uncomp_size, local_offset)
    if not found:
        print("No matches; listing all entries...")
        pos = 0
        while pos < len(cd_data) and cd_data[pos:pos + 4] == b"PK\x01\x02":
            fn_l, ex_l, cm_l = struct.unpack_from("<HHH", cd_data, pos + 28)
            print(" ", cd_data[pos + 46:pos + 46 + fn_l].decode("utf-8", errors="replace"))
            pos += 46 + fn_l + ex_l + cm_l

    for out_d in OUT_DIRS:
        os.makedirs(out_d, exist_ok=True)

    for fname, (method, csize, usize, loff) in found.items():
        print(f"Fetching {fname} ({csize / (1024*1024):.2f} MB)...")
        lh = http_range(URL, loff, loff + 29)
        fn_l, ex_l = struct.unpack_from("<HH", lh, 26)
        data_start = loff + 30 + fn_l + ex_l
        raw = http_range(URL, data_start, data_start + csize - 1)
        if method == 0:
            content = raw
        elif method == 8:
            content = zlib.decompress(raw, -15)
        else:
            raise RuntimeError(f"Unsupported compression method {method}")

        base = os.path.basename(fname)
        for out_d in OUT_DIRS:
            with open(os.path.join(out_d, base), "wb") as f:
                f.write(content)
        print(f"Installed {base} ({len(content) / (1024*1024):.2f} MB)")


if __name__ == "__main__":
    main()
