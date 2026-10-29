extends GutTest


func test_defaults_to_steam() -> void:
	var options: NetOptions = NetOptions.parse(PackedStringArray())
	assert_eq(options.backend, "steam")
	assert_false(options.auto_host)
	assert_false(options.public_lobby)
	assert_eq(options.join_target, "")
	assert_eq(options.port, NetOptions.DEFAULT_PORT)


func test_headless_defaults_to_enet() -> void:
	assert_eq(NetOptions.parse(PackedStringArray(), PackedStringArray(), true).backend, "enet")
	assert_eq(NetOptions.parse(PackedStringArray(["--net=steam"]), PackedStringArray(), true).backend, "steam")


func test_enet_host() -> void:
	var options: NetOptions = NetOptions.parse(PackedStringArray(["--net=enet", "--host"]))
	assert_eq(options.backend, "enet")
	assert_true(options.auto_host)


func test_enet_join_with_port() -> void:
	var options: NetOptions = NetOptions.parse(PackedStringArray(["--net=ENet", "--join=127.0.0.1", "--port=4000"]))
	assert_eq(options.backend, "enet")
	assert_eq(options.join_target, "127.0.0.1")
	assert_eq(options.port, 4000)


func test_solo() -> void:
	assert_true(NetOptions.parse(PackedStringArray(["--solo"])).auto_solo)


func test_public_lobby_and_lobby_id() -> void:
	var options: NetOptions = NetOptions.parse(PackedStringArray(["--host", "--public", "--lobby=109775241"]))
	assert_true(options.public_lobby)
	assert_eq(options.join_target, "109775241")


func test_steam_invite_launch_argument() -> void:
	var options: NetOptions = NetOptions.parse(PackedStringArray(), PackedStringArray(["--path", ".", "+connect_lobby", "109775241021"]))
	assert_eq(options.join_target, "109775241021")


func test_steam_connect_target_forms() -> void:
	assert_eq(NetOptions.steam_connect_target(PackedStringArray(["+connect_lobby", "42"])), "42")
	assert_eq(NetOptions.steam_connect_target(PackedStringArray(["+connect_lobby 42"])), "42")
	assert_eq(NetOptions.steam_connect_target(PackedStringArray(["+connect_lobby"])), "")
	assert_eq(NetOptions.steam_connect_target(PackedStringArray(["+connect_lobby", "abc"])), "")
	assert_eq(NetOptions.steam_connect_target(PackedStringArray(["42"])), "")
