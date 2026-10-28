extends Control
## Placeholder hub until M1: shows who is here and lets you leave.

const MAIN_MENU_SCENE: String = "res://ui/main_menu.tscn"

@onready var _players_label: Label = %PlayersLabel
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	_leave_button.pressed.connect(_on_leave_pressed)
	NetworkManager.session_ended.connect(_on_session_ended.unbind(1))
	multiplayer.peer_connected.connect(_on_peers_changed.unbind(1))
	multiplayer.peer_disconnected.connect(_on_peers_changed.unbind(1))
	if NetworkManager.is_host() and GameState.run == null:
		GameState.start_run(NetworkManager.player_count())
	_on_peers_changed()


func _on_peers_changed() -> void:
	_players_label.text = tr("HUB_PLAYERS") % NetworkManager.player_count()


func _on_leave_pressed() -> void:
	NetworkManager.leave()
	GameState.end_run()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_session_ended() -> void:
	GameState.end_run()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
