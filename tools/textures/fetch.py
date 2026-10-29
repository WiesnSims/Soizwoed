"""Downloads the PBR textures of Soizwöd from Poly Haven (CC0) into assets/textures/<name>/.

    python tools/textures/fetch.py              # everything missing
    python tools/textures/fetch.py salt_rock    # only these (re-downloads)

Each texture gets albedo.jpg, normal.jpg (OpenGL convention, what Godot expects), arm.jpg
(AO / roughness / metallic packed, used with ORMMaterial3D) and, where it helps, height.jpg.
Writes the credits table to docs/ASSETS.md. Adapted from Berghittn's tools/textures/build.py."""
import io
import json
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "textures"

# Albedo colour grading: saturation and brightness factors (1 = as photographed).
GRADE = {"salt_rock": (0.42, 0.78), "mandl_coat": (0.0, 1.0), "mandl_hat": (0.0, 1.15), "mandl_beard": (0.0, 1.05)}

# name: (Poly Haven asset, resolution, with height map, what it is for)
TEXTURES = {
    "salt_rock": ("marble_cliff_04", "2k", True, "mine walls and ceiling (rock salt)"),
    "mine_floor": ("forest_ground_04", "2k", True, "mine floor (dirt and gravel)"),
    "timber_bark": ("bark_brown_02", "1k", False, "round timber posts"),
    "timber_wood": ("rough_wood", "1k", False, "beams, sleepers, crates"),
    "rust_iron": ("rust_coarse_01", "1k", False, "rails, iron fittings"),
    "metal_plate": ("metal_plate_02", "1k", False, "lift cage floor"),
    "hub_floor": ("wood_floor_worn", "2k", False, "Gasthaus floor"),
    "hub_logs": ("beam_wall_01", "2k", False, "Gasthaus log walls"),
    "hub_plaster": ("plastered_wall", "1k", False, "Gasthaus plaster"),
    "hub_planks": ("dark_wooden_planks", "1k", False, "Gasthaus counter, tables, panelling"),
    "mandl_coat": ("caban", "1k", False, "Bergmandl coat (wool, tinted brown)"),
    "mandl_hat": ("polar_fleece", "1k", False, "Bergmandl cap (tinted red)"),
    "mandl_beard": ("curly_teddy_natural", "1k", False, "Bergmandl beard"),
    "mandl_leather": ("brown_leather", "1k", False, "Bergmandl belt, boots and bag"),
}
MAPS = {"albedo": "Diffuse", "normal": "nor_gl", "arm": "arm", "height": "Displacement"}


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "soizwoed-textures/1.0"})
    return urllib.request.urlopen(req, timeout=180).read()


def grade(data: bytes, saturation: float, brightness: float) -> bytes:
    rgb = np.asarray(Image.open(io.BytesIO(data)).convert("RGB"), dtype=np.float32) / 255.0
    grey = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    rgb = (grey[..., None] + (rgb - grey[..., None]) * saturation) * brightness
    out = io.BytesIO()
    Image.fromarray((np.clip(rgb, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(out, "JPEG", quality=92)
    return out.getvalue()


def fetch(name: str) -> None:
    asset, res, with_height, _ = TEXTURES[name]
    files = json.loads(get("https://api.polyhaven.com/files/" + asset))
    folder = OUT / name
    folder.mkdir(parents=True, exist_ok=True)
    for ours, theirs in MAPS.items():
        if ours == "height" and not with_height:
            continue
        data = get(files[theirs][res]["jpg"]["url"])
        if ours == "albedo" and name in GRADE:
            data = grade(data, *GRADE[name])
        (folder / f"{ours}.jpg").write_bytes(data)
    print("fetched", name, "from", asset, res)


def credits() -> None:
    lines = ["# Assets", "", "Third-party assets and where they come from.", "",
             "## Textures (Poly Haven, CC0)", "",
             "Fetched by `tools/textures/fetch.py`.", "",
             "| Texture | Used for | Poly Haven asset | Authors |", "|---|---|---|---|"]
    for name, (asset, res, _, use) in TEXTURES.items():
        info = json.loads(get("https://api.polyhaven.com/info/" + asset))
        authors = ", ".join(info.get("authors", {}))
        lines.append(f"| {name} ({res}) | {use} | [{asset}](https://polyhaven.com/a/{asset}) | {authors} |")
    lines += ["", "## Music", "",
              "The Gasthaus waltz (`assets/audio/music/stubenmusi.ogg`) is synthesised by `tools/audio/music.py`"
              " (our own, no third-party material)."]
    (ROOT / "docs" / "ASSETS.md").write_text("\n".join(lines) + "\n", encoding="utf8")


def main(names: list[str]) -> None:
    for name in names or [n for n in TEXTURES if not (OUT / n / "albedo.jpg").exists()]:
        fetch(name)
    credits()


if __name__ == "__main__":
    main(sys.argv[1:])
