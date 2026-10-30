# Soizwöd – Game Design Document (v2: action redesign)

> "Soizwöd" = Austrian dialect for "Salzwelt" (salt world).
> A first-person co-op **action-horror extraction** game in a cursed Austrian salt mine.
> 1–4 players (co-op first, solo playable with lower difficulty). Windows build, Steam networking (App ID 480).

**Redesign note (owner decision 2026-10-30):** M1–M5 built a tension/avoidance game; playtesting found it boring. v2 keeps the setting, the dark, the procedural mines, the bring-it-back-to-the-lift loop and all creatures, and turns it into a game about **fighting your way to the shift's target and back out**, with scarce ammo, roguelite weapon upgrades and a few permanent upgrades. Everything that is not combat, enemies or progression stays as built (see §12, "What stays").

---

## 1. Pitch

The **Soizwöd GmbH** sends a crew of underpaid miners into a cursed salt mine. Every shift the company wants **one specific find** ("Fundstück") from somewhere deep in the mine. The crew goes down armed with whatever they could afford, fights through the creatures of Alpine folklore, finds the Fundstück – often guarded by a boss – and then has to **carry it back to the lift against the clock** while the whole mine comes after them. Loot found on the way pays for better guns and more ammo. Every shift the mine gets nastier. Fail once and you're fired ("Kündigung" = run over).

Tone: dark and tense, with absurd Austrian humour. **Lethal Company / R.E.P.O. with guns**: few but dangerous enemies, every bullet counts – not hordes.

### Design pillars
1. **Every bullet counts** – ammo is scarce, reloading takes time, a missed shot is a problem. Fights are short, sharp and dangerous.
2. **The way back is the real fight** – taking the Fundstück turns the mine against you: a timer, escalating spawns, enemies hunting the carrier.
3. **Friends make it work** – the carrier can't shoot, so the others escort; specials (Salzweibl, Kasermandl) need teammates; revives matter.
4. **Dark and Austrian** – the lamp is still your lifeline, and you still hear things before you see them; weapons, enemies and UI text lean into Alpine/Austrian culture and dialect.

---

## 2. Core Game Loop

```
Hub (Gasthaus)
  → spend money: weapons, ammo, run upgrades (Waffenkammer at the bar)
  → spend Ehrenzeichen: permanent upgrades (Knappenbrief on the wall)
  → pick the mine section (Grubnplan), descend in the Förderkorb
Shift in the mine
  → explore the procedural mine, fight creatures, pick up loot (money) and ammo
  → find the Fundstück (one per shift, deep in the mine, often guarded by a boss)
  → take it: ALARM – timer starts, the mine escalates, creatures hunt the carrier
  → bring it into the Förderkorb and ride up before the timer runs out
Back at the surface
  → loot is sold (money), the Fundstück is delivered (Ehrenzeichen)
  → next shift: harder
Fail (timer runs out, or the whole crew is dead) → Kündigung: run over
```

### The run
- A run is a chain of shifts, each harder than the last (§8). There is no money quota any more: **the quota is the Fundstück**. Every shift has exactly one; delivering it is the only way to keep your job.
- **Score** = shifts survived (plus money earned as a tie-breaker).
- **Roguelite:** weapons, ammo, run upgrades and money are lost when the run ends. **Ehrenzeichen** and the permanent upgrades bought with them stay (§7).

### Shift structure
1. **Descent and exploration** – no timer yet. A soft clock still runs (in-world clock, Grubenpfeife after ~12 min) so a crew can't farm loot forever: after the whistle the **Schichtmeister** starts roaming (§6).
2. **The Fundstück** – one per shift, spawned once in the deepest part of the mine (a dedicated "Fundort" chunk). From shift 2 on it may be guarded by a **boss** (chance and boss strength rise per shift; always from shift 4). With a boss alive, the Fundstück sits in a cage/salt shell that only opens when the boss is dead.
3. **Alarm** – picking it up starts the **Rückweg-timer** (starts at ~4 min, shrinks with difficulty, scales with mine size so it is always possible). The lift's bell rings through the mine. From now on:
   - extra waves spawn every ~30 s **between the crew and the lift**, and on their tracks;
   - every creature that hears the alarm knows where the carrier is (pulses like the old cursed relic);
   - the Fundstück is **medium/heavy**: its carrier has both hands full and **cannot shoot** (melee shove only). It can be dropped or **handed over** to a teammate (not thrown);
   - creatures **focus the carrier**: whoever holds the Fundstück is every creature's preferred target.
4. **Extraction** – the shift is won when the Fundstück is inside the Förderkorb and someone pulls the lever (riders go up; whoever is outside is left behind, see §3). The lift **cannot** go up without the Fundstück (except "aufgeben" = give up = run over).
5. **Timer runs out** – the lift goes up empty, the crew is fired. Run over.

---

## 3. Players

- First-person: walk / sprint (stamina) / crouch / jump / climb ladders and ropes. Unchanged.
- **Health:** 100 base (+ permanent upgrades). No regen; heal with consumables (Obstler, Leberkässemmel, Speckbrot) and the Erste-Hilfe-Tascherl.
- **Armour (new):** the Lederschurz / Grubenhelm upgrades absorb part of incoming damage until worn through; refreshed in the hub (bought per run).
- **Light:** carbide lamp (flame, ignites firedamp) or electric Stirnlampe. Lights still matter: the Kasermandl, darkness hiding enemies, muzzle flashes and flares.
- **Inventory (owner decision, M6 playtest):** keys **1–3 weapons** (guns, the Spitzhacke), **4 a throwable** (Böller, Rauchbombe, dynamite; a second one goes into a pocket), **5–9 everything else**; plus both hands for medium/heavy things (loot, the Fundstück). The mouse wheel skips empty slots. **Ammo does not take slots**: each ammo type is a counter with a carry cap (upgradable).
- **Shooting:** aim with the mouse, left click fires, right click aims down the sights (the gun comes up so notch and bead sit exactly on the screen centre, where the shots go; less spread, slower move), R reloads (magazine by magazine, or shell by shell for the shotgun, interruptible). Weapons have spread, recoil, damage falloff and a noise radius (gunfire draws listening creatures).
- **No hit markers (owner decision):** a hit shows on the creature – blood spraying, a flinch, its cry and a wet thud – not on the crosshair. In the dark you may not know whether you hit.
- **Friendly fire is on**, at 33 % of the damage to start with (owner decision 2026-10-30; `balance.tres`): watch where you shoot.
- **Downed and dead:** at 0 health a miner is **downed** for 20 s (crawls slowly, can shoot the pistol only). A teammate holding E for 3 s gets them up with 30 health. Downed again within the shift or bled out → **dead**: drops everything (weapons too – teammates can pick them up), spectates, comes back next shift with the starting kit and their permanent upgrades. The **Wunderheilerin-Salbe** still revives the dead (within 30 s of death).
- **Solo:** no downed state (nobody to help) – instead one free "Zweite Luft" per shift: at 0 health you stay at 1 and get 3 s of invulnerability.
- Left behind when the lift goes up = dead for the rest of the shift (unchanged).

---

## 4. The Mine (Levels)

Unchanged in principle: assembled at runtime from hand-made chunks by a seeded generator; only the seed is sent over the network.

| Section | Feel | Special | Unlocks |
|---|---|---|---|
| **Oberer Stollen** | Timber, rails, old lamps | Rail cart (carry the Fundstück on it!) | from the start |
| **Salzsee** | Huge echoing caverns, black lake | Ferry, things in the water | after shift 3 |
| **Die Tiefe** | Celtic workings, bones, the Mann im Salz | Lots of firedamp, no rails, best loot | after shift 6 |

- The crew picks the section on the **Grubnplan** before each shift. Deeper sections: more money and Ehrenzeichen, tougher enemy types, harder bosses. After shift 9 every shift is an "Überstund" (overtime) with stacking modifiers (§8).
- **New chunk role "Fundort":** the deepest dead end of the main path; holds the Fundstück and the boss arena (room to fight, cover, a second exit only in some layouts).
- **Generation for combat:** loops matter even more (kiting, flanking); a few more open rooms per section for fights; ammo and loot spawn points; spawn "Löcher" (holes in walls/floor) where waves emerge, never in sight of a player.
- **Hazards stay** and become tactical: firedamp blows up enemies too (shoot it from a distance with a flare), rockfall blocks pursuers, rotten bridges break under heavy enemies, brine slows everyone.

---

## 5. Loot, Ammo and the Fundstück

- **Loot** (salt crystals, Jausenbox, Grubenlampe, Kaiserliches Abzeichen, Steinsalz-Block, Bronzeschwert, Goldene Haube, Kuckucksuhr, Gamsbart-Hut, Stück vom Mann im Salz) stays as built: optional greed, sold for money in the hub. Carrying heavy loot means not shooting, like the Fundstück. The cursed Mann im Salz and the cuckoo clock keep drawing enemies.
- **Ammo** is found in the mine (old miners' lockers, Munitionskisten – a few per mine, more in deeper sections) and bought in the hub. Never enough to shoot everything.
- **Sharing ammo (owner decision):** G while looking at a teammate close by hands them half of your rounds of the type their gun takes (up to what they can carry).
- **Notration (owner decision):** a miner who is nearly out of ammo (every gun at 4 pistol rounds / 1 shell or less, magazine plus spare) finds a few rounds on every creature they kill (5 pistol rounds / 2 shells). Only then – with ammo left, kills drop nothing extra.
- **Fundstück** per section (examples; one per shift, the company's "Auftrag" on the notice board):
  - Oberer Stollen: the **Goldener Grubenkompass**, the **Kaiserliche Grubenuhr**;
  - Salzsee: the **Seekristall** (glows – lights the carrier, everything sees them);
  - Die Tiefe: the **Keltische Goldmaske**, the **Herz vom Salzmann** (cursed: heavier, louder pulses).
  Delivered, it pays Ehrenzeichen (§7) and a cash bonus.

---

## 6. Creatures

All host-authoritative AI. **Every creature can hurt the players and (except the Schichtmeister) can be killed.** Each keeps its learnable rule from v1 – the rule is now how you fight it well, not only how you avoid it. Fewer, more dangerous enemies: a typical fight is 1–4 creatures.

| Creature | Role | How it fights | How to beat it |
|---|---|---|---|
| **Grubenhund** (new) | Basic | Fast, mangy undead mine dogs in packs of 2–3; bite, then circle. The everyday enemy. | Short bursts, shotgun, stick together. 40 HP. |
| **Bergmandl** | Harasser | Throws stones from range, steals loot and **ammo** off the floor and from hands, runs off giggling. | Kill it (30 HP) to get the loot back; shout to make it drop things. |
| **Tatzelwurm** | Ambusher | Burrows, hunts by vibration (gunfire is a big vibration!), bursts out and bites hard. | Stand still → it surfaces → shoot the soft throat while it is up (armoured underground). |
| **Kasermandl** | Special | Only moves in darkness; touch drains health. **Can only be hurt while lit.** | One player keeps a light on it (it freezes), another shoots it. Flares are perfect. |
| **Salzweibl** | Special | Lures with a teammate's voice; grabs a lone miner and **pins** them (drains health, victim can't act). | A teammate shoots or shoves it off. Stick together. Lure stays as built. |
| **Percht** | Elite / boss | Huge, armoured, slow; bells announce it; charge attack that knocks down; roars to call Grubenhunde. | The mask is its weak spot (3× damage); everything else does little. Flank it. |
| **Der Schichtmeister** | Enforcer | After the whistle (or when the Rückweg-timer is nearly up) he hunts the crew. Very fast, one touch downs you. | Can't be killed – only stunned (Alphorn, flare to the face). Be quick. |

**Bosses** (guard the Fundstück, one per shift from shift 4, sometimes earlier):
- Oberer Stollen: **Da Bergkini** (the Bergmandl king) – throws dynamite, summons Bergmandl, hides behind loot piles.
- Salzsee: **D'Seemuada** – a giant Tatzelwurm in the lake; attacks from the water, surfaces to bite.
- Die Tiefe: **Die Schiachpercht** – the Percht as a boss: more health, a bell shockwave, a pack of Grubenhunde.

**Elites** (from shift 5): any creature can spawn as a "Raunacht" variant – more health, faster, glowing eyes, drops extra ammo.

Creature voices (unchanged rules): audio only, no text; lines per creature in its `.tres`; "Gegner reden" setting.

---

## 7. Weapons, Tools and Progression

### Weapons (bought in the Waffenkammer, lost when the run ends)
| Weapon | Ammo | Role |
|---|---|---|
| **Spitzhacke** | – | Melee (2 hits for a Grubenhund), breaks salt walls. Everyone gets one with the kit before each shift: the weapon that never runs out of ammo. |
| **Dienstpistole** (old k.u.k. service pistol) | Pistolenpatronen | Starting gun. 8 rounds, accurate, weak. |
| **Salzschrot-Flinte** | Salzschrot | Double-barrel shotgun with rock-salt shells: huge damage close up, knocks back, slow reload. |
| **Mannlicher-Stutzen** | Gewehrpatronen | Bolt-action rifle: very high damage, weak spots, slow; for elites and bosses. |
| **Leuchtpistole** | Leuchtkugeln | Flare gun: lights an area for 20 s (freezes Kasermandl), sets enemies and firedamp alight. |
| **Dynamit / Böller** | – (consumable) | Thrown; dynamite does big area damage (and brings the roof down), Böller distract. |
| **Alphorn** | – | Cone stun, alerts the whole mine. |

All other v1 tools stay (Stirnlampe, Schubkarre, Seil, Funkgerät, Pfeiferl, Rauchbombe, food and drink, Wunderheilerin-Salbe).

### Run upgrades (money, lost when the run ends)
Bought in the hub between shifts: per weapon (damage, magazine size, reload speed, spread), ammo carry caps, armour, lamp (range, battery), an extra pocket slot.

### Permanent upgrades (Ehrenzeichen, kept forever)
- **Ehrenzeichen** (company honours) are earned per delivered Fundstück (more for deeper sections and later shifts, a bonus for bosses) and kept after the run ends. Saved per player on their own PC (`user://profile.cfg`); in co-op each player brings their own.
- Spent on the **Knappenbrief** in the Gasthaus: +10 max health (×5), starting weapon (Flinte or Stutzen instead of nothing), starting ammo, starting money, armour at start, faster revive, one more pocket slot. Modest numbers – skill and the run's upgrades should matter more.
- Cosmetics (hats like the Gamsbart-Hut, lamp colours) can also be unlocked here.

---

## 8. Difficulty and Scaling

Difficulty rises **every shift** (`shift_index`, 0-based), on top of the section's base:
- enemy budget and the number of waves after the alarm;
- enemy health and damage multipliers;
- which types appear (Grubenhund and Bergmandl from shift 1; Tatzelwurm, Kasermandl from 2; Salzweibl from 3; Percht roaming from 6);
- boss chance (0 % → 100 % from shift 4) and boss strength;
- elite chance (from shift 5);
- Rückweg-timer gets shorter (relative to the distance to the lift);
- ammo found gets scarcer.
After shift 9: **Überstunden** – each shift adds a random modifier (no lanterns, double Bergmandl, faster timer, armoured Grubenhunde …).

**Player count** (co-op first, solo playable):

| Parameter | 1 player | 2 | 3 | 4 |
|---|---|---|---|---|
| Enemy budget | 0.45 | 0.7 | 0.85 | 1.0 |
| Enemy health | 0.7 | 0.85 | 0.95 | 1.0 |
| Boss health | 0.5 | 0.7 | 0.85 | 1.0 |
| Rückweg-timer | +40 % | +15 % | 0 | 0 |
| Ammo found | 1.2 | 1.0 | 0.9 | 0.8 (per player) |

Solo extras: no downed state but one "Zweite Luft" per shift; Salzweibl uses generic lines; free Schubkarre. All numbers live in `balance.tres`.

---

## 9. Multiplayer & Social Features

Unchanged from v1: Steam lobbies (friends-only by default), invites and in-game friends list, late join only in the hub, Funkgerät, emotes (Jodler, wave, point), host leaving ends the session.

**Proximity voice (reworked after the M6 playtest):** the game records the microphone itself (input and output devices chosen in the settings, with a level meter) and sends the voice over its own connection – it works over Steam and ENet alike. You hear a teammate from where they stand (3D), muffled through rock, and the further away they are, the more the mine throws their voice back as a long echo. Push-to-talk (V) or open mic. Dead talk only to the dead.

New: teammates' health/ammo shown small next to their names; "downed" teammates marked through walls; pings (middle mouse: "do!" marks a spot or enemy for 5 s).

---

## 10. Presentation

Visuals and audio as in v1 (realistic PBR, very dark, lighting as the main tool, no music in the mine). Additions:
- **Smooth movement:** physics interpolation, the camera placed every rendered frame (no stutter at any frame rate); no frame cap by default (VSync follows the screen).
- **Weapon feel (modelled on Berghittn):** gloved hands on the gun, kick and muzzle climb per shot, slide blowback and ejected casings, a visible muzzle flash that lights the tunnel for an instant (and gives you away), figure-8 bob when walking, a lowered sprint pose, lag behind mouse turns, a lean when strafing – nearly all gone while aiming. Shotgun shots shake the view. Reloads are animated (the pistol's magazine drops out and a new one goes in; the Flinte breaks open, throws out its hulls, takes shell after shell and snaps shut). Close to a wall the gun is pulled back and lowered instead of going into the rock. Aimed, the eye looks over the sights and the stock sits low under the cheek, out of view – nothing comes through the camera. The Spitzhacke is held in both hands and swung (the point strikes a moment into the swing).
- **Hits:** blood spraying out of a creature, its flinch and cry and a wet thud; salt dust on rock. No hit markers.
- **Audio:** guns use **real recordings** (CC0 "Free Firearm Sound Library", the same takes as Berghittn) plus the mine's own long rolling echo after every shot; gunfire is audible (and audible to creatures) far through the mine; the alarm bell; boss music stings are allowed (the only music in the mine). Footsteps are kept quiet.
- **Shop (Waffenkammer):** shelves as tabs with icons (Waffn, Munition, Zum Schmeißn, Jausn & Schnaps, Ausrüstung), the items as cards with their rendered picture, name, what they do and the price; the till on top, what you can't afford dimmed.
- **HUD (like other shooters):** a hotbar 1–9 with icons rendered from the items' own models and magazine counts, icon bars for health/lamp/breath, a large ammo counter, a crosshair that opens with the spread (hidden while aiming), a condensed modern font (Barlow Condensed).
- UI text in German dialect with English translation (both exist since M5).

---

## 11. Technology

Unchanged: Godot 4 + GDScript (static typing), Forward+, Windows desktop export, GodotSteam with App ID 480 and `game=soizwoed` / `ver=<version>` lobby tags, ENet backend for testing, `NetworkManager` autoload, host-authoritative world, client-authoritative movement.

Voice chat: recorded by the game (`Mic` autoload: `AudioStreamMicrophone` on a muted bus with `AudioEffectCapture`, the input device from the settings), 16 kHz mono, μ-law coded, sent in 40 ms packets as unreliable RPCs – the same for the Steam and the ENet backend. Played on an `AudioStreamPlayer3D` at the speaker's head, plus a distance-weighted send into a mine-echo bus.

Combat networking:
- The shooter's client decides what it hit (raycast/spread on its own screen, zero latency feel – co-op among friends, cheating is not a concern) and sends `request_hit(target, damage, hit_point, weak_spot)` to the host; the host applies damage (sanity-checked: range, rate of fire, ammo) and replicates health, staggers and deaths.
- Ammo and magazine counts are owned by the player (synced for the teammate HUD); the host only checks plausibility.
- Muzzle flashes, tracers and impacts are cosmetic RPCs to the other peers; gunfire noise goes through `Game.host_noise`.
- Enemy attacks (bites, thrown stones, charges) are decided on the host; projectiles are host-simulated and replicated.
- Data-driven as before: weapons are `WeaponData` resources (damage, fire rate, magazine, reload, spread, recoil, ammo type, noise, upgrades), enemies are `EnemyData` + spawn rules, bosses get their own scenes. All numbers in `balance.tres`.

Project structure as in v1, plus `weapons/` (weapon data, scenes, first-person models), `progression/` (run upgrades, permanent profile) and `enemies/bosses/`.

---

## 12. Milestones

M1–M5 (v1) are done: solo slice, ENet multiplayer, Steam, content, content 2 and polish.

### What stays from v1 (not rebuilt)
Networking (ENet, Steam, lobbies, voice), the mine generator and all chunks and sections, hazards, the lift and shift flow skeleton, items/loot/carrying/Schubkarre/rail cart, the Gasthaus hub and shop UI, settings (incl. keys and language), translations, the audio pipeline, the creature voices, tests and build scripts.

### What is replaced or rebuilt
The money quota (→ Fundstück), creature behaviour (→ attacking, killable), health/death (→ downed state, armour), the shop's contents (→ weapons/ammo/upgrades), balancing.

| # | Milestone | Done when |
|---|---|---|
| **M6** | Combat prototype | Shooting system (hitscan, spread, recoil, ADS, ammo counters, reload) with Dienstpistole and Salzschrot-Flinte; enemy health, hit reactions and deaths; **Grubenhund** (new) and **Bergmandl** (stones, steals ammo) attack; downed/revive; ammo pickups; ammo HUD; works in solo and over ENet. Playable in the Oberer Stollen – the owner judges if it is fun before we continue. |
| **M7** | The Fundstück loop | Fundort chunk per section, Fundstück, alarm + Rückweg-timer + waves, lift needs the Fundstück, failure = run over, money quota removed, per-shift difficulty scaling, Waffenkammer (weapons, ammo, run upgrades), first boss (Da Bergkini). |
| **M8** | All creatures fight | Tatzelwurm, Kasermandl, Salzweibl (pin), Percht, Schichtmeister reworked for combat; Mannlicher-Stutzen, Leuchtpistole, Dynamit; bosses for Salzsee and Die Tiefe; elites. |
| **M9** | Progression | Ehrenzeichen, Knappenbrief permanent upgrades with a saved profile, all run upgrades, Überstunden modifiers, teammate HUD and pings. |
| **M10** | Feel & balance | Weapon models/animations/sound pass, impact effects, boss stings, balancing of the whole run with playtests, translations. |

Work milestone by milestone; each ends in a playable Windows build.

---

## 13. Testing

As in v1 (GUT unit tests for pure logic, headless smoke runs and scripted scenarios, ENet multiplayer scripts, Steam tests need a human). New pure-logic tests: weapon math (spread, falloff, reload, upgrades), ammo economy, damage/armour/downed rules, difficulty curves per shift and player count, profile save/load. New scenarios: a shootout, the alarm and Rückweg, each boss, a revive over ENet.

---

## 14. Open Questions (decide during development)

- Exact Rückweg-timer and difficulty curve – tune in M7 playtests.
- Max player count: 4 fixed, or allow 6?
- Do run upgrades get bought only in the hub, or also found in the mine (rare "Werkzeugkisten")?
