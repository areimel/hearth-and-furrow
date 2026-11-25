import sys, glob, os
from playwright.sync_api import sync_playwright
here = os.path.dirname(os.path.abspath(__file__)); os.makedirs(here + "/preview", exist_ok=True)
frames = [int(a) for a in sys.argv[1:]] or [20,90,150,200,300,350,420,470,540,620]
with sync_playwright() as p:
    b = p.chromium.launch(executable_path="/usr/bin/google-chrome", args=["--allow-file-access-from-files"])
    pg = b.new_page(viewport={"width":1920,"height":1080})
    pg.on("console", lambda m: print("console:", m.text)); pg.on("pageerror", lambda e: print("ERR", e))
    pg.goto("file://" + here + "/video.html")
    pg.wait_for_function("typeof window.seek==='function'")
    for f in frames:
        pg.evaluate("f=>window.seek(f)", f)
        pg.screenshot(path=f"{here}/preview/f{f:03d}.png")
    b.close()
