extends StaticBody3D
## Carbide and water at the lift: refills the player's lamp to full (DESIGN.md §3).


func interaction_text(player: Player) -> String:
	return tr("PROMPT_REFILL_LAMP") if player.lamp_share() < 0.98 else ""


func interact(player: Player) -> void:
	player.refill_lamp(1.0)
