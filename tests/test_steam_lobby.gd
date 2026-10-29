extends GutTest
## Lobby metadata rules (App ID 480 is shared): every lobby carries game and version, and only
## lobbies of this game and version may be joined. Pure logic, no Steam needed.


func _metadata(version: String) -> Dictionary:
	var data: Dictionary = {}
	for entry: Array in SteamBackend.lobby_metadata(version, "Sepp"):
		data[entry[0]] = entry[1]
	return data


func test_metadata_has_game_version_and_name() -> void:
	var data: Dictionary = _metadata("0.3.0")
	assert_eq(data[SteamBackend.KEY_GAME], "soizwoed")
	assert_eq(data[SteamBackend.KEY_VERSION], "0.3.0")
	assert_eq(data[SteamBackend.KEY_NAME], "Sepp")


func test_own_lobby_is_fine() -> void:
	assert_eq(SteamBackend.lobby_problem(_metadata("0.3.0"), "0.3.0"), "")


func test_other_version_is_refused() -> void:
	assert_eq(SteamBackend.lobby_problem(_metadata("0.2.9"), "0.3.0"), "NET_WRONG_VERSION")


func test_other_game_is_refused() -> void:
	assert_eq(SteamBackend.lobby_problem({"game": "spacewar", "ver": "0.3.0"}, "0.3.0"), "NET_NOT_SOIZWOED")
	assert_eq(SteamBackend.lobby_problem({}, "0.3.0"), "NET_NOT_SOIZWOED")


func test_refusal_reasons_are_translated() -> void:
	for key: String in ["NET_WRONG_VERSION", "NET_NOT_SOIZWOED", "NET_LOBBY_FULL", "NET_JOINING_INVITE"]:
		assert_ne(tr(key), key, "no text for %s" % key)
