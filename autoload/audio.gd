extends Node
## Audio buses and audio settings. Creature lines go to the Creatures bus.

const BUSES: PackedStringArray = ["Music", "SFX", "Creatures", "Voice"]

## Setting "Gegner reden": creature speech on/off. Non-speech creature sounds always play.
var creature_lines_enabled: bool = true


func _ready() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index: int = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
