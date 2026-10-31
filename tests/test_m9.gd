extends GutTest
## M9: the saved profile, the Knappenbrief perks, the new run upgrades and the Überstunden.

const TEST_PATH: String = "user://test_profile.cfg"

var config: BalanceConfig


func before_each() -> void:
	config = load("res://balance.tres") as BalanceConfig


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_every_perk_is_complete() -> void:
	assert_gt(config.perks.size(), 8)
	var ids: Dictionary = {}
	for perk: Perk in config.perks:
		assert_false(ids.has(perk.id), "perk ids are unique: %s" % perk.id)
		ids[perk.id] = true
		assert_gt(perk.max_level(), 0, "%s has a price" % perk.id)
		assert_true(perk.name_key.begins_with("PERK_"), "%s has a name key" % perk.id)
		for price: int in perk.prices:
			assert_gt(price, 0)
		if perk.is_choice():
			assert_eq(perk.max_level(), 1, "%s is bought once" % perk.id)
	for effect: Perk.Effect in Perk.Effect.values():
		assert_gt(config.perks.filter(func(p: Perk) -> bool: return p.effect == effect).size(), 0, "a perk for every effect")


func test_start_weapons_are_guns() -> void:
	var catalog: ItemCatalog = load("res://items/item_catalog.tres") as ItemCatalog
	for perk: Perk in config.perks:
		if perk.effect == Perk.Effect.START_WEAPON:
			var data: ItemData = catalog.by_id(perk.target)
			assert_not_null(data, "%s brings an item" % perk.id)
			assert_not_null(data.weapon, "%s brings a gun" % perk.id)
		if perk.effect == Perk.Effect.LAMP_COLOUR:
			assert_true(config.lamp_colours.has(perk.target), "%s has a colour" % perk.id)


func test_buying_perks_spends_ehrenzeichen() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	var gsund: Perk = config.perk(&"gsund")
	assert_false(profile.buy(gsund), "nothing to spend")
	profile.earn(5)
	assert_true(profile.buy(gsund))
	assert_eq(profile.ehrenzeichen, 5 - gsund.prices[0])
	assert_eq(profile.level(&"gsund"), 1)
	assert_eq(profile.ehrenzeichen_total, 5, "spending keeps the total")
	assert_eq(config.max_health(profile.perks), config.player_max_health + 10)


func test_perks_stop_at_their_highest_level() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.earn(1000)
	var gsund: Perk = config.perk(&"gsund")
	for i: int in gsund.max_level():
		assert_true(profile.buy(gsund))
	assert_false(profile.buy(gsund))
	assert_eq(config.max_health(profile.perks), config.player_max_health + 50, "+10 max health ×5 (DESIGN §7)")


func test_choices_are_worn_when_bought_and_can_be_taken_off() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.earn(100)
	var flinte: Perk = config.perk(&"eigene_flinte")
	var stutzen: Perk = config.perk(&"eigener_stutzen")
	profile.choose(flinte, true)
	assert_eq(profile.start_weapon, &"", "not bought: cannot be chosen")
	assert_true(profile.buy(flinte))
	assert_eq(profile.start_weapon, &"eigene_flinte")
	assert_true(profile.buy(stutzen))
	assert_eq(profile.start_weapon, &"eigener_stutzen", "one start weapon at a time")
	profile.choose(flinte, true)
	assert_true(profile.chosen(flinte))
	assert_false(profile.chosen(stutzen))
	profile.choose(flinte, false)
	assert_eq(profile.start_weapon, &"")
	assert_eq(config.start_weapon_item(&"eigene_flinte", profile.perks), &"salzschrot_flinte")
	assert_eq(config.start_weapon_item(&"eigene_flinte", {}), &"", "not bought")


func test_profile_saves_and_loads() -> void:
	var profile: PlayerProfile = PlayerProfile.new(TEST_PATH)
	profile.earn(40)
	profile.buy(config.perk(&"gsund"))
	profile.buy(config.perk(&"hut_gamsbart"))
	profile.finish_run(4)
	assert_eq(profile.save(), OK)
	var again: PlayerProfile = PlayerProfile.new(TEST_PATH)
	again.load_from_file(config.perks_by_id())
	assert_eq(again.ehrenzeichen, profile.ehrenzeichen)
	assert_eq(again.ehrenzeichen_total, 40)
	assert_eq(again.level(&"gsund"), 1)
	assert_eq(again.hat, &"hut_gamsbart")
	assert_eq(again.best_shifts, 4)
	assert_eq(again.runs, 1)


func test_loading_drops_unknown_perks_and_caps_levels() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("profile", "ehrenzeichen", 7)
	file.set_value("perks", "gsund", 99)
	file.set_value("perks", "gibts_ned", 2)
	file.set_value("loadout", "hat", "hut_knappe")  # not bought
	file.save(TEST_PATH)
	var profile: PlayerProfile = PlayerProfile.new(TEST_PATH)
	profile.load_from_file(config.perks_by_id())
	assert_eq(profile.level(&"gsund"), config.perk(&"gsund").max_level())
	assert_false(profile.perks.has(&"gibts_ned"))
	assert_eq(profile.hat, &"")
	assert_eq(profile.ehrenzeichen_total, 7, "the total is never below what is left")


func test_memory_profile_never_writes() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.earn(3)
	assert_eq(profile.save(), OK)
	assert_false(FileAccess.file_exists(PlayerProfile.DEFAULT_PATH + ".nope"))


func test_perk_numbers() -> void:
	var levels: Dictionary = {&"munition_pistole": 2, &"munition_schrot": 1, &"sanitaeter": 2, &"lederweste": 1}
	assert_eq(config.kit_ammo(&"pistole", {}), config.ration_pistole)
	assert_eq(config.kit_ammo(&"pistole", levels), config.ration_pistole + 16)
	assert_eq(config.kit_ammo(&"schrot", levels), 4)
	assert_eq(config.kit_ammo(&"gewehr", levels), 0)
	assert_almost_eq(config.help_up_time(levels), config.help_up_seconds * 0.6, 0.001)
	assert_eq(roundi(config.perk_total(Perk.Effect.START_ARMOUR, levels)), 15)


func test_new_run_upgrades() -> void:
	assert_eq(config.lamp_fuel_mult({}), 1.0)
	assert_almost_eq(config.lamp_fuel_mult({&"batterie": 2}), 1.6, 0.001)
	assert_false(config.crew_pocket_slot({}))
	assert_true(config.crew_pocket_slot({&"rucksack": 1}))
	var catalog: ItemCatalog = load("res://items/item_catalog.tres") as ItemCatalog
	var stutzen: ItemData = catalog.by_id(&"mannlicher_stutzen")
	var better: WeaponData = RunUpgrade.upgraded_weapon(stutzen.weapon, stutzen.id, config.run_upgrades, {&"stutzen_spread": 1})
	assert_lt(better.spread_hip, stutzen.weapon.spread_hip)


func test_start_money_once_per_miner() -> void:
	var run: RunState = RunState.new(config, 2)
	assert_true(run.bring_money("Sime", 200))
	assert_false(run.bring_money("Sime", 200), "rejoining brings nothing")
	assert_true(run.bring_money("Kumpl", 100))
	assert_false(run.bring_money("Nix", 0))
	assert_eq(run.money, 300)
	assert_eq(run.score().money, 0, "brought money is not earned")


func test_overtime_starts_after_shift_nine_and_stacks() -> void:
	var run: RunState = RunState.new(config, 4)
	run.rng.seed = 7
	for i: int in config.overtime_first_shift - 1:
		run.finish_shift(0, true)
	assert_true(run.overtime.is_empty(), "no overtime through shift 9")
	run.finish_shift(0, true)
	assert_eq(run.shift_index, config.overtime_first_shift)
	assert_eq(run.overtime.size(), 1, "shift 10 is an Überstund")
	run.finish_shift(0, true)
	assert_eq(run.overtime.size(), 2, "they stack")
	assert_ne(run.overtime[0], run.overtime[1], "no modifier twice")
	for i: int in 20:
		run.finish_shift(0, true)
	assert_eq(run.overtime.size(), config.overtime_kinds.size(), "until all are in force")


func test_extra_slots_are_in_the_layout() -> void:
	var kinds: PackedInt32Array = Inventory.layout(config)
	assert_eq(kinds.size(), config.weapon_slots + config.throwable_slots + config.item_slots + config.extra_slots)


func test_locked_slots_take_nothing() -> void:
	var inventory: Inventory = Inventory.new(Inventory.layout(config))
	var first_extra: int = inventory.slots.size() - config.extra_slots
	inventory.set_open_slots(first_extra)
	for i: int in config.item_slots + 2:
		inventory.add(RefCounted.new(), ItemData.WeightClass.LIGHT)
	assert_eq(inventory.free_slot(ItemData.SlotKind.ITEM), Inventory.NONE)
	assert_null(inventory.slots[first_extra], "the locked pocket stays empty")
	inventory.set_open_slots(first_extra + 1)
	assert_eq(inventory.free_slot(ItemData.SlotKind.ITEM), first_extra, "the Grubentaschn opens it")
	inventory.select(first_extra + 1)
	assert_ne(inventory.selected, first_extra + 1, "a locked slot cannot be selected")
