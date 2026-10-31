class_name Schiachpercht
extends Percht
## Die Schiachpercht (DESIGN.md §6 bosses, Die Tiefe): the Percht as the guardian of the
## Fundstück – bigger, much tougher, with a great cracked bell on her chest. She keeps to her hall
## until she sees someone; then she fights like a Percht (the charge, the mask as her weak spot)
## and more:
## - the bell: she swings it back (chains rattling, a rising hum – the warning), then strikes it,
##   and the shockwave hurts and throws down everyone close by who has no rock in between;
## - her pack: every so often Grubenhunde come out of the dark for whoever she hunts.
## While she lives the Fundstück stays in its salt shell (Game).

const HOME_RADIUS: float = 8.0

var _home: Vector3
var _shock_left: float = 5.0
var _shock_windup: float = -1.0


func _ready() -> void:
	super()
	_home = global_position
	body.scale = Vector3.ONE * 1.25
	_build_bell()


func _start_health() -> int:
	var run: RunState = GameState.run
	var mult: float = _config.boss_health_mult(run.shift_index if run != null else 0, run.player_count if run != null else 1)
	return maxi(1, roundi(_config.schiachpercht_health * mult * (_config.elite_health_mult if elite else 1.0)))


func _think(delta: float) -> void:
	if _shock_windup >= 0.0:
		_halt(delta)
		_shock_windup += delta
		if _shock_windup >= _config.schiachpercht_shockwave_windup:
			_shock_windup = -1.0
			_shockwave()
		return
	if state == State.HUNT and _target != null and is_instance_valid(_target):
		_shock_left -= delta
		if _shock_left <= 0.0 and _target.global_position.distance_to(global_position) < _config.schiachpercht_shockwave_radius * 1.2:
			_shock_left = _config.schiachpercht_shockwave_seconds
			_shock_windup = 0.0
			net_pose = Pose.WINDUP
			play_sound.rpc("bell_windup", 6.0)
			print("[schiachpercht] swings the bell")
			return
	super(delta)


func boss_fighting() -> bool:
	return state in [State.HUNT, State.WINDUP, State.CHARGE, State.DAZED]


## The bell is struck: everyone close by without rock in between is hurt and thrown down.
func _shockwave() -> void:
	net_pose = Pose.NORMAL
	play_sound.rpc("bell_shock", 10.0)
	var game: Game = Game.instance
	game.host_noise(global_position, _config.noise_bell)
	game._shake_near.rpc(global_position, _config.schiachpercht_shockwave_radius * 2.5)
	var hit: int = 0
	for player: Player in game.players():
		if not player.alive or game.in_mine_cage(player.global_position):
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance > _config.schiachpercht_shockwave_radius or not game.clear_line(global_position + Vector3.UP * 1.5, player.global_position + Vector3.UP):
			continue
		var share: float = 1.0 - 0.5 * distance / _config.schiachpercht_shockwave_radius
		game.host_damage_player(player, scaled_damage(roundi(_config.schiachpercht_shockwave_damage * share)))
		game.host_knock_player(player, global_position, _config.knockdown_push, _config.knockdown_seconds)
		hit += 1
	print("[schiachpercht] bell shockwave, %d thrown down" % hit)


func _roar_seconds() -> float:
	return _config.schiachpercht_dogs_seconds


func _roar() -> void:
	play_sound.rpc("percht_roar", 10.0)
	Game.instance.host_noise(global_position, 35.0)
	_call_dogs(_config.schiachpercht_dogs, _config.schiachpercht_dogs_max)


## Her rounds keep to her hall.
func _patrol_point() -> Vector3:
	return _home + Vector3(randf_range(-HOME_RADIUS, HOME_RADIUS), 0.0, randf_range(-HOME_RADIUS, HOME_RADIUS)) * 0.5


## The great bell on her chest, cracked and green with age.
func _build_bell() -> void:
	var bronze: StandardMaterial3D = BodyParts.rough(Color(0.36, 0.42, 0.3), 0.45, 0.4, 0.2)
	bronze.metallic = 0.8
	var bell: Node3D = Node3D.new()
	bell.name = "Bell"
	bell.position = Vector3(0.0, 1.35, -0.6)
	body.add_child(bell)
	BodyParts.add(bell, BodyParts.cylinder(0.14, 0.32, 0.45, 18), bronze, Vector3.ZERO)
	BodyParts.add(bell, BodyParts.cylinder(0.32, 0.34, 0.05, 18), bronze, Vector3(0.0, -0.23, 0.0))
	BodyParts.add(bell, BodyParts.sphere(0.07, 8), BodyParts.rough(Color(0.15, 0.13, 0.1), 0.6, 0.2), Vector3(0.0, -0.28, 0.0))
	BodyParts.add(bell, BodyParts.box(Vector3(0.02, 0.3, 0.01)), BodyParts.rough(Color(0.05, 0.05, 0.04), 1.0, 0.0), Vector3(0.12, -0.05, -0.2), Vector3(0, 0, 15))  # the crack
	BodyParts.no_shadows(bell)
