# Assets

Third-party assets and where they come from.

## Textures (Poly Haven, CC0)

Fetched by `tools/textures/fetch.py`.

| Texture | Used for | Poly Haven asset | Authors |
|---|---|---|---|
| salt_rock (2k) | mine walls and ceiling (rock salt) | [marble_cliff_04](https://polyhaven.com/a/marble_cliff_04) | Amal Kumar |
| mine_floor (2k) | mine floor (dirt and gravel) | [forest_ground_04](https://polyhaven.com/a/forest_ground_04) | Rob Tuytel, Rico Cilliers |
| timber_bark (1k) | round timber posts | [bark_brown_02](https://polyhaven.com/a/bark_brown_02) | Rob Tuytel |
| timber_wood (1k) | beams, sleepers, crates | [rough_wood](https://polyhaven.com/a/rough_wood) | Rob Tuytel |
| rust_iron (1k) | rails, iron fittings | [rust_coarse_01](https://polyhaven.com/a/rust_coarse_01) | Dimitrios Savva, Rico Cilliers |
| metal_plate (1k) | lift cage floor | [metal_plate_02](https://polyhaven.com/a/metal_plate_02) | Rob Tuytel |
| hub_floor (2k) | Gasthaus floor | [wood_floor_worn](https://polyhaven.com/a/wood_floor_worn) | Dimitrios Savva |
| hub_logs (2k) | Gasthaus log walls | [beam_wall_01](https://polyhaven.com/a/beam_wall_01) | Rob Tuytel |
| hub_plaster (1k) | Gasthaus plaster | [plastered_wall](https://polyhaven.com/a/plastered_wall) | Amal Kumar |
| hub_planks (1k) | Gasthaus counter, tables, panelling | [dark_wooden_planks](https://polyhaven.com/a/dark_wooden_planks) | Amal Kumar |
| mandl_coat (1k) | Bergmandl coat (wool, tinted brown) | [caban](https://polyhaven.com/a/caban) | colormass, Rico Cilliers |
| mandl_hat (1k) | Bergmandl cap (tinted red) | [polar_fleece](https://polyhaven.com/a/polar_fleece) | colormass, Rico Cilliers |
| mandl_beard (1k) | Bergmandl beard | [curly_teddy_natural](https://polyhaven.com/a/curly_teddy_natural) | colormass, Rico Cilliers |
| mandl_leather (1k) | Bergmandl belt, boots and bag | [brown_leather](https://polyhaven.com/a/brown_leather) | Rob Tuytel |

## Music

The Gasthaus waltz (`assets/audio/music/stubenmusi.ogg`) is synthesised by `tools/audio/music.py` (our own, no third-party material).

## Gun recordings (CC0)

`tools/audio/recordings/` holds recordings copied from our earlier project Berghittn (`X:\Code\Projects\GeilesGame`, owner request 2026-10-30; the owner allows copying from it, as long as each copy is checked to fit and improved where it can be). Berghittn's `tools/audio/recordings.py` cut them out of near-distance takes, mixed them to mono and limited them. Shots: Walther PPQ (Dienstpistole), Winchester Model 12 and Charles Daly 12 ga (Salzschrot-Flinte), Tikka T3 (Mannlicher-Stutzen, shot_stutzen_1/2, copied in M8); plus magazine out/in, a dry click and a bolt opening/closing.

They are kept untouched there; `tools/audio/guns.py` (run by `build.py`) builds the game's gun sounds from them: `shot_pistole_*` and `shot_flinte_*` get a mine-tunnel boom and early rock slaps, the Flinte extra weight; `flinte_open`, `flinte_close` and `dry_click_flinte` are made from the bolt and click recordings. `shot_stutzen_*` gets the same treatment (a rifle's crack: less boom, more slaps, a longer tail); `bolt_cycle` (the Stutzen's bolt after a shot) is the bolt recordings back to back, `shot_leucht` (the flare pistol) the pistol take pitched far down under a synthesised hiss. `mag_in_1`, `mag_out_1`, `dry_click_1`, `bolt_open_1`, `bolt_close_1` are used as they are (the bolt opening and closing for the Stutzen's reload).

| Source | Authors | Licence |
|---|---|---|
| "The Free Firearm Sound Library", https://opengameart.org/content/the-free-firearm-sound-library | Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney | CC0 |

The mine's echo after a shot (`shot_echo_*`) and the creature hit (`flesh_hit_*`) are synthesised by `tools/audio/sfx.py`.

## Font

`assets/fonts/BarlowCondensed-SemiBold.ttf` and `-Medium.ttf` ("Barlow Condensed" by The Barlow Project Authors, https://github.com/jpt/barlow), from the Google Fonts repository, SIL Open Font License 1.1 (`assets/fonts/OFL.txt`). Used for all UI text.
