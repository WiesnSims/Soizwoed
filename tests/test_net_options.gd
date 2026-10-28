extends GutTest


func test_defaults_to_steam() -> void:
	var options: NetOptions = NetOptions.parse(PackedStringArray())
	assert_eq(options.backend, "steam")
	assert_false(options.auto_host)
	assert_eq(options.join_target, "")
	assert_eq(options.port, NetOptions.DEFAULT_PORT)


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
