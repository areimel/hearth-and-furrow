"""Render the launch video page frame by frame into PNGs.

Usage (from the repo root):
    uv run --with playwright python -I brag-output/work/render.py
    uv run --with playwright python -I brag-output/work/render.py --only 0,10,220
    uv run --with playwright python -I brag-output/work/render.py --start 100 --end 199 --out /tmp/x

Options:
    --start N   first frame (default 0)
    --end M     last frame, inclusive (default 639)
    --only LIST comma-separated frame indexes; overrides --start/--end
    --out DIR   output directory (default brag-output/work/frames)
    --page P    page path relative to the repo root (default brag-output/work/video.html)

The page must define window.seek(frame) which resolves once that frame is drawn.
The repo root is served over HTTP on a free 127.0.0.1 port so relative asset paths work.
"""

import argparse
import functools
import glob
import http.server
import os
import struct
import subprocess
import sys
import threading

WORK = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(WORK))
TOTAL_FRAMES = 640
WIDTH, HEIGHT = 1920, 1080
PNG_SIG = b"\x89PNG\r\n\x1a\n"
PLAYWRIGHT_CACHE = os.path.expanduser("~/.cache/ms-playwright")


def parse_args():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int, default=TOTAL_FRAMES - 1)
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.join(WORK, "frames"))
    ap.add_argument("--page", default="brag-output/work/video.html")
    args = ap.parse_args()
    if args.only:
        args.frames = sorted({int(x) for x in args.only.split(",") if x.strip()})
    else:
        args.frames = list(range(args.start, args.end + 1))
    for f in args.frames:
        if not 0 <= f < TOTAL_FRAMES:
            ap.error(f"frame {f} outside 0..{TOTAL_FRAMES - 1}")
    return args


def start_server():
    """Serve REPO over HTTP on a free loopback port; return (server, port)."""
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=REPO))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, server.server_address[1]


def launch_browser(p):
    """Try the bundled browser, then the system Chrome channel, then any cached chromium build."""
    attempts = [("bundled chromium", lambda: p.chromium.launch(headless=True)),
                ("channel=chrome", lambda: p.chromium.launch(headless=True, channel="chrome"))]
    cached = sorted(glob.glob(os.path.join(PLAYWRIGHT_CACHE, "chromium-*", "chrome-linux*", "chrome")),
                    reverse=True)
    cached += sorted(glob.glob(os.path.join(PLAYWRIGHT_CACHE, "chromium_headless_shell-*",
                                            "chrome-headless-shell-linux*", "chrome-headless-shell")),
                     reverse=True)
    for exe in cached:
        attempts.append((f"executable {exe}", lambda exe=exe: p.chromium.launch(headless=True, executable_path=exe)))
    errors = []
    for name, fn in attempts:
        try:
            browser = fn()
            print(f"browser: {name}", flush=True)
            return browser
        except Exception as e:  # noqa: BLE001 - try the next launch path
            errors.append(f"  {name}: {str(e).splitlines()[0][:160]}")
    sys.exit("could not launch a browser:\n" + "\n".join(errors))


def png_header(path):
    """Return (width, height, colour_type, bit_depth) from the IHDR chunk."""
    with open(path, "rb") as fh:
        head = fh.read(26)
    if head[:8] != PNG_SIG:
        raise ValueError(f"{path} is not a PNG")
    w, h = struct.unpack(">II", head[16:24])
    return w, h, head[25], head[24]


def normalise_to_rgb(path):
    """Rewrite a PNG as 8-bit RGB (drops any alpha channel) using ffmpeg."""
    tmp = path + ".rgb.png"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-frames:v", "1",
                    "-pix_fmt", "rgb24", tmp], check=True)
    os.replace(tmp, path)


def main():
    args = parse_args()
    os.makedirs(args.out, exist_ok=True)

    # Playwright is imported here so --help works without it.
    from playwright.sync_api import sync_playwright

    server, port = start_server()
    url = f"http://127.0.0.1:{port}/{args.page.lstrip('/')}"
    print(f"serving {REPO} on port {port}; page {url}", flush=True)
    rendered = 0
    try:
        with sync_playwright() as p:
            browser = launch_browser(p)
            try:
                page = browser.new_page(viewport={"width": WIDTH, "height": HEIGHT},
                                        device_scale_factor=1)
                page.on("pageerror", lambda e: print(f"page error: {e}", file=sys.stderr, flush=True))
                page.goto(url, wait_until="load")
                page.wait_for_function("typeof window.seek === 'function'", timeout=30000)
                total = len(args.frames)
                for i, f in enumerate(args.frames, 1):
                    page.evaluate("f => window.seek(f)", f)
                    page.screenshot(path=os.path.join(args.out, "%04d.png" % f),
                                    type="png", omit_background=False)
                    rendered += 1
                    if i % 40 == 0 or i == total:
                        print(f"rendered {i}/{total} (frame {f})", flush=True)
            finally:
                browser.close()
    finally:
        server.shutdown()

    # Verify: every requested file exists, is 1920x1080, and is 8-bit RGB (colour type 2).
    missing = [f for f in args.frames if not os.path.exists(os.path.join(args.out, "%04d.png" % f))]
    if missing:
        sys.exit(f"missing frames: {missing[:10]}")
    fixed = 0
    for f in args.frames:
        path = os.path.join(args.out, "%04d.png" % f)
        w, h, ctype, depth = png_header(path)
        if (w, h) != (WIDTH, HEIGHT):
            sys.exit(f"{path} is {w}x{h}, expected {WIDTH}x{HEIGHT}")
        if ctype != 2 or depth != 8:
            normalise_to_rgb(path)
            fixed += 1
            w, h, ctype, depth = png_header(path)
            if (ctype, depth) != (2, 8):
                sys.exit(f"{path} still not 8-bit RGB after conversion (type {ctype}, depth {depth})")
    all_pngs = glob.glob(os.path.join(args.out, "[0-9][0-9][0-9][0-9].png"))
    print(f"rendered {rendered} frames to {args.out}", flush=True)
    print(f"verified {len(args.frames)} files: {WIDTH}x{HEIGHT}, 8-bit RGB"
          f" ({fixed} converted from alpha/other modes); {len(all_pngs)} PNGs in folder", flush=True)
    if len(all_pngs) != len(args.frames):
        print(f"note: folder holds {len(all_pngs)} PNGs but this run wrote {len(args.frames)}"
              " (stale frames from an earlier run?)", flush=True)


if __name__ == "__main__":
    main()
