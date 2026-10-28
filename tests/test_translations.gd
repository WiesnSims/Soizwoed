extends GutTest
## Every translation key in i18n/strings.csv has a German text, and the keys used
## by scenes exist.

const CSV_PATH: String = "res://i18n/strings.csv"
const SCENES: PackedStringArray = ["res://ui/main_menu.tscn", "res://hub/hub.tscn"]


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


func test_translation_server_knows_german() -> void:
	TranslationServer.set_locale("de")
	assert_eq(tr("MENU_QUIT"), "Feierabend")
