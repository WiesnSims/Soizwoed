extends GutTest
## M10: impacts by surface, the boss stings, every sound the data names, Da Bergkini's weak spot,
## the cheat gate and the retuned curves.

const BOSSES: PackedStringArray = ["res://enemies/bosses/bergkini/bergkini.tres",
		"res://enemies/bosses/seemuada/seemuada.tres", "res://enemies/bosses/schiachpercht/schiachpercht.tres"]

var config: BalanceConfig


func before_each() -> void:
	config = load("res://balance.tres") as BalanceConfig


func test_surfaces_from_material_names() -> void:
	assert_eq(ImpactFx.surface_from_name("res://assets/materials/timber_wood.tres"), ImpactFx.Surface.WOOD)
	assert_eq(ImpactFx.surface_from_name("res://assets/materials/hub_planks.tres"), ImpactFx.Surface.WOOD)
	assert_eq(ImpactFx.surface_from_name("res://assets/materials/rust_iron.tres"), ImpactFx.Surface.METAL)
	assert_eq(ImpactFx.surface_from_name("res://assets/materials/metal_plate.tres"), ImpactFx.Surface.METAL)
	assert_eq(ImpactFx.surface_from_name("res://assets/materials/salt_rock.tres"), ImpactFx.Surface.ROCK)
	assert_eq(ImpactFx.surface_from_name(""), ImpactFx.Surface.ROCK)


func test_surface_meta_and_meshes() -> void:
	var tagged: StaticBody3D = autofree(StaticBody3D.new())
	tagged.set_meta(&"surface", "metal")
	assert_eq(ImpactFx.surface_of(tagged), ImpactFx.Surface.METAL)
	var timber: StaticBody3D = autofree(StaticBody3D.new())
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = load("res://assets/materials/timber_wood.tres")
	timber.add_child(mesh)
	assert_eq(ImpactFx.surface_of(timber), ImpactFx.Surface.WOOD)
	assert_eq(ImpactFx.surface_of(null), ImpactFx.Surface.ROCK)


func test_mark_pictures() -> void:
	for kind: StringName in [&"hole_rock", &"hole_wood", &"dent", &"splat", &"pool", &"puff"]:
		var image: Image = ImpactFx.draw_mark(kind, 32)
		assert_eq(image.get_width(), 32)
		var centre: float = image.get_pixel(16, 16).a
		var corner: float = image.get_pixel(0, 0).a
		assert_gt(centre, 0.4, "%s is solid in the middle" % kind)
		assert_lt(corner, 0.1, "%s fades out to the corners" % kind)


func test_impact_sounds_exist() -> void:
	for sound: String in ImpactFx.SOUNDS:
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s_1.ogg" % sound), sound)
	assert_true(ResourceLoader.exists("res://assets/audio/sfx/hole_burst_1.ogg"))
	assert_true(ResourceLoader.exists("res://assets/audio/sfx/weapon_draw_1.ogg"))


func test_every_boss_has_a_sting() -> void:
	for path: String in BOSSES:
		var data: EnemyData = load(path) as EnemyData
		assert_ne(data.sting, "", "%s has a sting" % data.id)
		assert_true(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % data.sting), data.sting)
	assert_true(ResourceLoader.exists("res://assets/audio/music/sting_boss_down.ogg"))


func test_every_weapon_sound_exists() -> void:
	var catalog: ItemCatalog = load("res://items/item_catalog.tres") as ItemCatalog
	var checked: int = 0
	for entry: Resource in catalog.items:
		var weapon: WeaponData = (entry as ItemData).weapon
		if weapon == null:
			continue
		for sound: String in [weapon.sound, weapon.reload_sound, weapon.reload_sound_late, weapon.reload_open_sound,
				weapon.reload_close_sound, weapon.dry_sound, weapon.cycle_sound, weapon.rack_sound]:
			if sound == "":
				continue
			checked += 1
			assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % sound) or ResourceLoader.exists("res://assets/audio/sfx/%s_1.ogg" % sound),
					"%s: %s" % [entry.id, sound])
	assert_gt(checked, 15)


func test_leuchtpistole_has_its_own_reload() -> void:
	var gun: WeaponData = (load("res://items/data/leuchtpistole.tres") as ItemData).weapon
	var flinte: WeaponData = (load("res://items/data/salzschrot_flinte.tres") as ItemData).weapon
	assert_ne(gun.reload_sound, flinte.reload_sound)
	assert_ne(gun.reload_open_sound, flinte.reload_open_sound)
	assert_eq((load("res://items/data/dienstpistole.tres") as ItemData).weapon.rack_sound, "slide_rack")


func test_every_creature_that_bleeds_leaves_a_pool() -> void:
	assert_gt((load("res://enemies/grubenhund/grubenhund.tres") as EnemyData).blood_pool, 0.0)
	assert_gt((load("res://enemies/percht/percht.tres") as EnemyData).blood_pool, 1.0)
	assert_eq((load("res://enemies/salzweibl/salzweibl.tres") as EnemyData).blood_pool, 0.0, "salt does not bleed")


func test_bergkini_has_a_weak_spot() -> void:
	assert_gt(config.bergkini_head_mult, 1.0)


func test_cheat_only_where_allowed() -> void:
	# Tests run in a debug build (the editor binary), where the cheat is allowed.
	assert_true(Game.cheats_allowed())
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(presets.contains("custom_features=\"%s\"" % Game.CHEAT_FEATURE), "playtest builds keep the cheat until release")


## The M10 curves: a shift's found ammo covers its creatures early on and gets scarce, never
## below the floor; the way back stays tight but possible (test_balance checks the margin).
func test_ammo_gets_scarce_but_not_too_scarce() -> void:
	for players: int in [1, 4]:
		assert_eq(config.ammo_box_count(30, players), config.ammo_box_count(40, players), "the scarcity has a floor")
		assert_gte(float(config.ammo_box_count(30, players)), config.ammo_boxes_per_player * players * config.by_players(config.ammo_found_by_players, players) * config.ammo_scarcity_min - 1.0)
	assert_almost_eq(config.enemy_health_mult(4, 10), 1.4, 0.001)
	assert_between(config.rueckweg_seconds(0, 1, 105.0), 210.0, 270.0, "about four minutes solo in the first shift")
