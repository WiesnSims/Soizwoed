extends StaticBody3D
## The Gasthaus counter: opens the shop (tools and consumables, DESIGN.md §7).


func interaction_text(_player: Player) -> String:
	return tr("PROMPT_SHOP") if Game.instance.phase == Game.Phase.HUB else ""


func interact(_player: Player) -> void:
	Game.instance.hud.open_shop()
