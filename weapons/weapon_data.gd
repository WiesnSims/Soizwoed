class_name WeaponData
extends Resource
## How a gun behaves (DESIGN.md §7). Lives on the gun's ItemData (`weapon`); the numbers are
## tuned here, per weapon. A shot is `pellets` rays inside a cone of the current spread.

## Which ammo counter it draws on (Player.ammo), e.g. &"pistole", &"schrot".
@export var ammo_type: StringName = &""
## Damage of one pellet at close range.
@export var damage: int = 10
@export var pellets: int = 1
## Seconds between two shots.
@export var fire_interval: float = 0.25
@export var magazine: int = 8
## Seconds to reload a full magazine, or one round when `reload_per_round`.
@export var reload_seconds: float = 1.6
@export var reload_per_round: bool = false
## Half-angle of the cone the pellets fly in (degrees): from the hip and aiming down the sights.
@export var spread_hip: float = 2.5
@export var spread_ads: float = 0.8
## Moving widens the cone by this factor; crouching narrows it.
@export var spread_moving: float = 1.6
@export var spread_crouched: float = 0.8
## Beyond `falloff_start` m the damage drops linearly to `falloff_min` of it at `range` m.
@export var range: float = 40.0
@export var falloff_start: float = 15.0
@export var falloff_min: float = 0.5
## The muzzle kicks the view up by this many degrees per shot.
@export var recoil: float = 2.5
## Creatures that listen hear the shot this far (m).
@export var noise: float = 30.0
## Field of view while aiming, as a share of the normal one.
@export var ads_zoom: float = 0.8
## Name of the shot sound (assets/audio/sfx).
@export var sound: String = "pistol_shot"
@export var reload_sound: String = "reload_pistol"
## Can be fired while downed (the pistol).
@export var usable_downed: bool = false
## Pushes a creature back (m/s) per pellet that hits.
@export var knockback: float = 0.0
