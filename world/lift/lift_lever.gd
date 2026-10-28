extends StaticBody3D
## The lift lever. In the Gasthaus it sends the crew down (starts a shift); in the mine it
## sends the Förderkorb up early, which needs a long pull so nobody does it by accident.

@onready var cage: Foerderkorb = get_parent() as Foerderkorb


func interaction_text(_player: Player) -> String:
	var game: Game = Game.instance
	if cage.in_hub:
		return tr("PROMPT_LIFT_DOWN") if game.phase == Game.Phase.HUB else ""
	return tr("PROMPT_LIFT_UP") if game.phase == Game.Phase.SHIFT else ""


func interact_hold_seconds(_player: Player) -> float:
	return 0.0 if cage.in_hub else Balance.config.lift_lever_hold_seconds


func interact(_player: Player) -> void:
	Game.instance.play_sound_everywhere.rpc("lever", global_position)
	Game.instance.request_lift.rpc_id(1)
