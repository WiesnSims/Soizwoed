# Soizwöd – Game Design Document

> "Soizwöd" = Austrian dialect for "Salzwelt" (salt world).
> A first-person co-op extraction horror-comedy in a cursed Austrian salt mine.
> 1–4 players (solo fully supported, more fun with friends). Windows build, Steam networking (App ID 480).

---

## 1. Pitch

The **Soizwöd GmbH**, a dubious salt company from the Salzkammergut, sends a crew of underpaid miners into a long-abandoned salt mine. The mine is full of valuables (salt crystals, old miners' gear, Celtic artefacts, things that should not exist) and full of creatures from Alpine folklore that do not want you there.

Each shift: ride the mine cart down, find loot, drag it back to the lift before the shift whistle, sell it to make the quota. Miss the quota and you're fired ("Kündigung" = game over).

Tone: dark and genuinely tense, interrupted by absurd Austrian humour. Think Lethal Company / R.E.P.O. meets Hallstatt tourist brochure meets Krampus.

### Design pillars
1. **Tension through darkness and sound** – your lamp is your lifeline; you hear things before you see them.
2. **Friends make it chaos** – proximity voice, carrying heavy stuff together, rescuing (or abandoning) each other.
3. **Solo is a real mode** – harder and lonelier, never impossible.
4. **Austrian absurdity** – tools, enemies, loot and UI text all lean into Alpine/Austrian culture and dialect.

---

## 2. Core Game Loop

```
Hub (Gasthaus / Firmenbüro)
  → buy tools with money from last shift
  → pick mine section (later unlocks)
  → descend in the Förderkorb (lift cage)
Shift in the mine (~12–15 real minutes)
  → explore procedurally assembled tunnels
  → find & carry loot back to the Förderkorb
  → avoid/handle creatures and hazards
  → the shift whistle blows → get out or stay down forever
Back at the surface
  → loot is valued and added to the quota
  → after 3 shifts: quota check → pass (higher quota next round) or fired (run ends)
```

### Quota cycle
- A run = consecutive quota cycles until failure. Score = cycles survived + total money.
- Quota rises each cycle (e.g. base × 1.4^cycle, tune in playtests).
- Money not used for the quota can be spent on tools in the hub.

### Shift timer
- In-world clock on the Förderkorb and on a pocket watch item.
- At "Schichtende" the **Grubenpfeife** (whistle) blows. 60 s grace period, then the lift goes up without anyone not standing in it.
- Players left behind (or killed) are out for the rest of that shift. They rejoin at the start of the next shift; the loot they carried is lost, no other penalty. In solo this means the shift ends, its unbanked loot is lost, and the run continues with the next shift.

---

## 3. Players

- First-person, walk / sprint (stamina) / crouch / jump / climb ladders.
- **Health:** 100. No regen; healing via consumables.
- **Light:** each player has a Karbidlampe (carbide lamp) with limited fuel. Refill at lift or with items. Light level directly affects enemy behaviour (some are attracted, some repelled).
- **Inventory:** 4 small slots + both hands for one heavy object.
- **Heavy loot:** some loot is too heavy to carry fast alone (sprint disabled, slow walk). Two players carrying together move normally. Solo players use the Schubkarre (see tools).
- **Death:** ragdoll, drop all items. Dead players spectate living teammates (cycle through cameras). A body carried back to the lift gives a small "Sterbegeld" bonus.
- **Revive:** none in base design (keeps stakes high). Optional item: "Wunderheilerin-Salbe", rare, revives within 30 s.

---

## 4. The Mine (Levels)

Mines are assembled at runtime from **hand-made modular room/tunnel chunks** (Godot scenes) using a seeded generator. Only the seed is sent over the network; every client builds the identical layout.

### Biomes (unlocked over time)
| Biome | Feel | Special mechanic |
|---|---|---|
| **Oberer Stollen** (upper tunnels) | Wooden supports, rails, old lamps | Mine carts on rails can be pushed for transport |
| **Salzsee** (brine lake caverns) | Huge echoing caverns, underground lake | Small boat to cross water; things in the water |
| **Die Tiefe** (the deep) | Ancient Celtic workings, bones, the "Mann im Salz" | Gas pockets, no rails, best loot |

### Hazards
- **Schlagende Wetter** (firedamp gas pockets): visible as faint shimmer; an open flame (carbide lamp) can ignite it → explosion. Turn lamp off to pass (darkness!).
- **Steinschlag** (rockfall): creaking warning sound, then debris. Can block corridors.
- **Rotten ladders and floors**: break under heavy weight (carrying a salt block across a weak bridge is a bad idea).
- **Sole** (brine): slows movement, damages equipment.

### Generation rules (for the generator)
- Start chunk = Förderkorb station. Always reachable exit.
- Graph-based: main path + loops + dead ends. Loops are important for escaping enemies.
- Each chunk has tagged connectors (size, type: tunnel/shaft/water) and spawn points (loot, enemy, hazard).
- Difficulty parameter (cycle number + player count) controls depth, loot value and enemy budget.

---

## 5. Loot

Each item: value range, weight class (light / medium / heavy), optional special behaviour.

| Item | Weight | Notes |
|---|---|---|
| Salzkristall (salt crystal) | light | Common, low value |
| Steinsalz-Block | heavy | High value, 2 players or Schubkarre |
| Alte Jausenbox | light | Opening it may contain a 100-year-old Speckbrot (consumable, small heal, chance of food poisoning) |
| Grubenlampe (antique) | medium | Fragile – value drops when dropped |
| Kaiserliches Abzeichen | light | Rare, high value |
| Keltisches Bronzeschwert | medium | Can be used as a weak weapon |
| Goldene Haube | medium | Rare, very high value |
| Kuckucksuhr | medium | Randomly cuckoos loudly – attracts enemies |
| Gamsbart-Hut | light | Fun item, wearable cosmetic, low value |
| Stück vom "Mann im Salz" | heavy | Cursed: carrying it slowly draws enemies; huge value |

Fragile items lose value on impact (physics velocity threshold).

---

## 6. Creatures (Alpine folklore)

All enemies are **host-authoritative AI**. Each has a clear, learnable rule so experienced players can outplay them.

| Creature | Behaviour | Counter |
|---|---|---|
| **Bergmandl** (mine gnome) | Small, fast, in groups. Steals loot from the floor and from hands, runs off giggling. Not deadly alone. | Shout at them (voice volume, or the "Plärren" key) or hit them; they drop loot. |
| **Tatzelwurm** | Burrows through salt walls. Hunts by vibration – sprinting and dropping heavy objects attract it. | Walk slowly, stand still. |
| **Kasermandl** | Ghostly old herder. Only visible in darkness. Freezes when lit. | Keep a light on it (weeping-angel rule). Problem with gas pockets! |
| **Salzweibl** | Lures players with a familiar voice (plays back a snippet of a teammate's real voice chat). | Stick together, use names. |
| **Der Schichtmeister** | Ghost of a dead foreman. Appears after the whistle if players are still down. Very fast, deadly. | Be at the lift on time. |
| **Percht** (deep biome only) | Large, slow, near-unkillable; patrols. Bells announce it. | Avoid, hide, distract with noise. |

Enemy spawn budget scales with player count and cycle (see §8).

### Creature voices (user request 2026-10-28, like Berghittn's "Gredn")
Creatures talk: short lines in Austrian dialect, heard only – **no text on screen at all** (no labels, no subtitles). In the dark mine a voice is first of all a warning: you hear a creature before you see it, so the lines are positional 3D audio, muffled through walls like proximity voice.

- **Who talks:**
  - **Bergmandl** – giggles plus cheeky lines when it spots loot, steals, runs off or gets shouted at ("Des g'hert jetzt mir!", "Hihi, z'langsam!", "Ned so laut!").
  - **Kasermandl** – whispers and mutters only while it is in darkness; when lit it falls silent. Silence = your light is on it.
  - **Der Schichtmeister** – a booming foreman who announces himself after the whistle ("Schicht is aus! Wer is no do unten?!").
  - **Percht** – growls and grunts under its bells, a word or two at most.
  - **Tatzelwurm** – no words, only scraping and hissing.
  - **Salzweibl** – unchanged (§6, §8): teammate voice snippets, generic lines in solo.
- **Moments:** spotting a player, idle muttering while unseen, special actions (stealing, lunging, freezing), being hit, dying/fleeing. Each with its own chance and cooldowns (per creature and global) in `balance.tres`.
- **Network:** the host picks the line and sends a small line id; every peer plays the same sound locally.
- **Voices:** every line is spoken by **eSpeak NG** on the dev machine (never shipped) and run through a filter per creature type, generated by a Python script in `tools/audio/` (as in Berghittn). Only the resulting `.ogg` files ship.
- **Sample check:** before a creature's voice is final, a sample pack with several filter variants per creature goes to the user, who picks the best one.
- A setting "Gegner reden" (on by default) turns the lines off; giggles, growls and other non-speech sounds stay, since they are gameplay cues.
- Lines are data: each creature's `.tres` lists its lines (id, moment, sound file).

---

## 7. Tools (bought in the hub)

| Tool | Effect |
|---|---|
| **Karbidlampe** | Default light. Flame! Ignites gas. |
| **Elektrische Stirnlampe** | Upgrade: no flame (safe in gas), battery instead of fuel. |
| **Spitzhacke** | Melee, breaks salt walls for shortcuts/loot. |
| **Schubkarre** | Wheelbarrow – carry 1 heavy or 3 medium items at near-normal speed. Essential solo tool. Loud on rails/gravel. |
| **Seil & Kletterhaken** | Place rope on ledges/shafts for vertical shortcuts. |
| **Alphorn** | Callback to Berghittn: deafening blast, stuns enemies in a cone, alerts everything else in the mine. |
| **Böller** (firecrackers) | Throwable distraction. |
| **Funkgerät** (walkie-talkie) | Talk beyond proximity range. Static near creatures. |
| **Obstler** (schnapps) | Heals 25, screen wobbles for 20 s. |
| **Leberkässemmel** | Heals 40, takes 4 s to eat. |
| **Grubenhund-Pfeiferl** | Calls a mine cart along the rails to you. |
| **Rauchbombe "Bierzelt"** | Smoke cloud that smells so bad creatures avoid the area. |

Tools are persistent for the run, lost when the run ends.

---

## 8. Solo vs. Multiplayer Scaling

Solo is just "host with no other players" – same code path. Values scale with `player_count` (1–4):

| Parameter | 1 player | 2 | 3 | 4 |
|---|---|---|---|---|
| Quota multiplier | 0.45 | 0.65 | 0.85 | 1.0 |
| Enemy budget | 0.5 | 0.7 | 0.85 | 1.0 |
| Loot density | 0.6 | 0.75 | 0.9 | 1.0 |
| Shift length | +2 min | +1 min | 0 | 0 |

Solo extras:
- Starts each run with a free Schubkarre.
- Salzweibl voice-lure uses generic voice lines instead of teammate audio.
- Heavy loot only slightly slower in solo when using the Schubkarre.

All numbers live in a single config resource (`balance.tres`) so they can be tuned without code changes.

---

## 9. Multiplayer & Social Features

- **Lobby:** host creates a Steam lobby (friends-only by default), friends join via Steam overlay invite or an in-game friends list. Max 4 players (keep design open for up to 6).
- **Late join:** only allowed in the hub, not during a shift.
- **Proximity voice chat:** volume by distance, muffled through walls (raycast), slight cave reverb. Dead players can talk to each other only. Push-to-talk and open mic options.
- **Voice volume as mechanic:** shouting scares Bergmandl, but loud voices attract the Tatzelwurm.
- **Emotes:** wave, point, "Jodler" (yodel – audible far, attracts enemies).
- **Host leaves:** session ends, everyone returns to main menu with a message (no host migration in v1).

---

## 10. Presentation

### Visuals
- **Realistic and beautiful** (user decision 2026-10-29): a native Windows x64 game can and should look much better than browser-only Berghittn. High-resolution PBR photo textures (CC0, albedo + normal + roughness/AO, height where it helps; 1K–2K), trilinear/anisotropic filtering, real geometry detail (round timber posts, rails, sleepers, rubble) instead of flat boxes.
- Very dark mine; lighting is the main visual tool: flickering lamp light with soft real-time shadows, volumetric fog/dust in the light, SSAO/SSIL for contact shadows and bounce, subtle glow, filmic tonemapping, a little exposure adaptation. Wet, slightly glossy salt rock that catches the lamp light.
- Hub: cosy wood-panelled Gasthaus with stove, Herrgottswinkel, notice board with the quota.

### Audio
- Footsteps per surface, wood creaking, dripping brine, distant rumbles.
- Each creature has a distinct audio signature (giggles, bells, scraping, cuckoo) and most also speak dialect lines – audio only, never shown as text (see §6 "Creature voices").
- Music only in the hub (Stubenmusi / accordion), silence in the mine.

### UI & language
- In-game text in German with Austrian dialect flavour (e.g. "Schicht aus!", "Quote ned gschafft – Kündigung!"). Use Godot's translation system (CSV) from the start so English can be added.
- Code, comments and identifiers in English.

---

## 11. Technology

### Engine & language
- **Godot 4** (latest stable 4.x), **GDScript** with static typing.
- Forward+ renderer (desktop only, no web target).
- Target: **Windows desktop** export.

### Networking
- Godot high-level multiplayer API (`MultiplayerSpawner`, `MultiplayerSynchronizer`, RPCs).
- **Host-authoritative** for world state: AI, loot, doors, hazards, quota, shift timer, physics objects.
- **Client-authoritative movement** for each player's own character (co-op game among friends, cheating is not a concern; gives zero-latency movement). Host validates nothing beyond sanity bounds.
- Held items are "owned" by the holding player while held; ownership returns to host on drop.
- World generation: host picks seed, sends it via RPC, all peers generate locally. Loot/enemy spawns are spawned by host via `MultiplayerSpawner`.
- Sync rates: player transforms ~20 Hz with interpolation; AI ~10–20 Hz; rare events via reliable RPCs.

### Transport layer – two interchangeable backends
Abstract behind a `NetworkManager` autoload with a common interface (`host()`, `join(target)`, `leave()`, signals for peers):

1. **SteamBackend** (production): **GodotSteam** addon with its Steam multiplayer peer.
   - Use **App ID 480 (Spacewar)** – `steam_appid.txt` containing `480` next to the executable and in the project root for editor runs.
   - Lobbies via Steam Matchmaking. Because App ID 480 is shared by many developers, **tag every lobby** with metadata `game=soizwoed` and `ver=<build version>` and **filter** lobby searches on both. Prefer friend invites (`join_requested` / overlay invites).
   - Steam relay handles NAT – no port forwarding.
2. **ENetBackend** (development & testing): plain `ENetMultiplayerPeer` on localhost.
   - Allows running multiple instances on one PC **without Steam** (Steam cannot run two instances with the same account).
   - Selected via command line: `--net=enet --host` / `--net=enet --join=127.0.0.1`. Default is Steam.

### Voice chat
- Steam voice via GodotSteam's voice functions (record → send compressed packets over unreliable channel → decompress → play on an `AudioStreamPlayer3D` attached to the speaker's head).
- ENet backend: voice disabled or via `AudioEffectCapture` (nice-to-have, not required).

### Suggested project structure
```
soizwoed/
├─ CLAUDE.md
├─ docs/DESIGN.md
├─ project.godot
├─ steam_appid.txt          # "480"
├─ addons/godotsteam/
├─ autoload/                # NetworkManager, GameState, Balance, Audio
├─ net/                     # steam_backend.gd, enet_backend.gd
├─ player/                  # player.tscn, controller, inventory, voice
├─ world/
│  ├─ generator/            # seeded mine generator
│  ├─ chunks/               # modular tunnel/room scenes per biome
│  └─ hazards/
├─ enemies/                 # one folder per creature
├─ items/                   # loot & tools (Resource-based definitions)
├─ hub/
├─ ui/
├─ i18n/                    # translations CSV
├─ tests/                   # GUT tests
└─ tools/                   # build/export scripts
```

Items, tools and enemies should be **data-driven** (custom `Resource` types) so new content is mostly new `.tres` files.

---

## 12. Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | Project setup | Godot project, folder structure, autoloads, GUT installed, Windows export preset, build script works |
| M1 | Solo vertical slice | One biome (Oberer Stollen), generator with ~8 chunks, player controller, lamp, 5 loot items, carrying, lift + shift timer + quota, hub with shop, 1 enemy (Bergmandl) |
| M2 | Multiplayer via ENet | 2–4 local instances play M1 together: synced players, loot, enemy, carry-together, spectate on death |
| M3 | Steam | SteamBackend with App ID 480, lobby create/filter/join, friend invites, proximity voice |
| M4 | Content | All tools, Tatzelwurm, Kasermandl, Schichtmeister, hazards, Salzsee biome |
| M5 | Content 2 & polish | Die Tiefe, Salzweibl, Percht, audio pass, balancing, settings menu, translations |

Work milestone by milestone. Each milestone should end in a playable Windows build.

---

## 13. Testing

- **Unit tests** with GUT for pure logic: generator (same seed → same layout, all chunks connected, exit reachable), quota math, balance scaling, inventory.
- **Headless smoke test:** run the game headless for N seconds, fail on script errors.
- **Local multiplayer test:** script that launches one host + N clients via ENet and checks they connect and the shift starts.
- **Steam tests require a human:** the Steam client must be running and a second Steam account (a friend) is needed. Claude Code should prepare the build and then clearly ask the user to test, with a short checklist of what to try.

---

## 14. Open Questions (decide during development)

- Exact quota curve and shift length – tune in M1/M2 playtests.
- Whether a rare revive item stays in.
- Max player count: 4 fixed, or allow 6?
- Persistent unlocks between runs (cosmetics like hats) – yes/no?
