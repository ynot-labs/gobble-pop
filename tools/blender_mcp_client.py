#!/usr/bin/env python3
"""Minimal client for the official MCP for Blender addon running on localhost:9876."""
import json
import socket
import sys


from typing import Optional


def send_cmd(cmd_type: str, params: Optional[dict] = None, host: str = "127.0.0.1", port: int = 9876, timeout: float = 180.0) -> dict:
    payload = json.dumps({"type": cmd_type, "params": params or {}}).encode("utf-8")
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock.sendall(payload)
        chunks = []
        while True:
            data = sock.recv(65536)
            if not data:
                break
            chunks.append(data)
            try:
                return json.loads(b"".join(chunks).decode("utf-8"))
            except json.JSONDecodeError:
                continue
    return {"status": "error", "message": "Empty response from Blender MCP"}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: blender_mcp_client.py ping | exec_file <script.py> | screenshot <out.png>")
        sys.exit(1)
    action = sys.argv[1]
    if action == "ping":
        print(json.dumps(send_cmd("ping"), indent=2))
    elif action == "exec_file":
        with open(sys.argv[2], "r", encoding="utf-8") as f:
            code = f.read()
        res = send_cmd("execute_code", {"code": code}, timeout=300.0)
        print(json.dumps(res, indent=2, ensure_ascii=False))
        if res.get("status") != "success":
            sys.exit(2)
    elif action == "screenshot":
        out = sys.argv[2]
        res = send_cmd("get_viewport_screenshot", {"max_size": 1280, "filepath": out, "format": "png"})
        print(json.dumps(res, indent=2, ensure_ascii=False))
