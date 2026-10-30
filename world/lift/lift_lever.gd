extends StaticBody3D
## The lift lever. In the Gasthaus it sends the crew down (starts a shift); in the mine it
## sends the Förderkorb up – only with the Fundstück on board, else a second pull gives up the
## shift (the host decides). A long pull, so nobody does it by accident.

@onready var cage: Foerderkorb = get_parent() as Foerderkorb


func interaction_text(player: Player) -> String:
	var game: Game = Game.instance
	if cage.in_hub:
		return tr("PROMPT_LIFT_DOWN") if game.phase == Game.Phase.HUB else ""
	if game.phase != Game.Phase.SHIFT or not cage.contains(player.global_position):
		return ""
	# Clients only know roughly: the host's check decides.
	return tr("PROMPT_LIFT_UP") if not multiplayer.is_server() or game.fundstueck_on_board() else tr("PROMPT_LIFT_GIVE_UP")


func interact_hold_seconds(_player: Player) -> float:
	return 0.0 if cage.in_hub else Balance.config.lift_lever_hold_seconds


func interact(_player: Player) -> void:
	Game.instance.play_sound_everywhere.rpc("lever", global_position)
	Game.instance.request_lift.rpc_id(1)
