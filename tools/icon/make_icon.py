"""Builds icon.ico (the .exe and window icon) from icon.svg.

Godot renders the SVG at each size (render_icon.gd), Pillow packs them into one .ico.
    python tools/icon/make_icon.py
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIZES = [16, 24, 32, 48, 64, 128, 256]
GODOT = os.environ.get("GODOT", "godot")


def main() -> int:
    with tempfile.TemporaryDirectory() as out_dir:
        subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "tools/icon/render_icon.gd", "--", out_dir],
                       check=True)
        images = [Image.open(os.path.join(out_dir, f"icon_{s}.png")).convert("RGBA") for s in SIZES]
        target = os.path.join(ROOT, "icon.ico")
        images[-1].save(target, format="ICO", sizes=[(s, s) for s in SIZES], append_images=images[:-1])
    print(f"wrote {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
