extends GutTest
## Solo must be a host session with zero clients (same code path as multiplayer).


func after_each() -> void:
	NetworkManager.leave()


func test_solo_is_host_with_one_player() -> void:
	watch_signals(NetworkManager)
	NetworkManager.host_solo()
	assert_signal_emitted(NetworkManager, "session_started")
	assert_true(NetworkManager.is_host())
	assert_true(multiplayer.is_server())
	assert_eq(NetworkManager.player_count(), 1)


func test_leave_ends_session() -> void:
	NetworkManager.host_solo()
	NetworkManager.leave()
	assert_false(NetworkManager.in_session())
	assert_eq(NetworkManager.player_count(), 0)


func test_version_comes_from_project_settings() -> void:
	assert_eq(NetworkManager.game_version(), ProjectSettings.get_setting("application/config/version"))
