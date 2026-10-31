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
## Height of the sight line (top of the rear notch and the front bead) above the gun's origin,
## and how far in front of the eye the gun sits when aiming: the sights then line up with the
## screen centre, where the shots go.
@export var sight_height: float = 0.025
@export var aim_distance: float = 0.3
## Field of view while aiming, as a share of the normal one.
@export var ads_zoom: float = 0.8
## Name of the shot sound (assets/audio/sfx).
@export var sound: String = "shot_pistole"
## Played at the start of a reload, and `reload_sound_late` at that share of it (magazine in).
@export var reload_sound: String = "mag_out"
@export var reload_sound_late: String = ""
@export var reload_late_share: float = 0.6
## A break-action gun: opened once before the first shell (`reload_sound` is then each shell)
## and snapped shut when the reload ends or is cut short.
@export var reload_open_sound: String = ""
@export var reload_close_sound: String = ""
## A reload from empty ends by racking the slide (the pistol), at `rack_share` of the reload.
@export var rack_sound: String = ""
@export var rack_share: float = 0.7
## Pulling the trigger on an empty gun.
@export var dry_sound: String = "dry_click"
## Can be fired while downed (the pistol).
@export var usable_downed: bool = false
## The gun in hand (GunView): kick back (m) and muzzle climb (degrees) per shot, and how long
## it takes to settle; camera shake per shot (0..1).
@export var kick_back: float = 0.05
@export var kick_angle: float = 9.0
@export var kick_time: float = 0.12
@export var shake: float = 0.0
## Where the hands hold it and where the muzzle is (the gun's own space).
@export var grip: Vector3 = Vector3(0.0, -0.06, 0.06)
@export var support: Vector3 = Vector3(-0.02, -0.075, 0.04)
@export var muzzle: Vector3 = Vector3(0.0, 0.0, -0.13)
@export var flash_size: float = 1.0
## Throws out a casing per shot (the pistol; the break-action shotgun does not).
@export var ejects_casing: bool = false
## Pushes a creature back (m/s) per pellet that hits.
@export var knockback: float = 0.0
## Fires a flare (Leuchtpistole) instead of hitscan pellets: it flies and burns (Flare).
@export var projectile: bool = false
## A bolt-action: after each shot the bolt is worked (this sound, starting this long after the
## shot; the gun's "Bolt" node moves with it). The next shot waits for `fire_interval`.
@export var cycle_sound: String = ""
@export var cycle_delay: float = 0.25
## Loaded round by round through the open action (the Stutzen's internal magazine): the left
## hand pushes each round in from above.
@export var top_loaded: bool = false
