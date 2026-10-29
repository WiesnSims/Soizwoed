extends Control
## Main menu: solo, host, join, quit. Lies over the Gasthaus in the game scene; the game takes
## over once a session starts. Also applies the --solo/--host/--join command line options
## once at startup, and joins an accepted Steam invite.
##
## With Steam, joining is through the lobby list (public lobbies and friends' lobbies) or a
## Steam invite; with ENet through an address.

const DEFAULT_JOIN_ADDRESS: String = "127.0.0.1"

static var _launch_options_applied: bool = false

@onready var _solo_button: Button = %SoloButton
@onready var _host_button: Button = %HostButton
@onready var _public_check: CheckBox = %PublicCheck
@onready var _join_button: Button = %JoinButton
@onready var _find_button: Button = %FindButton
@onready var _lobby_list: VBoxContainer = %LobbyList
@onready var _quit_button: Button = %QuitButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _status_label: Label = %StatusLabel
@onready var _steam_label: Label = %SteamLabel


func _ready() -> void:
	_solo_button.pressed.connect(_on_solo_pressed)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_find_button.pressed.connect(_on_find_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.invite_pending.connect(_join_pending_invite)
	NetworkManager.lobbies_found.connect(_show_lobbies)
	var steam: bool = NetworkManager.can_find_lobbies()
	_public_check.visible = steam
	_public_check.button_pressed = NetworkManager.options.public_lobby
	_find_button.visible = steam
	_address_edit.get_parent().visible = not steam
	_steam_label.visible = steam
	if steam:
		_steam_label.text = tr("MENU_STEAM_AS") % NetworkManager.local_name()
	_address_edit.text = DEFAULT_JOIN_ADDRESS
	_status_label.text = tr(NetworkManager.last_end_reason)
	NetworkManager.last_end_reason = ""
	if NetworkManager.pending_invite != "":
		_join_pending_invite.call_deferred()
	elif not _launch_options_applied:
		_launch_options_applied = true
		_apply_launch_options.call_deferred()


func _apply_launch_options() -> void:
	var options: NetOptions = NetworkManager.options
	if options.auto_solo:
		_on_solo_pressed()
	elif options.auto_host:
		_on_host_pressed()
	elif options.auto_find:
		_on_find_pressed()
	elif not options.join_target.is_empty():
		_address_edit.text = options.join_target
		_join(options.join_target)


func _on_solo_pressed() -> void:
	NetworkManager.host_solo()


func _on_host_pressed() -> void:
	if NetworkManager.host(_public_check.button_pressed):
		if not NetworkManager.in_session():
			_status_label.text = tr("NET_OPENING")
			_set_buttons_disabled(true)
	else:
		_status_label.text = tr(NetworkManager.last_end_reason)


func _on_join_pressed() -> void:
	_join(_address_edit.text.strip_edges())


func _join(target: String) -> void:
	if NetworkManager.join(target):
		_status_label.text = tr("NET_CONNECTING")
		_set_buttons_disabled(true)
	else:
		_status_label.text = tr(NetworkManager.last_end_reason)


func _join_pending_invite() -> void:
	var target: String = NetworkManager.pending_invite
	NetworkManager.pending_invite = ""
	if target != "":
		_join(target)


func _on_find_pressed() -> void:
	_status_label.text = tr("NET_SEARCHING")
	_show_lobbies([])
	_status_label.text = tr("NET_SEARCHING")
	NetworkManager.find_lobbies()


func _show_lobbies(lobbies: Array) -> void:
	for child: Node in _lobby_list.get_children():
		child.queue_free()
	for lobby: Dictionary in lobbies:
		print("[menu] lobby %s: %s %d/%d%s" % [lobby["target"], lobby["name"], lobby["players"], lobby["max_players"], " (friend)" if lobby["friend"] else ""])
		var button: Button = Button.new()
		var key: String = "MENU_LOBBY_FRIEND" if lobby["friend"] else "MENU_LOBBY"
		button.text = tr(key) % [lobby["name"], lobby["players"], lobby["max_players"]]
		var target: String = lobby["target"]
		button.pressed.connect(func() -> void: _join(target))
		button.disabled = _solo_button.disabled or int(lobby["players"]) >= int(lobby["max_players"])
		_lobby_list.add_child(button)
	if _status_label.text == tr("NET_SEARCHING") or _status_label.text == tr("NET_NO_LOBBIES"):
		_status_label.text = tr("NET_NO_LOBBIES") if lobbies.is_empty() else ""


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_session_ended(reason: String) -> void:
	_status_label.text = tr(reason)
	_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	for button: BaseButton in [_solo_button, _host_button, _join_button, _find_button, _public_check]:
		button.disabled = disabled
	for button: Node in _lobby_list.get_children():
		(button as Button).disabled = disabled
