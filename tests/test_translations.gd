extends GutTest
## Every translation key in i18n/strings.csv has a German and an English text, and the keys
## used by scenes and code exist.

const CSV_PATH: String = "res://i18n/strings.csv"
const SCENES: PackedStringArray = ["res://ui/main_menu.tscn", "res://game/game.tscn"]


func _csv_rows() -> Dictionary:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	assert_eq(header[0], "keys")
	assert_true(header.has("de"))
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2 and not row[0].is_empty():
			rows[row[0]] = row[header.find("de")]
	return rows


func test_every_key_has_english_text() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	var en: int = header.find("en")
	assert_gt(en, 0, "no English column")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2 and not row[0].is_empty():
			assert_true(row.size() > en and not row[en].is_empty(), "missing English text for %s" % row[0])


func test_every_input_action_has_a_name() -> void:
	var rows: Dictionary = _csv_rows()
	for action: StringName in SettingsData.REBINDABLE:
		assert_true(rows.has("ACTION_" + String(action).to_upper()), "no name for %s" % action)
		assert_true(InputMap.has_action(action), "%s is not an input action" % action)


func test_placeholders_match_between_languages() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	var de: int = header.find("de")
	var en: int = header.find("en")
	var placeholder: RegEx = RegEx.create_from_string("%[ds]")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > en and not row[0].is_empty():
			var german: Array = placeholder.search_all(row[de]).map(func(m: RegExMatch) -> String: return m.get_string())
			var english: Array = placeholder.search_all(row[en]).map(func(m: RegExMatch) -> String: return m.get_string())
			assert_eq(english, german, "placeholders of %s differ" % row[0])


func test_every_key_has_german_text() -> void:
	var rows: Dictionary = _csv_rows()
	assert_gt(rows.size(), 0)
	for key: String in rows:
		assert_false(str(rows[key]).is_empty(), "missing German text for %s" % key)


func test_scene_texts_are_known_keys() -> void:
	var rows: Dictionary = _csv_rows()
	var key_pattern: RegEx = RegEx.create_from_string("(?:text|placeholder_text) = \"([A-Z0-9_]+)\"")
	for path: String in SCENES:
		var source: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in key_pattern.search_all(source):
			assert_true(rows.has(found.get_string(1)), "%s uses unknown key %s" % [path, found.get_string(1)])


func test_translation_server_knows_german_and_english() -> void:
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(tr("MENU_QUIT"), "Clock off")
	TranslationServer.set_locale("de")
	assert_eq(tr("MENU_QUIT"), "Feierabend")
	TranslationServer.set_locale(before)


func test_code_texts_are_known_keys() -> void:
	var rows: Dictionary = _csv_rows()
	var key_pattern: RegEx = RegEx.create_from_string(r'tr\("([A-Z0-9_]+)"\)')
	for dir: String in ["res://game", "res://hub", "res://ui", "res://player", "res://items", "res://world", "res://enemies"]:
		for path: String in _scripts_in(dir):
			var source: String = FileAccess.get_file_as_string(path)
			for found: RegExMatch in key_pattern.search_all(source):
				assert_true(rows.has(found.get_string(1)), "%s uses unknown key %s" % [path, found.get_string(1)])


func test_data_name_keys_are_known() -> void:
	var rows: Dictionary = _csv_rows()
	var catalog: ItemCatalog = load("res://items/item_catalog.tres")
	for item: Resource in catalog.items:
		var data: ItemData = item as ItemData
		assert_true(rows.has(data.name_key), "missing %s" % data.name_key)
		if data.price > 0:
			assert_true(rows.has(data.name_key + "_DESC"), "missing %s_DESC" % data.name_key)


func _scripts_in(dir: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			result.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		result.append_array(_scripts_in(dir.path_join(sub)))
	return result
