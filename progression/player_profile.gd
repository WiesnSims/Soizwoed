class_name PlayerProfile
extends RefCounted
## What a player keeps between runs (DESIGN.md §7): the Ehrenzeichen not yet spent, the
## Knappenbrief perks bought with them, and what they chose to wear and take along. Saved on the
## player's own PC; in co-op every player brings their own. Pure logic plus the file, so it can
## be unit tested with any path.

const DEFAULT_PATH: String = "user://profile.cfg"
const VERSION: int = 1

## Where it is saved; empty: kept in memory only (automated runs never touch the real one).
var path: String = ""
var ehrenzeichen: int = 0
## Every Ehrenzeichen ever earned (spent ones included).
var ehrenzeichen_total: int = 0
## Perk id -> level.
var perks: Dictionary = {}
## The bought gun the kit brings (empty: none).
var start_weapon: StringName = &""
## The hat and the lamp colour worn (perk ids; empty: none / the lamp's own colour).
var hat: StringName = &""
var lamp_colour: StringName = &""
var runs: int = 0
var best_shifts: int = 0


func _init(save_path: String = "") -> void:
	path = save_path


func level(id: StringName) -> int:
	return int(perks.get(id, 0))


func earn(amount: int) -> void:
	ehrenzeichen += maxi(0, amount)
	ehrenzeichen_total += maxi(0, amount)


## Buys the next level of `perk` if there is one and the Ehrenzeichen are there. A start weapon
## or a cosmetic is put to use right away.
func buy(perk: Perk) -> bool:
	var current: int = level(perk.id)
	var price: int = perk.price_after(current)
	if current >= perk.max_level() or price > ehrenzeichen:
		return false
	ehrenzeichen -= price
	perks[perk.id] = current + 1
	if perk.is_choice():
		choose(perk, true)
	return true


## Takes a bought start weapon along / wears a bought cosmetic (`on`), or puts it away.
func choose(perk: Perk, on: bool) -> void:
	if level(perk.id) <= 0:
		return
	match perk.effect:
		Perk.Effect.START_WEAPON:
			start_weapon = perk.id if on else (&"" if start_weapon == perk.id else start_weapon)
		Perk.Effect.HAT:
			hat = perk.id if on else (&"" if hat == perk.id else hat)
		Perk.Effect.LAMP_COLOUR:
			lamp_colour = perk.id if on else (&"" if lamp_colour == perk.id else lamp_colour)


func chosen(perk: Perk) -> bool:
	return perk.id in [start_weapon, hat, lamp_colour]


## A run ended after `shifts` shifts survived.
func finish_run(shifts: int) -> void:
	runs += 1
	best_shifts = maxi(best_shifts, shifts)


## What the other peers need to know of this profile (the host for the kit and the rules,
## everyone for looks and the teammate HUD).
func loadout() -> Dictionary:
	return {"perks": perks.duplicate(), "start_weapon": start_weapon, "hat": hat, "lamp": lamp_colour}


func save() -> Error:
	if path == "":
		return OK
	var file: ConfigFile = ConfigFile.new()
	file.set_value("profile", "version", VERSION)
	file.set_value("profile", "ehrenzeichen", ehrenzeichen)
	file.set_value("profile", "ehrenzeichen_total", ehrenzeichen_total)
	file.set_value("profile", "runs", runs)
	file.set_value("profile", "best_shifts", best_shifts)
	file.set_value("loadout", "start_weapon", String(start_weapon))
	file.set_value("loadout", "hat", String(hat))
	file.set_value("loadout", "lamp_colour", String(lamp_colour))
	for id: StringName in perks:
		file.set_value("perks", String(id), int(perks[id]))
	return file.save(path)


## Reads the profile from `path`; a missing or broken file leaves a fresh one. Perks that no
## longer exist in `known` (perk id -> Perk) are dropped and levels are capped.
func load_from_file(known: Dictionary = {}) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		push_warning("profile: %s could not be read, starting fresh" % path)
		return
	ehrenzeichen = maxi(0, int(file.get_value("profile", "ehrenzeichen", 0)))
	ehrenzeichen_total = maxi(ehrenzeichen, int(file.get_value("profile", "ehrenzeichen_total", 0)))
	runs = maxi(0, int(file.get_value("profile", "runs", 0)))
	best_shifts = maxi(0, int(file.get_value("profile", "best_shifts", 0)))
	perks.clear()
	if file.has_section("perks"):
		for key: String in file.get_section_keys("perks"):
			var id: StringName = StringName(key)
			var value: int = maxi(0, int(file.get_value("perks", key, 0)))
			if not known.is_empty():
				if not known.has(id):
					continue
				value = mini(value, (known[id] as Perk).max_level())
			if value > 0:
				perks[id] = value
	for key: String in ["start_weapon", "hat", "lamp_colour"]:
		var id: StringName = StringName(str(file.get_value("loadout", key, "")))
		if id != &"" and level(id) <= 0:
			id = &""
		set(key, id)
