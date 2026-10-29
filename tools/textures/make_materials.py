"""Writes one ORMMaterial3D per texture in assets/textures/ to assets/materials/<name>.tres,
and sets the texture import options (VRAM compression, mipmaps, normal maps) in the .import
files Godot made, so exported builds look the same as the editor.

    python tools/textures/make_materials.py
    godot --headless --import          # afterwards, to apply the import options"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "assets" / "textures"
MATERIALS = ROOT / "assets" / "materials"

# name: extra material properties. UVs come from the mesh (the cave mesher uses metres / 3),
# props use uv1_scale. roughness multiplies the texture's roughness.
SETTINGS = {
    "salt_rock": {"roughness": 0.72, "heightmap_scale": 2.5, "normal_scale": 1.4},
    "mine_floor": {"roughness": 0.95, "heightmap_scale": 3.0, "normal_scale": 1.2},
    "timber_bark": {"normal_scale": 1.3, "uv1_scale": "Vector3(2, 3, 1)"},
    "timber_wood": {"triplanar": 0.7},
    "rust_iron": {"metallic": 0.6, "triplanar": 2.0},
    "metal_plate": {"metallic": 0.7, "triplanar": 0.5},
    "hub_floor": {"triplanar": 0.3, "world": True},
    "hub_logs": {"normal_scale": 1.2, "triplanar": 0.3, "world": True},
    "hub_plaster": {"triplanar": 0.4, "world": True},
    "hub_planks": {"triplanar": 0.5},
    "mandl_coat": {"triplanar": 3.0, "albedo_color": "Color(0.62, 0.46, 0.31, 1)"},
    "mandl_hat": {"triplanar": 3.0, "albedo_color": "Color(0.72, 0.1, 0.07, 1)"},
    "mandl_beard": {"triplanar": 4.0, "albedo_color": "Color(0.85, 0.83, 0.8, 1)", "normal_scale": 1.5},
    "mandl_leather": {"triplanar": 3.0},
}


def material(name: str) -> str:
    folder = f"res://assets/textures/{name}"
    opts = SETTINGS.get(name, {})
    has_height = (TEXTURES / name / "height.jpg").exists()
    ext = [("albedo", "Texture2D"), ("normal", "Texture2D"), ("arm", "Texture2D")]
    if has_height:
        ext.append(("height", "Texture2D"))
    lines = ['[gd_resource type="ORMMaterial3D" format=3]', ""]
    for i, (map_name, kind) in enumerate(ext, 1):
        lines.append(f'[ext_resource type="{kind}" path="{folder}/{map_name}.jpg" id="{i}_{map_name}"]')
    lines += ["", "[resource]", f'resource_name = "{name}"']
    if "albedo_color" in opts:
        lines.append(f"albedo_color = {opts['albedo_color']}")
    lines.append('albedo_texture = ExtResource("1_albedo")')
    lines.append('orm_texture = ExtResource("3_arm")')
    lines.append(f"roughness = {opts.get('roughness', 1.0)}")
    lines.append(f"metallic = {opts.get('metallic', 1.0)}")
    lines.append("normal_enabled = true")
    lines.append(f"normal_scale = {opts.get('normal_scale', 1.0)}")
    lines.append('normal_texture = ExtResource("2_normal")')
    if has_height:
        lines.append("heightmap_enabled = true")
        lines.append(f"heightmap_scale = {opts.get('heightmap_scale', 3.0)}")
        lines.append("heightmap_deep_parallax = true")
        lines.append("heightmap_min_layers = 8")
        lines.append("heightmap_max_layers = 24")
        lines.append('heightmap_texture = ExtResource("4_height")')
    if "triplanar" in opts:
        # Boxes and other primitives: triplanar so long beams are not stretched.
        scale = opts["triplanar"]
        lines.append("uv1_triplanar = true")
        lines.append("uv1_triplanar_sharpness = 4.0")
        lines.append(f"uv1_scale = Vector3({scale}, {scale}, {scale})")
        if opts.get("world"):
            lines.append("uv1_world_triplanar = true")
    elif "uv1_scale" in opts:
        lines.append(f"uv1_scale = {opts['uv1_scale']}")
    lines.append("texture_filter = 5")
    return "\n".join(lines) + "\n"


def set_import_options(path: Path, normal: bool) -> None:
    """VRAM compressed (BC on desktop), mipmaps, and normal-map mode where needed."""
    text = path.read_text(encoding="utf8")
    options = {"compress/mode": "2", "mipmaps/generate": "true", "compress/normal_map": "1" if normal else "2",
               "detect_3d/compress_to": "0"}
    for key, value in options.items():
        text, n = re.subn(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, flags=re.M)
        if n == 0:
            text = text.replace("[params]\n", f"[params]\n\n{key}={value}\n", 1)
    path.write_text(text, encoding="utf8")


def main() -> None:
    MATERIALS.mkdir(parents=True, exist_ok=True)
    for folder in sorted(p for p in TEXTURES.iterdir() if p.is_dir()):
        (MATERIALS / f"{folder.name}.tres").write_text(material(folder.name), encoding="utf8")
        for image in folder.glob("*.jpg"):
            imp = image.with_suffix(".jpg.import")
            if imp.exists():
                set_import_options(imp, image.stem == "normal")
        print("material", folder.name)


if __name__ == "__main__":
    main()
