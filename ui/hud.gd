class_name Hud
extends CanvasLayer
## Everything on screen during the game: crosshair, interaction prompt, inventory slots, bars
## (health, stamina, carbide), pocket watch, messages, fades, and the panels (shop, shift
## results, pause). While dead it only says whom you are watching. Built in code; all texts go
## through tr().

signal leave_requested

const TEXT_COLOR: Color = Color(0.96, 0.9, 0.78)
const DIM_COLOR: Color = Color(0.7, 0.64, 0.55)
const PANEL_COLOR: Color = Color(0.08, 0.06, 0.04, 0.95)
const ACCENT: Color = Color(0.86, 0.62, 0.3)
const PANEL_SIZE: Vector2 = Vector2(520, 0)
const SHOP_SIZE: Vector2 = Vector2(1000, 620)
const SHOP_CARD_WIDTH: float = 236.0
const SHOP_CATEGORY_KEYS: Array[String] = ["SHOP_CAT_WEAPONS", "SHOP_CAT_AMMO", "SHOP_CAT_THROWABLES", "SHOP_CAT_PROVISIONS", "SHOP_CAT_GEAR", "SHOP_CAT_UPGRADES"]
const SHOP_CATEGORY_ICONS: Array[HudIcon.Kind] = [HudIcon.Kind.GUN, HudIcon.Kind.BULLET, HudIcon.Kind.BOMB, HudIcon.Kind.BOTTLE, HudIcon.Kind.PICK, HudIcon.Kind.ARMOUR]
const ALARM_COLOR: Color = Color(1.0, 0.42, 0.3)

## Teammates, downed marks and pings.
var team: TeamOverlay
var _root: Control
var _crosshair: Crosshair
var _icons: ItemIcons
var _hotbar: Hotbar
## Bottom right: the gun in hand.
var _ammo_box: Control
var _ammo_name: Label
var _ammo_magazine: Label
var _ammo_spare: Label
var _ammo_icon: HudIcon
var _health_value: Label
var _armour_bar: ProgressBar
## Top centre while the alarm is on: the Rückweg-timer.
var _alarm_label: Label
var _prompt: Label
var _hold_bar: ProgressBar
var _message: Label
var _message_tween: Tween
var _run_label: Label
var _hands_label: Label
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
var _dim: ColorRect
var _panel_box: VBoxContainer
var _panel_kind: String = ""
var _run_info: Dictionary = {}
var _settings: SettingsPanel
## The shelf open in the shop, and the item pictures shown there (filled in when rendered):
## item id -> the TextureRects showing it.
var _shop_category: int = ItemData.ShopCategory.WEAPONS
var _shop_pictures: Dictionary = {}
## The Knappenbrief sheet shown: 0 perks, 1 cosmetics.
var _brief_sheet: int = 0


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_icons = ItemIcons.new()
	_icons.name = "ItemIcons"
	add_child(_icons)
	_icons.icon_ready.connect(_on_icon_ready)
	_build_center()
	_build_bottom()
	_build_ammo()
	_build_top()
	team = TeamOverlay.new()
	team.name = "Team"
	_root.add_child(team)
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
	_dim.visible = _panel.visible
	if player == null:
		return
	for node: Control in _alive_nodes:
		node.visible = player.alive
	_spectate_label.visible = not player.alive or player.downed
	if player.downed:
		_spectate_label.text = tr("HUD_DOWNED") % ceili(player.downed_left())
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
	_update_gun(player)
	_health_bar.value = float(player.health) / player.max_health
	_health_value.text = str(player.health)
	_armour_bar.get_parent().visible = player.armour_cap() > 0
	_armour_bar.value = float(player.armour) / maxf(1.0, player.armour_cap())
	_alarm_label.visible = game.alarm_on and game.phase == Game.Phase.SHIFT
	if _alarm_label.visible:
		_alarm_label.text = tr("HUD_ALARM") % Game._clock(game.alarm_left)
		# Blinks in the last half minute.
		_alarm_label.modulate.a = 1.0 if game.alarm_left > 30.0 or fmod(game.alarm_left, 1.0) > 0.35 else 0.35
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
	_run_label.text = "%s\n%s" % [tr("HUD_MONEY") % int(info.money), tr("HUD_SHIFT") % (int(info.shift) + 1)]
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


## The shop at the Wirt's counter: the shelves (categories) on the left, the items of the chosen
## one as cards on the right – the item's own picture, name, what it does, the price and a buy
## button. The till is shown on top; what you cannot afford is dimmed.
func open_shop() -> void:
	_start_panel("shop", "", SHOP_SIZE)
	var money: int = int(_run_info.get("money", 0))
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var title: Label = _label(tr("SHOP_TITLE"), 32)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(HudIcon.new(HudIcon.Kind.COIN, Color.WHITE, 26))
	var till: Label = _label(tr("SHOP_MONEY") % money, 24)
	top.add_child(till)
	_panel_box.add_child(top)
	_panel_box.add_child(_rule())
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_box.add_child(body)
	# The shelves.
	var shelves: VBoxContainer = VBoxContainer.new()
	shelves.custom_minimum_size = Vector2(200, 0)
	shelves.add_theme_constant_override("separation", 6)
	body.add_child(shelves)
	var stock: Dictionary = {}  # ShopCategory -> Array[ItemData], or Array[RunUpgrade] for UPGRADES
	for data: ItemData in Game.instance.catalog.shop():
		if not stock.has(data.shop_category()):
			stock[data.shop_category()] = []
		(stock[data.shop_category()] as Array).append(data)
	if not Balance.config.run_upgrades.is_empty():
		stock[ItemData.ShopCategory.UPGRADES] = Balance.config.run_upgrades
	if not stock.has(_shop_category) and not stock.is_empty():
		_shop_category = stock.keys().min()
	for category: int in ItemData.ShopCategory.values():
		if not stock.has(category):
			continue
		var tab: Button = Button.new()
		tab.text = "        %s  (%d)" % [tr(SHOP_CATEGORY_KEYS[category]), (stock[category] as Array).size()]
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(0, 46)
		tab.add_theme_font_size_override("font_size", 20)
		tab.toggle_mode = true
		tab.button_pressed = category == _shop_category
		var chosen: bool = category == _shop_category
		tab.add_theme_stylebox_override("normal", _tab_box(chosen))
		tab.add_theme_stylebox_override("hover", _tab_box(true, 0.6))
		tab.add_theme_stylebox_override("pressed", _tab_box(true))
		tab.add_theme_color_override("font_color", ACCENT if chosen else TEXT_COLOR)
		tab.add_theme_color_override("font_pressed_color", ACCENT)
		tab.pressed.connect(_on_shop_category.bind(category))
		var icon: HudIcon = HudIcon.new(SHOP_CATEGORY_ICONS[category], ACCENT if chosen else DIM_COLOR, 24)
		icon.position = Vector2(10, 11)
		tab.add_child(icon)
		shelves.add_child(tab)
	# The cards of the chosen shelf.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	_shop_pictures.clear()
	for entry: Resource in stock.get(_shop_category, []):
		grid.add_child(_upgrade_card(entry as RunUpgrade, money) if entry is RunUpgrade else _shop_card(entry as ItemData, money))
	_panel_box.add_child(_rule())
	var close: Button = Button.new()
	close.text = tr("PANEL_CLOSE")
	close.custom_minimum_size = Vector2(200, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(close_panels)
	_panel_box.add_child(close)
	_apply_modal()


func _shop_card(data: ItemData, money: int) -> Control:
	var affordable: bool = data.price <= money
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(SHOP_CARD_WIDTH, 0)
	var frame: StyleBoxFlat = _stylebox(Color(1, 1, 1, 0.05), 12)
	frame.border_color = Color(1, 1, 1, 0.12)
	frame.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", frame)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var picture_back: PanelContainer = PanelContainer.new()
	picture_back.add_theme_stylebox_override("panel", _stylebox(Color(0, 0, 0, 0.35), 4))
	var picture: TextureRect = TextureRect.new()
	picture.custom_minimum_size = Vector2(0, 104)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = _icons.icon(data)
	picture_back.add_child(picture)
	box.add_child(picture_back)
	_remember_picture(data.id, picture)
	var name_label: Label = _label(tr(data.name_key), 21)
	name_label.add_theme_color_override("font_color", TEXT_COLOR if affordable else DIM_COLOR)
	box.add_child(name_label)
	var description: Label = _label(tr(data.name_key + "_DESC"), 15)
	description.add_theme_color_override("font_color", DIM_COLOR)
	description.add_theme_constant_override("outline_size", 0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(SHOP_CARD_WIDTH - 24, 64)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	var buy: Button = Button.new()
	buy.text = tr("SHOP_BUY") % data.price
	buy.custom_minimum_size = Vector2(0, 38)
	buy.add_theme_font_size_override("font_size", 18)
	buy.disabled = not affordable
	if affordable:
		buy.add_theme_color_override("font_color", ACCENT)
	buy.pressed.connect(_on_buy_pressed.bind(data.id))
	box.add_child(buy)
	if not affordable:
		card.modulate = Color(1, 1, 1, 0.65)
	return card


## A card of the upgrades shelf: the picture of what it improves, its name and level, what it
## does and the price of the next level (DESIGN.md §7 "Run upgrades").
func _upgrade_card(upgrade: RunUpgrade, money: int) -> Control:
	var levels: Dictionary = _run_info.get("upgrades", {})
	var level: int = int(levels.get(upgrade.id, 0))
	var maxed: bool = level >= upgrade.max_level()
	var price: int = upgrade.price_after(level)
	var affordable: bool = not maxed and price <= money
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(SHOP_CARD_WIDTH, 0)
	var frame: StyleBoxFlat = _stylebox(Color(1, 1, 1, 0.05), 12)
	frame.border_color = Color(ACCENT, 0.5) if level > 0 else Color(1, 1, 1, 0.12)
	frame.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", frame)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var picture_back: PanelContainer = PanelContainer.new()
	picture_back.add_theme_stylebox_override("panel", _stylebox(Color(0, 0, 0, 0.35), 4))
	picture_back.custom_minimum_size = Vector2(0, 104)
	var item: ItemData = Game.instance.catalog.by_id(upgrade.icon_item) if upgrade.icon_item != &"" else null
	if item != null:
		var picture: TextureRect = TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture = _icons.icon(item)
		picture_back.add_child(picture)
		_remember_picture(item.id, picture)
	else:
		var drawn: HudIcon.Kind = HudIcon.Kind.POCKET if upgrade.effect == RunUpgrade.Effect.POCKET_SLOT else HudIcon.Kind.ARMOUR
		var shield: HudIcon = HudIcon.new(drawn, Color(0.62, 0.66, 0.72) if drawn == HudIcon.Kind.ARMOUR else Color(0.55, 0.38, 0.22), 72)
		shield.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		shield.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picture_back.add_child(shield)
	box.add_child(picture_back)
	var name_label: Label = _label("%s  %s" % [tr(upgrade.name_key), tr("SHOP_LEVEL") % [level, upgrade.max_level()]], 21)
	name_label.add_theme_color_override("font_color", TEXT_COLOR if affordable or maxed else DIM_COLOR)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var description: Label = _label(tr(upgrade.name_key + "_DESC"), 15)
	description.add_theme_color_override("font_color", DIM_COLOR)
	description.add_theme_constant_override("outline_size", 0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(SHOP_CARD_WIDTH - 24, 64)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	var buy: Button = Button.new()
	buy.text = tr("SHOP_MAXED") if maxed else tr("SHOP_BUY") % price
	buy.custom_minimum_size = Vector2(0, 38)
	buy.add_theme_font_size_override("font_size", 18)
	buy.disabled = not affordable
	if affordable:
		buy.add_theme_color_override("font_color", ACCENT)
	buy.pressed.connect(_on_upgrade_pressed.bind(upgrade.id))
	box.add_child(buy)
	if not affordable and not maxed:
		card.modulate = Color(1, 1, 1, 0.65)
	return card


func _remember_picture(id: StringName, picture: TextureRect) -> void:
	if not _shop_pictures.has(id):
		_shop_pictures[id] = []
	(_shop_pictures[id] as Array).append(picture)


func _on_upgrade_pressed(id: StringName) -> void:
	Audio.play_ui("ui_click")
	Game.instance.request_buy_upgrade.rpc_id(1, id)


func _on_shop_category(category: int) -> void:
	Audio.play_ui("ui_click")
	_shop_category = category
	open_shop()


## An item picture finished rendering: put it into the open shop.
func _on_icon_ready(id: StringName) -> void:
	for picture: Variant in _shop_pictures.get(id, []):
		if is_instance_valid(picture):
			(picture as TextureRect).texture = _icons.icon(Game.instance.catalog.by_id(id))


func _tab_box(chosen: bool, strength: float = 1.0) -> StyleBoxFlat:
	var box: StyleBoxFlat = _stylebox(Color(ACCENT, 0.16 * strength) if chosen else Color(1, 1, 1, 0.04), 8)
	box.border_color = Color(ACCENT, strength) if chosen else Color(1, 1, 1, 0.0)
	box.border_width_left = 3
	return box


func _rule() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = Color(1, 1, 1, 0.1)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The Knappenbrief on the Gasthaus wall (DESIGN.md §7): this player's own Ehrenzeichen buy
## permanent perks (the "Knappe" sheet) and things to wear (the "Gwand" sheet). Bought start
## weapons and cosmetics can be taken along or put away. Only in the Gasthaus.
func open_knappenbrief() -> void:
	_start_panel("knappenbrief", "", SHOP_SIZE)
	var profile: PlayerProfile = GameState.profile
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var title: Label = _label(tr("KNAPPENBRIEF_TITLE"), 32)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(HudIcon.new(HudIcon.Kind.MEDAL, Color.WHITE, 30))
	top.add_child(_label(tr("KNAPPENBRIEF_HONOURS") % profile.ehrenzeichen, 24))
	_panel_box.add_child(top)
	var note: Label = _label(tr("KNAPPENBRIEF_NOTE") % [profile.ehrenzeichen_total, profile.best_shifts], 15)
	note.add_theme_color_override("font_color", DIM_COLOR)
	_panel_box.add_child(note)
	_panel_box.add_child(_rule())
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_box.add_child(body)
	var sheets: VBoxContainer = VBoxContainer.new()
	sheets.custom_minimum_size = Vector2(200, 0)
	sheets.add_theme_constant_override("separation", 6)
	body.add_child(sheets)
	for sheet: int in 2:
		var tab: Button = Button.new()
		var chosen: bool = sheet == _brief_sheet
		tab.text = "        %s" % tr("KNAPPENBRIEF_SHEET_%d" % sheet)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(0, 46)
		tab.add_theme_font_size_override("font_size", 20)
		tab.add_theme_stylebox_override("normal", _tab_box(chosen))
		tab.add_theme_stylebox_override("hover", _tab_box(true, 0.6))
		tab.add_theme_stylebox_override("pressed", _tab_box(true))
		tab.add_theme_color_override("font_color", ACCENT if chosen else TEXT_COLOR)
		tab.pressed.connect(func() -> void:
			Audio.play_ui("ui_click")
			_brief_sheet = sheet
			open_knappenbrief())
		var icon: HudIcon = HudIcon.new(HudIcon.Kind.MEDAL if sheet == 0 else HudIcon.Kind.HAT, ACCENT if chosen else DIM_COLOR, 24)
		icon.position = Vector2(10, 11)
		tab.add_child(icon)
		sheets.add_child(tab)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	_shop_pictures.clear()
	for perk: Perk in Balance.config.perks:
		if perk.is_cosmetic() == (_brief_sheet == 1):
			grid.add_child(_perk_card(perk, profile))
	_panel_box.add_child(_rule())
	var close: Button = Button.new()
	close.text = tr("PANEL_CLOSE")
	close.custom_minimum_size = Vector2(200, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(close_panels)
	_panel_box.add_child(close)
	_apply_modal()


## A Knappenbrief card: the picture, name and level, what it does, and either the price of the
## next level or, for a bought start weapon or cosmetic, taking it along / putting it away.
func _perk_card(perk: Perk, profile: PlayerProfile) -> Control:
	var level: int = profile.level(perk.id)
	var maxed: bool = level >= perk.max_level()
	var price: int = perk.price_after(level)
	var affordable: bool = not maxed and price <= profile.ehrenzeichen
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(SHOP_CARD_WIDTH, 0)
	var frame: StyleBoxFlat = _stylebox(Color(1, 1, 1, 0.05), 12)
	frame.border_color = Color(ACCENT, 0.5) if level > 0 else Color(1, 1, 1, 0.12)
	frame.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", frame)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var picture_back: PanelContainer = PanelContainer.new()
	picture_back.add_theme_stylebox_override("panel", _stylebox(Color(0, 0, 0, 0.35), 4))
	picture_back.custom_minimum_size = Vector2(0, 104)
	var item: ItemData = Game.instance.catalog.by_id(perk.icon_item) if perk.icon_item != &"" else null
	if item != null:
		var picture: TextureRect = TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture = _icons.icon(item)
		picture_back.add_child(picture)
		_remember_picture(item.id, picture)
	else:
		var drawn: HudIcon = HudIcon.new(_perk_icon(perk), _perk_icon_color(perk), 72)
		drawn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		drawn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picture_back.add_child(drawn)
	box.add_child(picture_back)
	var heading: String = tr(perk.name_key) if perk.max_level() == 1 else "%s  %s" % [tr(perk.name_key), tr("SHOP_LEVEL") % [level, perk.max_level()]]
	var name_label: Label = _label(heading, 21)
	name_label.add_theme_color_override("font_color", TEXT_COLOR if affordable or level > 0 else DIM_COLOR)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var description: Label = _label(tr(perk.name_key + "_DESC"), 15)
	description.add_theme_color_override("font_color", DIM_COLOR)
	description.add_theme_constant_override("outline_size", 0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(SHOP_CARD_WIDTH - 24, 64)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", 18)
	if perk.is_choice() and level > 0:
		var on: bool = profile.chosen(perk)
		var weapon: bool = perk.effect == Perk.Effect.START_WEAPON
		if on:
			button.text = tr("KNAPPENBRIEF_LEAVE" if weapon else "KNAPPENBRIEF_TAKE_OFF")
		else:
			button.text = tr("KNAPPENBRIEF_TAKE" if weapon else "KNAPPENBRIEF_WEAR")
		button.add_theme_color_override("font_color", ACCENT)
		button.pressed.connect(_on_perk_choice.bind(perk.id, not on))
	else:
		button.text = tr("SHOP_MAXED") if maxed else tr("KNAPPENBRIEF_BUY") % price
		button.disabled = not affordable
		if affordable:
			button.add_theme_color_override("font_color", ACCENT)
		button.pressed.connect(_on_perk_pressed.bind(perk.id))
	box.add_child(button)
	if not affordable and level == 0:
		card.modulate = Color(1, 1, 1, 0.65)
	return card


func _perk_icon(perk: Perk) -> HudIcon.Kind:
	match perk.effect:
		Perk.Effect.MAX_HEALTH, Perk.Effect.REVIVE_SPEED:
			return HudIcon.Kind.HEALTH
		Perk.Effect.START_MONEY:
			return HudIcon.Kind.COIN
		Perk.Effect.START_ARMOUR:
			return HudIcon.Kind.ARMOUR
		Perk.Effect.POCKET_SLOT:
			return HudIcon.Kind.POCKET
		Perk.Effect.HAT:
			return HudIcon.Kind.HAT
		Perk.Effect.LAMP_COLOUR:
			return HudIcon.Kind.LAMP
	return HudIcon.Kind.MEDAL


func _perk_icon_color(perk: Perk) -> Color:
	match perk.effect:
		Perk.Effect.REVIVE_SPEED:
			return Color(0.9, 0.9, 0.86)
		Perk.Effect.START_ARMOUR:
			return Color(0.62, 0.66, 0.72)
		Perk.Effect.POCKET_SLOT:
			return Color(0.55, 0.38, 0.22)
		Perk.Effect.HAT:
			return Color(0.12, 0.12, 0.13) if perk.target == &"knappe" else Color(0.25, 0.32, 0.22)
		Perk.Effect.LAMP_COLOUR:
			return Balance.config.lamp_colours.get(perk.target, Color.WHITE)
	return Color(0.85, 0.22, 0.17)


func _on_perk_pressed(id: StringName) -> void:
	var perk: Perk = Balance.config.perk(id)
	if perk == null or not GameState.profile.buy(perk):
		show_message(tr("MSG_TOO_FEW_HONOURS"))
		return
	Audio.play_ui("ui_click")
	GameState.profile.save()
	_profile_changed()
	show_message(tr("MSG_PERK_BOUGHT") % tr(perk.name_key))


func _on_perk_choice(id: StringName, on: bool) -> void:
	var perk: Perk = Balance.config.perk(id)
	if perk == null:
		return
	Audio.play_ui("ui_click")
	GameState.profile.choose(perk, on)
	GameState.profile.save()
	_profile_changed()


## The profile changed: the host and everyone else learn what it brings now.
func _profile_changed() -> void:
	var player: Player = Game.instance.local_player()
	if player != null:
		player.submit_loadout.rpc_id(1, GameState.profile.loadout())
	open_knappenbrief()


## The Grubnplan: pick the mine section for the next shift (deeper ones open as the run goes on).
func open_sections() -> void:
	_start_panel("sections", tr("PLAN_TITLE"))
	var game: Game = Game.instance
	var shift: int = int(_run_info.get("shift", 0))
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
		elif not game.section_unlocked(index, shift):
			pick.text = tr("PLAN_LOCKED") % (rule.unlock_shift + 1)
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
	var fundstueck: String = tr(str(results.get("fundstueck", "")))
	if fired:
		# Why the crew lost its job (DESIGN.md §2).
		var reasons: Dictionary = {Game.Ascent.TIMEOUT: "RESULTS_FIRED_TIMEOUT", Game.Ascent.ALL_DEAD: "RESULTS_FIRED_DEAD", Game.Ascent.GAVE_UP: "RESULTS_FIRED_GAVE_UP"}
		_add_text(tr(reasons.get(int(results.get("reason", 0)), "RESULTS_FIRED_GAVE_UP")) % fundstueck, ALARM_COLOR)
		var score: Dictionary = results.score
		_add_text(tr("RESULTS_SCORE") % [int(score.shifts), int(score.money), int(score.ehrenzeichen)], TEXT_COLOR)
		_add_button(tr("HUB_LEAVE"), func() -> void: leave_requested.emit())
	else:
		_add_text(tr("RESULTS_DELIVERED") % [fundstueck, int(results.bonus)], Color(0.6, 0.9, 0.5))
		_add_text(tr("RESULTS_EHRENZEICHEN") % int(results.ehrenzeichen), Color(0.95, 0.82, 0.45))
		_add_text(tr("RESULTS_HONOURS_TOTAL") % GameState.profile.ehrenzeichen, DIM_COLOR, 16)
		_add_text(tr("RESULTS_NEXT_SHIFT") % (int(results.shift) + 1), DIM_COLOR)
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


func _start_panel(kind: String, title: String, min_size: Vector2 = PANEL_SIZE) -> void:
	_panel_kind = kind
	for child: Node in _panel_box.get_children():
		_panel_box.remove_child(child)
		child.queue_free()
	_panel.custom_minimum_size = min_size
	_panel.reset_size()
	_center_panel.call_deferred()
	if title != "":
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
	elif player.ammo_mate() != null:
		text = "[%s] " % Settings.key_label(&"drop") + tr("PROMPT_HAND_AMMO") % player.ammo_mate().display_name()
	_prompt.text = text
	_prompt.visible = text != ""
	var progress: float = maxf(player.hold_progress, player.use_progress)
	_hold_bar.visible = progress > 0.0
	_hold_bar.value = progress


func _update_slots(player: Player) -> void:
	var inventory: Inventory = player.inventory
	_hotbar.refresh(player, get_process_delta_time())
	var hands: WorldItem = inventory.hands as WorldItem
	var pocket: WorldItem = inventory.slots[inventory.selected] as WorldItem
	_hands_label.visible = hands != null or (pocket != null and pocket.data.use != ItemData.Use.NONE and pocket.data.weapon == null)
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
	_crosshair = Crosshair.new()
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


## The gun in hand, bottom right: a big magazine count, the spare rounds and their icon.
func _build_ammo() -> void:
	_ammo_box = VBoxContainer.new()
	_ammo_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_box.position = Vector2(-260, -118)
	_ammo_box.size = Vector2(236, 100)
	_ammo_box.alignment = BoxContainer.ALIGNMENT_END
	_ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ammo_box)
	_alive_nodes.append(_ammo_box)
	_ammo_name = _label("", 16)
	_ammo_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_name.add_theme_color_override("font_color", DIM_COLOR)
	_ammo_box.add_child(_ammo_name)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_box.add_child(row)
	_ammo_icon = HudIcon.new(HudIcon.Kind.BULLET, Color.WHITE, 30.0)
	_ammo_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ammo_icon)
	_ammo_magazine = _label("", 54)
	_ammo_magazine.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	row.add_child(_ammo_magazine)
	_ammo_spare = _label("", 26)
	_ammo_spare.size_flags_vertical = Control.SIZE_SHRINK_END
	_ammo_spare.add_theme_color_override("font_color", DIM_COLOR)
	row.add_child(_ammo_spare)


## Ammo, crosshair (opening with the spread, gone while aiming) and the reload bar.
func _update_gun(player: Player) -> void:
	var gunner: Gunner = player.gunner
	var item: WorldItem = gunner.weapon_item() if gunner != null else null
	_ammo_box.visible = item != null
	var gap: float = 6.0
	if item != null:
		var weapon: WeaponData = item.data.weapon
		var spare: int = player.ammo_count(weapon.ammo_type)
		_ammo_name.text = tr("HUD_RELOADING") if gunner.reloading else (tr("HUD_NO_AMMO") if item.rounds == 0 and spare == 0 else item.display_name())
		_ammo_magazine.text = str(item.rounds)
		_ammo_magazine.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3) if item.rounds == 0 else Color(1.0, 0.92, 0.72))
		_ammo_spare.text = "/ %d" % spare
		_ammo_icon.kind = HudIcon.ammo_kind(weapon.ammo_type)
		_ammo_icon.queue_redraw()
		var moving: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.6
		gap = clampf(WeaponMath.spread(weapon, gunner.aiming, moving, player.crouching) * 3.5, 4.0, 40.0)
	_crosshair.gap = gap
	_crosshair.dot_only = item == null
	# Aiming down the sights, the notch and bead are the crosshair.
	_crosshair.visible = not (gunner != null and gunner.aiming and item != null)
	if gunner != null and gunner.reloading:
		_hold_bar.visible = true
		_hold_bar.value = gunner.reload_progress


func _build_bottom() -> void:
	# Bottom left: health (with its number), lamp and breath, each with an icon.
	var bars: VBoxContainer = VBoxContainer.new()
	bars.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bars.position = Vector2(24, -104)
	bars.size = Vector2(260, 84)
	bars.alignment = BoxContainer.ALIGNMENT_END
	bars.add_theme_constant_override("separation", 6)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bars)
	_alive_nodes.append(bars)
	_health_bar = _status_row(bars, HudIcon.Kind.HEALTH, Color(0.85, 0.22, 0.17), 14.0, 26.0)
	_health_value = _label("", 26)
	(_health_bar.get_parent() as HBoxContainer).add_child(_health_value)
	_armour_bar = _status_row(bars, HudIcon.Kind.ARMOUR, Color(0.62, 0.66, 0.72), 8.0, 20.0)
	_lamp_bar = _status_row(bars, HudIcon.Kind.LAMP, Color(0.98, 0.76, 0.35), 8.0, 20.0)
	_stamina_bar = _status_row(bars, HudIcon.Kind.STAMINA, Color(0.85, 0.85, 0.8), 6.0, 18.0)
	# Bottom centre: the hint for what is in hand, and the hotbar.
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-440, -140)
	bottom.size = Vector2(880, 128)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 2)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_alive_nodes.append(bottom)
	_hands_label = _label("", 15)
	_hands_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hands_label.add_theme_color_override("font_color", DIM_COLOR)
	bottom.add_child(_hands_label)
	_hotbar = Hotbar.new()
	_hotbar.icons = _icons
	_hotbar.build(Inventory.layout(Balance.config))
	bottom.add_child(_hotbar)


## One status line: an icon and a bar after it.
func _status_row(parent: Container, kind: HudIcon.Kind, color: Color, height: float, icon_size: float) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: HudIcon = HudIcon.new(kind, color, icon_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var bar: ProgressBar = _bar(color)
	bar.custom_minimum_size = Vector2(170, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	parent.add_child(row)
	return bar


func _build_top() -> void:
	_message = _label("", 30)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.position = Vector2(-450, 70)
	_message.size = Vector2(900, 40)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_message)
	_alarm_label = _label("", 34)
	_alarm_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alarm_label.position = Vector2(-200, 18)
	_alarm_label.size = Vector2(400, 44)
	_alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alarm_label.add_theme_color_override("font_color", ALARM_COLOR)
	_alarm_label.hide()
	_root.add_child(_alarm_label)
	_alive_nodes.append(_alarm_label)
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
	# Behind an open panel the game is dimmed, so the panel stands out from the HUD.
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.hide()
	_root.add_child(_dim)
	_panel = PanelContainer.new()
	var panel_box: StyleBoxFlat = _stylebox(PANEL_COLOR, 24)
	panel_box.border_color = Color(ACCENT, 0.35)
	panel_box.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", panel_box)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.hide()
	_root.add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_panel_box)
	_panel.resized.connect(_center_panel)


## Keeps the panel in the middle of the screen whatever its size.
func _center_panel() -> void:
	_panel.position = ((_root.size - _panel.size) / 2.0).round()


func _bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back: StyleBoxFlat = _stylebox(Color(0, 0, 0, 0.45), 0)
	back.border_color = Color(1, 1, 1, 0.14)
	back.set_border_width_all(1)
	back.set_corner_radius_all(2)
	var fill: StyleBoxFlat = _stylebox(color, 0)
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
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
