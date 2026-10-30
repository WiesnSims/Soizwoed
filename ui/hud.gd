class_name Hud
extends CanvasLayer
## Everything on screen during the game: crosshair, interaction prompt, inventory slots, bars
## (health, stamina, carbide), pocket watch, messages, fades, and the panels (shop, shift
## results, pause). While dead it only says whom you are watching. Built in code; all texts go
## through tr().

signal leave_requested

const TEXT_COLOR: Color = Color(0.96, 0.9, 0.78)
const DIM_COLOR: Color = Color(0.7, 0.64, 0.55)
const PANEL_COLOR: Color = Color(0.08, 0.06, 0.04, 0.88)
const ACCENT: Color = Color(0.86, 0.62, 0.3)

var _root: Control
var _crosshair: ColorRect
var _prompt: Label
var _hold_bar: ProgressBar
var _message: Label
var _message_tween: Tween
var _run_label: Label
var _hands_label: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _lamp_bar: ProgressBar
var _watch: Label
var _spectate_label: Label
## "Redst" while your voice goes out (Steam voice chat).
var _mic_label: Label
## Shown only while the local player is alive.
var _alive_nodes: Array[Control] = []
var _fade: ColorRect
var _fade_tween: Tween
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _panel_kind: String = ""
var _run_info: Dictionary = {}
var _settings: SettingsPanel


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_center()
	_build_bottom()
	_build_top()
	_build_panel()
	_settings = SettingsPanel.new()
	_settings.closed.connect(_on_settings_closed)
	_root.add_child(_settings)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_root.add_child(_fade)
	_root.hide()


func _process(_delta: float) -> void:
	var game: Game = Game.instance
	var player: Player = game.local_player() if game != null else null
	_root.visible = player != null
	if player == null:
		return
	for node: Control in _alive_nodes:
		node.visible = player.alive
	_spectate_label.visible = not player.alive
	_mic_label.visible = player.voice_chat != null and player.voice_chat.talking
	if not player.alive:
		var target: Player = player.spectating
		_spectate_label.text = tr("HUD_SPECTATING") % [target.display_name(), Settings.key_label(&"use")] if target != null and is_instance_valid(target) else tr("HUD_DEAD")
		_prompt.visible = false
		_hold_bar.visible = false
		_watch.visible = false
		return
	_update_prompt(player)
	_update_slots(player)
	_health_bar.value = float(player.health) / Balance.config.player_max_health
	_stamina_bar.value = player.stamina
	_stamina_bar.modulate.a = 0.0 if player.stamina >= 0.999 else 1.0
	_lamp_bar.value = player.lamp_share()
	var in_hub: bool = player.global_position.y > Game.HUB_FLOOR_ABOVE
	_run_label.visible = in_hub and not _run_info.is_empty()
	_watch.visible = Input.is_action_pressed(&"watch") and not modal_open()
	if _watch.visible:
		_watch.text = "%s\n%s" % [tr("HUD_WATCH"), game.clock_text()]


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or Game.instance == null or Game.instance.local_player() == null:
		return
	get_viewport().set_input_as_handled()
	if _settings.visible:
		_settings.close()
	elif modal_open():
		if _panel_kind != "over":
			close_panels()
	else:
		_open_pause()


# --- public ----------------------------------------------------------------------------------------

func show_message(text: String, seconds: float = 2.5) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.8)


func fade_out(seconds: float) -> void:
	_fade_to(1.0, seconds)


func fade_in(seconds: float) -> void:
	_fade_to(0.0, seconds)


func update_run(info: Dictionary) -> void:
	_run_info = info
	_run_label.text = "%s\n%s" % [tr("HUD_MONEY") % int(info.money), tr("HUD_QUOTA") % [int(info.quota), int(info.shifts_left)]]
	if int(info.get("players", 1)) > 1:
		_run_label.text += "\n" + tr("HUD_CREW") % int(info.players)
	if _panel_kind == "shop":
		open_shop()
	elif _panel_kind == "sections":
		open_sections()


func modal_open() -> bool:
	return _panel.visible or _settings.visible


func close_panels() -> void:
	_panel.hide()
	_settings.hide()
	_panel_kind = ""
	_apply_modal()


func open_shop() -> void:
	_start_panel("shop", tr("SHOP_TITLE"))
	_add_text(tr("SHOP_MONEY") % int(_run_info.get("money", 0)), ACCENT)
	var money: int = int(_run_info.get("money", 0))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_panel_box.add_child(scroll)
	for data: ItemData in Game.instance.catalog.shop():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var name_label: Label = _label("%s\n%s" % [tr(data.name_key), tr(data.name_key + "_DESC")], 17)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var buy: Button = Button.new()
		buy.text = tr("SHOP_BUY") % data.price
		buy.custom_minimum_size = Vector2(150, 0)
		buy.disabled = data.price > money
		buy.pressed.connect(_on_buy_pressed.bind(data.id))
		row.add_child(buy)
		list.add_child(row)
	_add_button(tr("PANEL_CLOSE"), close_panels)
	_apply_modal()


## The Grubnplan: pick the mine section for the next shift (later ones unlock with the cycles).
func open_sections() -> void:
	_start_panel("sections", tr("PLAN_TITLE"))
	var game: Game = Game.instance
	var cycle: int = int(_run_info.get("cycle", 0))
	for index: int in Game.instance.biomes.size():
		var section: ChunkSet = Game.instance.biomes[index]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var rule: BiomeRule = Balance.config.biome_rule(section.id)
		var text: String = tr(section.biome_name_key) + "\n" + tr(section.biome_name_key + "_DESC")
		var label: Label = _label(text, 17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(380, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var pick: Button = Button.new()
		pick.custom_minimum_size = Vector2(170, 0)
		if index == game.biome_index:
			pick.text = tr("PLAN_PICKED")
			pick.disabled = true
		elif not game.section_unlocked(index, cycle):
			pick.text = tr("PLAN_LOCKED") % (rule.unlock_cycle + 1)
			pick.disabled = true
		else:
			pick.text = tr("PLAN_PICK")
			pick.pressed.connect(_on_section_pressed.bind(index))
		row.add_child(pick)
		_panel_box.add_child(row)
	_add_button(tr("PANEL_CLOSE"), close_panels)
	_apply_modal()


func _on_section_pressed(index: int) -> void:
	Audio.play_ui("ui_click")
	Game.instance.request_section.rpc_id(1, index)


func show_results(results: Dictionary, left_behind: bool, dead: bool = false) -> void:
	var fired: bool = results.fired
	var title: String = tr("RESULTS_DIED") if dead else (tr("RESULTS_LEFT_BEHIND") if left_behind else tr("RESULTS_TITLE"))
	_start_panel("over" if fired else "results", title)
	var sold: Array = results.sold
	if sold.is_empty():
		_add_text(tr("RESULTS_NOTHING"), DIM_COLOR)
	for entry: Array in sold:
		_add_text(tr("RESULTS_ITEM") % [tr(entry[0]), int(entry[1])], DIM_COLOR)
	_add_text(tr("RESULTS_TOTAL") % int(results.total), ACCENT)
	if fired:
		_add_text(tr("RESULTS_FIRED") % int(results.quota), Color(0.95, 0.4, 0.3))
		var score: Dictionary = results.score
		_add_text(tr("RESULTS_SCORE") % [int(score.cycles), int(score.money)], TEXT_COLOR)
		_add_button(tr("HUB_LEAVE"), func() -> void: leave_requested.emit())
	else:
		if results.cycle_ended:
			_add_text(tr("RESULTS_QUOTA_MET") % int(results.quota), Color(0.6, 0.9, 0.5))
		_add_text(tr("HUD_MONEY") % int(results.money), TEXT_COLOR)
		_add_button(tr("PANEL_CONTINUE"), close_panels)
	_apply_modal()


# --- panels ----------------------------------------------------------------------------------------

func _open_pause() -> void:
	_start_panel("pause", tr("PAUSE_TITLE"))
	_add_text(_keys_help(), DIM_COLOR, 15)
	_add_button(tr("PANEL_CONTINUE"), close_panels)
	if NetworkManager.can_invite():
		_add_button(tr("PAUSE_INVITE"), _open_invite)
	if NetworkManager.voice_enabled():
		_add_button(tr("PAUSE_VOICE_OPEN") if Audio.voice_open_mic else tr("PAUSE_VOICE_PTT") % Settings.key_label(&"voice_talk"), _toggle_open_mic)
		_add_button(tr("PAUSE_MIC_TEST_ON") if VoiceChat.echo else tr("PAUSE_MIC_TEST_OFF"), _toggle_mic_test)
	_add_button(tr("MENU_SETTINGS"), _open_settings)
	_add_button(tr("HUB_LEAVE"), func() -> void: leave_requested.emit())
	_apply_modal()


## The Steam overlay's invite dialog when there is one, else our own list of Steam friends
## (the overlay is missing when Steam did not start the game, DESIGN.md §9 "in-game friends list").
## Every key and what it does, in the keys the player has set (Esc menu).
func _keys_help() -> String:
	var lines: PackedStringArray = []
	var line: PackedStringArray = []
	for action: StringName in SettingsData.REBINDABLE:
		if String(action).begins_with("slot_"):
			continue
		line.append("%s %s" % [Settings.key_label(action), tr("ACTION_" + String(action).to_upper())])
		if line.size() == 5:
			lines.append(" · ".join(line))
			line = []
	if not line.is_empty():
		lines.append(" · ".join(line))
	return "
".join(lines)


func _open_invite() -> void:
	if NetworkManager.invite_friends():
		close_panels()
		return
	_start_panel("invite", tr("INVITE_TITLE"))
	var friends: Array[Dictionary] = NetworkManager.invitable_friends()
	if friends.is_empty():
		_add_text(tr("INVITE_NO_FRIENDS"), DIM_COLOR)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, mini(friends.size(), 8) * 44)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_panel_box.add_child(scroll)
	for friend: Dictionary in friends:
		var row: HBoxContainer = HBoxContainer.new()
		var name_text: String = str(friend.name)
		if bool(friend.in_game):
			name_text += "  " + tr("INVITE_IN_GAME")
		var name_label: Label = _label(name_text, 17)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.modulate.a = 1.0 if bool(friend.online) else 0.5
		row.add_child(name_label)
		var invite: Button = Button.new()
		invite.text = tr("INVITE_SEND")
		invite.custom_minimum_size = Vector2(130, 36)
		invite.pressed.connect(_on_invite_pressed.bind(int(friend.id), invite))
		row.add_child(invite)
		list.add_child(row)
	_add_button(tr("PANEL_CLOSE"), _open_pause)
	_apply_modal()


func _on_invite_pressed(friend_id: int, button: Button) -> void:
	Audio.play_ui("ui_click")
	var sent: bool = NetworkManager.invite_friend(friend_id)
	button.text = tr("INVITE_SENT") if sent else tr("INVITE_FAILED")
	button.disabled = sent


func _toggle_open_mic() -> void:
	Settings.data.voice_open_mic = not Settings.data.voice_open_mic
	Settings.apply()
	_open_pause()


func _open_settings() -> void:
	_panel.hide()
	_settings.open()
	_apply_modal()


func _on_settings_closed() -> void:
	_open_pause()


func _toggle_mic_test() -> void:
	VoiceChat.echo = not VoiceChat.echo
	_open_pause()


func _on_buy_pressed(id: StringName) -> void:
	Audio.play_ui("ui_click")
	Game.instance.request_buy.rpc_id(1, id)


func _start_panel(kind: String, title: String) -> void:
	_panel_kind = kind
	for child: Node in _panel_box.get_children():
		_panel_box.remove_child(child)
		child.queue_free()
	_add_text(title, ACCENT, 30)
	_panel.show()


func _add_text(text: String, color: Color, size: int = 19) -> void:
	var label: Label = _label(text, size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(label)


func _add_button(text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(action)
	_panel_box.add_child(button)


## Mouse and controls follow whether a panel is open.
func _apply_modal() -> void:
	var game: Game = Game.instance
	var player: Player = game.local_player() if game != null else null
	var riding: bool = game != null and (game.phase == Game.Phase.DESCENDING or game.phase == Game.Phase.ASCENDING)
	var free_mouse: bool = modal_open() or player == null or Game.dev_quiet
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if free_mouse else Input.MOUSE_MODE_CAPTURED
	if player != null:
		player.input_enabled = not modal_open() and not riding


# --- per-frame -------------------------------------------------------------------------------------

func _update_prompt(player: Player) -> void:
	var text: String = ""
	if player.focus != null and is_instance_valid(player.focus):
		text = player.focus.interaction_text(player)
		var hold: bool = player.focus.has_method(&"interact_hold_seconds") and player.focus.interact_hold_seconds(player) > 0.0
		text = ("[%s …] " if hold else "[%s] ") % Settings.key_label(&"interact") + text
	_prompt.text = text
	_prompt.visible = text != ""
	var progress: float = maxf(player.hold_progress, player.use_progress)
	_hold_bar.visible = progress > 0.0
	_hold_bar.value = progress


func _update_slots(player: Player) -> void:
	var inventory: Inventory = player.inventory
	for i: int in _slot_labels.size():
		var item: WorldItem = inventory.slots[i] as WorldItem if i < inventory.slots.size() else null
		_slot_labels[i].text = "%d  %s" % [i + 1, item.display_name() if item != null else "–"]
		_slot_panels[i].modulate = Color(1, 1, 1, 1) if i == inventory.selected else Color(1, 1, 1, 0.55)
	var hands: WorldItem = inventory.hands as WorldItem
	var pocket: WorldItem = inventory.slots[inventory.selected] as WorldItem
	_hands_label.visible = hands != null or (pocket != null and pocket.data.use != ItemData.Use.NONE)
	if hands == null and _hands_label.visible:
		_hands_label.text = "[%s] %s" % [Settings.key_label(&"use"), tr("USE_" + ItemData.Use.keys()[pocket.data.use])]
	if hands != null:
		var text: String = tr("HUD_HANDS") % hands.display_name()
		var cart: Schubkarre = hands as Schubkarre
		if cart != null:
			text += "  (%d/%d)" % [cart.used_units(), Balance.config.schubkarre_capacity_medium]
		elif inventory.shared_carry:
			text += "  " + tr("HUD_TOGETHER")
		elif hands.data.melee_damage > 0:
			text += "   [%s] %s" % [Settings.key_label(&"use"), tr("USE_STRIKE")]
		_hands_label.text = text + "   [%s] " % Settings.key_label(&"drop") + tr("HUD_DROP")


# --- building --------------------------------------------------------------------------------------

func _build_center() -> void:
	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.55)
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-2, -2)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	_alive_nodes.append(_crosshair)
	_spectate_label = _label("", 22)
	_spectate_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spectate_label.position = Vector2(-400, -90)
	_spectate_label.size = Vector2(800, 60)
	_spectate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectate_label.hide()
	_root.add_child(_spectate_label)
	_prompt = _label("", 20)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-300, 30)
	_prompt.size = Vector2(600, 30)
	_root.add_child(_prompt)
	_hold_bar = _bar(Color(0.95, 0.8, 0.5))
	_hold_bar.set_anchors_preset(Control.PRESET_CENTER)
	_hold_bar.position = Vector2(-60, 64)
	_hold_bar.size = Vector2(120, 6)
	_root.add_child(_hold_bar)
	_watch = _label("", 30)
	_watch.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_watch.position = Vector2(-260, -60)
	_watch.size = Vector2(220, 120)
	_watch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_watch.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	_root.add_child(_watch)


func _build_bottom() -> void:
	var bars: VBoxContainer = VBoxContainer.new()
	bars.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bars.position = Vector2(24, -110)
	bars.size = Vector2(220, 90)
	bars.add_theme_constant_override("separation", 4)
	_root.add_child(bars)
	_alive_nodes.append(bars)
	_health_bar = _labelled_bar(bars, tr("HUD_HEALTH"), Color(0.75, 0.2, 0.15))
	_lamp_bar = _labelled_bar(bars, tr("HUD_LAMP"), Color(0.95, 0.75, 0.35))
	_stamina_bar = _labelled_bar(bars, tr("HUD_STAMINA"), Color(0.85, 0.85, 0.8))
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-330, -96)
	bottom.size = Vector2(660, 80)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(bottom)
	_alive_nodes.append(bottom)
	_hands_label = _label("", 17)
	_hands_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_hands_label)
	var slots: HBoxContainer = HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 6)
	bottom.add_child(slots)
	for i: int in Balance.config.inventory_slots:
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _stylebox(Color(0.08, 0.06, 0.04, 0.7)))
		panel.custom_minimum_size = Vector2(150, 34)
		var label: Label = _label("", 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		panel.add_child(label)
		slots.add_child(panel)
		_slot_panels.append(panel)
		_slot_labels.append(label)


func _build_top() -> void:
	_message = _label("", 26)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.position = Vector2(-450, 70)
	_message.size = Vector2(900, 40)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_message)
	_run_label = _label("", 18)
	_run_label.position = Vector2(24, 20)
	_run_label.add_theme_color_override("font_color", ACCENT)
	_root.add_child(_run_label)
	_mic_label = _label(tr("HUD_TALKING"), 18)
	_mic_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_mic_label.position = Vector2(-224, -60)
	_mic_label.size = Vector2(200, 30)
	_mic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mic_label.add_theme_color_override("font_color", ACCENT)
	_mic_label.hide()
	_root.add_child(_mic_label)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _stylebox(PANEL_COLOR, 24))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.hide()
	_root.add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_panel_box)


func _labelled_bar(parent: Container, title: String, color: Color) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = _label(title, 14)
	label.custom_minimum_size = Vector2(70, 0)
	label.add_theme_color_override("font_color", DIM_COLOR)
	row.add_child(label)
	var bar: ProgressBar = _bar(color)
	bar.custom_minimum_size = Vector2(140, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	parent.add_child(row)
	return bar


func _bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _stylebox(Color(0, 0, 0, 0.5), 0))
	bar.add_theme_stylebox_override("fill", _stylebox(color, 0))
	return bar


func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _stylebox(color: Color, margin: int = 6) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	box.set_content_margin_all(margin)
	return box


func _fade_to(alpha: float, seconds: float) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", alpha, seconds)
