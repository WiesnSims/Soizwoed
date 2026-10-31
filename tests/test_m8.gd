extends GutTest
## M8: the new guns and ammo as data, elites, the new ammo types in caps and Notration, the
## bosses on the sections, and the creatures' armour and weak spots in balance.tres.

var config: BalanceConfig


func before_each() -> void:
	config = load("res://balance.tres") as BalanceConfig


func test_stutzen_is_a_bolt_action() -> void:
	var stutzen: ItemData = load("res://items/data/mannlicher_stutzen.tres") as ItemData
	var pistol: ItemData = load("res://items/data/dienstpistole.tres") as ItemData
	assert_eq(stutzen.weapon.ammo_type, &"gewehr")
	assert_eq(stutzen.weapon.magazine, 5)
	assert_true(stutzen.weapon.reload_per_round and stutzen.weapon.top_loaded, "loaded round by round from above")
	assert_ne(stutzen.weapon.cycle_sound, "", "the bolt is worked after each shot")
	assert_gt(stutzen.weapon.damage, pistol.weapon.damage * 4, "for elites and bosses")
	assert_lt(stutzen.weapon.spread_ads, pistol.weapon.spread_ads)
	assert_eq(stutzen.slot_kind(), ItemData.SlotKind.WEAPON)


func test_leuchtpistole_fires_flares() -> void:
	var gun: ItemData = load("res://items/data/leuchtpistole.tres") as ItemData
	assert_true(gun.weapon.projectile)
	assert_eq(gun.weapon.ammo_type, &"leucht")
	assert_eq(gun.weapon.magazine, 1)
	assert_gte(config.flare_light_seconds, 15.0, "lights an area for about 20 s (DESIGN.md §7)")


func test_dynamit_is_thrown_from_slot_4() -> void:
	var dynamit: ItemData = load("res://items/data/dynamit.tres") as ItemData
	assert_eq(dynamit.slot_kind(), ItemData.SlotKind.THROWABLE)
	assert_gt(config.dynamit_damage, config.boeller_damage * 3)
	assert_gt(config.dynamit_radius, config.boeller_radius)


func test_new_ammo_has_caps_and_boxes() -> void:
	assert_eq(config.ammo_cap(&"gewehr"), config.ammo_cap_gewehr)
	assert_eq(config.ammo_cap(&"leucht"), config.ammo_cap_leucht)
	assert_eq(config.ammo_cap(&"gewehr", {&"cap_gewehr": 2}), config.ammo_cap_gewehr + 20)
	for id: String in ["gewehrpatronen", "leuchtkugeln"]:
		var box: ItemData = load("res://items/data/%s.tres" % id) as ItemData
		assert_eq(box.kind, ItemData.Kind.AMMO)
		assert_gt(box.ammo_amount, 0)
	var catalog: ItemCatalog = load("res://items/item_catalog.tres") as ItemCatalog
	for id: StringName in [&"mannlicher_stutzen", &"leuchtpistole", &"dynamit", &"gewehrpatronen", &"leuchtkugeln"]:
		assert_not_null(catalog.by_id(id), "%s is in the catalog" % id)
		assert_gt(catalog.by_id(id).price, 0, "%s is sold" % id)


func test_flares_never_block_notration() -> void:
	# A miner with a flare gun full of flares but no rounds for anything else counts as out.
	assert_true(config.notration_due({&"pistole": 2, &"leucht": 4}))
	assert_false(config.notration_due({&"pistole": 2, &"gewehr": 6}))
	assert_eq(config.notration_rounds(&"gewehr"), config.notration_gewehr)


func test_elites_from_shift_5() -> void:
	assert_eq(config.elite_chance(0), 0.0)
	assert_eq(config.elite_chance(config.elite_first_shift - 1), 0.0)
	assert_eq(config.elite_first_shift, 4, "shift 5 is index 4 (DESIGN.md §6)")
	assert_gt(config.elite_chance(config.elite_first_shift), 0.0)
	assert_gt(config.elite_chance(config.elite_first_shift + 3), config.elite_chance(config.elite_first_shift))
	assert_almost_eq(config.elite_chance(60), config.elite_chance_max, 0.0001)
	assert_gt(config.elite_health_mult, 1.0)
	assert_gt(config.elite_speed_mult, 1.0)


func test_armour_and_weak_spots() -> void:
	assert_gt(config.percht_mask_mult, 1.0)
	assert_lt(config.percht_armour_mult, 1.0)
	assert_gt(config.tatzelwurm_throat_mult, 1.0)
	assert_lt(config.tatzelwurm_scale_mult, 1.0)
	assert_gt(config.seemuada_head_mult, 1.0)
	assert_gt(config.weak_spot_mult, 1.0)


func test_each_section_has_its_boss() -> void:
	var bosses: Dictionary = {
		"res://world/chunks/oberer_stollen/oberer_stollen.tres": &"bergkini",
		"res://world/chunks/salzsee/salzsee.tres": &"seemuada",
		"res://world/chunks/die_tiefe/die_tiefe.tres": &"schiachpercht",
	}
	for path: String in bosses:
		assert_eq((load(path) as ChunkSet).boss, bosses[path], path)
	for id: String in ["seemuada", "schiachpercht"]:
		var data: EnemyData = load("res://enemies/bosses/%s/%s.tres" % [id, id]) as EnemyData
		assert_eq(data.id, StringName(id))
		assert_not_null(data.scene)


func test_hud_shows_each_ammo() -> void:
	assert_eq(HudIcon.ammo_kind(&"pistole"), HudIcon.Kind.BULLET)
	assert_eq(HudIcon.ammo_kind(&"schrot"), HudIcon.Kind.SHELL)
	assert_eq(HudIcon.ammo_kind(&"gewehr"), HudIcon.Kind.RIFLE)
	assert_eq(HudIcon.ammo_kind(&"leucht"), HudIcon.Kind.FLARE)
