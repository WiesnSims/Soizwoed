extends SceneTree
## Renders res://icon.svg to PNGs at every Windows icon size into the folder given after `--`.
## Used by tools/icon/make_icon.py; run: godot --headless -s tools/icon/render_icon.gd -- <out_dir>

const SIZES: PackedInt32Array = [16, 24, 32, 48, 64, 128, 256]
const SOURCE_SIZE: float = 256.0


func _init() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var svg: String = FileAccess.get_file_as_string("res://icon.svg")
	for size: int in SIZES:
		var image: Image = Image.new()
		var error: Error = image.load_svg_from_string(svg, size / SOURCE_SIZE)
		if error != OK:
			printerr("render %d failed: %s" % [size, error_string(error)])
			quit(1)
			return
		image.save_png(out_dir.path_join("icon_%d.png" % size))
	print("rendered %d sizes" % SIZES.size())
	quit(0)
