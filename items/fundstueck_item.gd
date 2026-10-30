class_name FundstueckItem
extends WorldItem
## The shift's Fundstück (DESIGN.md §2, §5): the one find the company wants. Medium or heavy, so
## whoever carries it has both hands full and cannot shoot. While a boss guards it, it sits in a
## shell of rock salt that only breaks when the boss is dead (`locked`, host decides).
## Picking it up sounds the alarm (Game).

## Still inside its salt shell: nobody can take it.
var locked: bool = false

var _shell: MeshInstance3D


func _ready() -> void:
	super()
	_shell = MeshInstance3D.new()
	_shell.name = "SaltShell"
	var shell_mesh: SphereMesh = SphereMesh.new()
	shell_mesh.radius = 0.55
	shell_mesh.height = 0.95
	shell_mesh.radial_segments = 9
	shell_mesh.rings = 5
	_shell.mesh = shell_mesh
	var crust: StandardMaterial3D = StandardMaterial3D.new()
	crust.albedo_color = Color(0.86, 0.8, 0.74, 0.72)
	crust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crust.roughness = 0.35
	crust.emission_enabled = true
	crust.emission = Color(0.5, 0.35, 0.25)
	crust.emission_energy_multiplier = 0.25
	_shell.material_override = crust
	_shell.position = Vector3.UP * 0.2
	_shell.visible = false
	add_child(_shell)


func interaction_text(player: Player) -> String:
	if locked:
		return tr("PROMPT_FUNDSTUECK_LOCKED")
	return super(player)


## Host: into or out of the salt shell, on every peer.
func host_set_locked(on: bool) -> void:
	_apply_locked.rpc(on)


## Sent to a peer that joins later (it only happens in the hub, but keeps the state whole).
func host_send_state_to(peer: int, place: int) -> void:
	super(peer, place)
	if locked:
		_apply_locked.rpc_id(peer, true)


@rpc("authority", "call_local", "reliable")
func _apply_locked(on: bool) -> void:
	var was: bool = locked
	locked = on
	print("[fundstueck] %s locked %s" % [data.id, on])
	_shell.visible = on
	if was and not on:
		# The shell bursts: a crack and salt dust, then it is gone.
		Audio.play_at("wall_break", global_position, &"SFX", 2.0, 40.0)
		_shell.visible = true
		var tween: Tween = _shell.create_tween()
		tween.tween_property(_shell, "scale", Vector3.ONE * 1.6, 0.35).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_shell, "transparency", 1.0, 0.35)
		tween.tween_callback(_shell.hide)
