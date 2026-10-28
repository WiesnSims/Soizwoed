# Design Decisions

Decisions on questions not (or not clearly) answered in `DESIGN.md`. Newest at the bottom.

## 2026-10-28 – Pre-M0 clarifications

### Confirmed by the owner
- **DESIGN.md location:** moved to `docs/DESIGN.md` (as referenced by CLAUDE.md).
- **Left behind / death during a shift:** the player is out for the rest of that shift and rejoins at the start of the next shift. Carried loot is lost, no other penalty. Solo: the shift ends, unbanked loot is lost, the run continues with the next shift. (DESIGN.md §2 updated; it previously said "rest of the cycle".)
- **Solo without Steam:** solo runs with no network transport at all (`OfflineMultiplayerPeer`, host = peer 1), so it works when Steam is not running. Steam is only required for hosting/joining online lobbies.
- **"Plärren" key:** a shout input that has the same in-game effect as a loud voice (scares Bergmandl, attracts Tatzelwurm). Makes the mechanic available before voice chat (M3) and for players without a microphone.
- **Berghittn reference:** the earlier project lives in `X:\Code\Projects\GeilesGame`. It may be read for reference; nothing is copied from it without telling the owner first.

### Chosen by Claude (change any time)
- **Base shift length:** 13 min, plus the solo/duo bonus from §8. Value lives in `balance.tres`.
- **Base quota:** set during M1 playtests, lives in `balance.tres`.
- **Medium items:** carried in the hands (like heavy items, but at normal speed). The 4 inventory slots hold light items and tools only.
- **Build version:** `application/config/version` in `project.godot`; it is also the `ver` lobby metadata value.
- **Max players:** a single constant (default 4) so 6 stays possible.
- **Salzweibl voice lure:** a setting lets players opt out of having their voice recorded for it (the creature falls back to generic lines).
