# Soizwöd

First-person co-op extraction game in a cursed Austrian salt mine. 1–4 players, solo fully supported.
Godot 4 + GDScript, Windows desktop build, Steam networking via GodotSteam with App ID 480.

The full game design is here and must be followed:
@docs/DESIGN.md

## How to work
- Work milestone by milestone (DESIGN.md §12). Finish and test one milestone before starting the next.
- At the end of each milestone, produce a working Windows build and summarise what to playtest.
- Work on a milestone branch. When I approve the milestone, merge it into `main` and then delete the branch (no tags needed). Always push `main` to GitHub after completing a milestone or merging into `main`.
- If you need something from me (installing Godot export templates, Steam client running, a second Steam account, a design decision), ask clearly and specifically instead of guessing.
- When a design question is not answered in DESIGN.md, make a sensible choice, note it in `docs/DECISIONS.md`, and tell me.

## Code conventions
- GDScript with static typing everywhere (`var speed: float = 5.0`, typed function signatures).
- Code, comments, file and node names in English. Player-facing text in German/Austrian dialect, always through the translation system (`tr()` + `i18n/*.csv`), never hard-coded.
- snake_case files and functions, PascalCase classes and nodes.
- Items, tools, enemies and balance values are data-driven `Resource`s (`.tres`). All balance numbers live in `balance.tres`.
- Every networked feature must work in both solo (host only) and multiplayer – solo is just a host with zero clients.

## Networking rules
- Host is authoritative for world state (AI, loot, timer, quota, physics objects). Each player owns their own character movement.
- Never call Steam APIs outside `net/steam_backend.gd` and voice code; everything else talks to the `NetworkManager` autoload.
- Keep the ENet backend working at all times – it is the main way to test multiplayer without Steam.
- Steam lobbies must always set and filter `game=soizwoed` and `ver=<version>` metadata (App ID 480 is shared).

## Commands
- Run tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Export Windows build: `godot --headless --export-release "Windows Desktop" build/Soizwoed.exe`
- Local multiplayer test: start one instance with `-- --net=enet --host` and others with `-- --net=enet --join=127.0.0.1`
- Script versions (PowerShell, logs in `build/logs/`, exit code 1 on any error or warning):
  - `tools/run_tests.ps1` – GUT tests
  - `tools/smoke_test.ps1` – headless main menu + solo session
  - `tools/mp_test.ps1 -Clients 3` (add `-HostLeavesFirst` for the host-quits case) – headless ENet host + clients playing a short shift
  - `tools/mp_test.ps1 -Coop` – headless co-op scenario: item sync, carrying together, death and spectating
  - `tools/mp_test.ps1 -Tools` – headless: a client uses the M4 tools, the host must see each use arrive
  - `tools/steam_test.ps1` – needs the Steam client running: headless host creates a public lobby, a second instance must find it via the game/ver filter
  - `tools/build.ps1` – import, export `build/Soizwoed.exe`, copy `steam_appid.txt` next to it
  - Run them with `powershell -NoProfile -ExecutionPolicy Bypass -File tools/<script>.ps1`
- Test runs must never disturb the user at the PC: prefer `--headless`. When a window is needed (screenshots), always run `godot --audio-driver Dummy -- ... --shots=<dir>`; `--shots` makes the window small in the screen corner, without focus, without mouse capture and muted.
- Before saying a task is done: run the tests and a headless smoke run, and fix any errors or warnings in the output.
