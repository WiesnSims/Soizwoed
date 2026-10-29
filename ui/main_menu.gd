extends Control
## Main menu: solo, host, join, quit. Lies over the Gasthaus in the game scene; the game takes
## over once a session starts. Also applies the --solo/--host/--join command line options
## once at startup.

const DEFAULT_JOIN_ADDRESS: String = "127.0.0.1"

static var _launch_options_applied: bool = false

@onready var _solo_button: Button = %SoloButton
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _quit_button: Button = %QuitButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_solo_button.pressed.connect(_on_solo_pressed)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	NetworkManager.session_ended.connect(_on_session_ended)
	_address_edit.text = DEFAULT_JOIN_ADDRESS
	_status_label.text = tr(NetworkManager.last_end_reason)
	NetworkManager.last_end_reason = ""
	if not _launch_options_applied:
		_launch_options_applied = true
		_apply_launch_options.call_deferred()


func _apply_launch_options() -> void:
	var options: NetOptions = NetworkManager.options
	if options.auto_solo:
		_on_solo_pressed()
	elif options.auto_host:
		_on_host_pressed()
	elif not options.join_target.is_empty():
		_address_edit.text = options.join_target
		_on_join_pressed()


func _on_solo_pressed() -> void:
	NetworkManager.host_solo()


func _on_host_pressed() -> void:
	if not NetworkManager.host():
		_status_label.text = tr(NetworkManager.last_end_reason)


func _on_join_pressed() -> void:
	if NetworkManager.join(_address_edit.text.strip_edges()):
		_status_label.text = "NET_CONNECTING"
		_set_buttons_disabled(true)
	else:
		_status_label.text = tr(NetworkManager.last_end_reason)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_session_ended(reason: String) -> void:
	_status_label.text = tr(reason)
	_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [_solo_button, _host_button, _join_button]:
		button.disabled = disabled
