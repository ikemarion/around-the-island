# Around the Island

A chaotic first-person chase game for up to four friends, built with Godot. Steal the spark, improvise around the kitchen island, and carry the chase into the living room and garage.

## Play

The current release is **ATI v0.62 for Windows**: [download ATI-v0.62-Windows.zip](https://github.com/ikemarion/around-the-island/releases/download/v0.62.0/ATI-v0.62-Windows.zip). Extract the whole folder and run `ATI-v0.62.exe`; Godot is not required. [Release notes and checksum](https://github.com/ikemarion/around-the-island/releases/tag/v0.62.0). Use v0.62 on everyone's PC for matching visuals and all fixes. The wire protocol remains 17.

- The configured host opens **Host lobby** and keeps Playit running.
- Friends open the same build and choose **Join lobby**. No codes or networking software are needed on their PCs.
- Wait until everyone is seated, then any admitted player can choose **Start match**.
- **Practice with a bot** works offline. Choose Sockling or Looper before playing; the bot rolls a random skin each round.

See [ONLINE-PLAY.md](ONLINE-PLAY.md) for the supported hosting arrangement and [NETWORK-RELIABILITY.md](NETWORK-RELIABILITY.md) for connection-report collection.

## v0.62 garage art update

- Reworked the garage around the approved coral-and-cream vintage car and warm, rounded kitchen reference: sculpted car body, cream cabin, detailed windows, wheels, lights and trim.
- Added sage inset workshop cabinets, wood-grain surfaces, perforated toolboard, recognizable hand tools, bench vise, enamel task lamp, parts bins and a few restrained tabletop details.
- Replaced the plain shutter with a paneled garage door, cream window frames, hinges, wood jambs and a lift handle. Resurfaced the garage floor and softened its parking markings.
- Rebuilt the movable tire, toolbox, paint can and rolling cart with matching materials and hardware.
- Added a localized garage fill light and lightweight 2× edge antialiasing. Static workshop details are batched by material and use less dense bevel geometry than the hero car.
- Preserved the original routes, collisions, four garage prop IDs, pickup markers, physics and multiplayer protocol. No full-height walls or additional obstacles were added.

[Actual in-game captures and design notes](docs/art/garage-refresh/README.md). This is game geometry rendered by Godot, not a replacement concept image.

## Included v0.61 maintenance fixes

- Restores the intended unlimited ENet host bandwidth after an engine argument mismatch could impose a five-byte/second incoming cap. Controlled local packet delivery improved; a new remote playtest is still required.
- Repeated network acknowledgements no longer immediately cancel a guest's slide or snap them backward; genuine resynchronization remains bounded.
- Failed report saves remain pending, and normal lobby waiting no longer creates false failed-probe counts.
- Guests see charged-throw feedback; stuns cancel slide propulsion.
- Start/Options opens the session menu; B/Circle dismisses it. Small windows keep readable controls and scroll instead of shrinking the interface.
- Character footwork and start/stop/landing transitions are smoother without changing hitboxes or movement tuning.
- Player exports omit tests and reference artwork. Tests have a repeatable runner with deadlines and failure detection; development exports retain the test suite.

The latest local connection checks do not establish Internet/Playit reliability. No tunnel, router or firewall configuration is changed by this update.

## Controls

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Move / look | WASD / mouse | Left / right stick |
| Jump | Space | A / Cross |
| Crouch; slide when moving quickly | Shift | Left stick press |
| Hold an obstacle; release to drop | Hold E | Hold X / Square |
| Shove; hold/release to charge/throw a held obstacle | M1 | RT / R2 |
| Pull an obstacle | M2 | LT / L2 |
| Use a power-up | Q | RB / R1 |
| Charged chaser boost | F | LB / L1 |
| Restart, host or solo only | R | Hold Y / Triangle for one second |
| Session menu / resume | Escape | Start / Options; B / Circle dismisses |
| Optional radial camera | V | — |

The stun gun takes firing priority over empty-handed shoving. The session menu does **not** pause multiplayer; leaving as host closes the room for everyone. Scores freeze after 75 seconds, but everyone can keep moving until the next round.

## Develop and test

Import `project.godot` into Godot 4.7.2 and press F5. Source files are the live Godot project; a Windows ZIP is a separate, exported copy and must be rebuilt after changes.

[Testing instructions](tools/TESTING.md) cover the one-command suite, focused checks and network fixtures. Use **Windows Desktop** for a player build and **Windows Tests** for a resource pack run through the debug engine. Do not distribute test packs to friends. `pwsh -File tools/package_windows.ps1` runs the full source suite, exports the Windows game, and creates a local ZIP plus SHA-256 checksum; it does not publish anything.

The source map:

- `scripts/main_networked.gd` — session coordination, replication, scoring and round flow.
- `scripts/player.gd` — movement, prediction, interactions and abilities.
- `scripts/match_menu.gd`, `scripts/kitchen_menu.gd` — in-match and lobby presentation.
- `scripts/sockling_motion.gd` — shared character animation; the individual art scripts preserve each character's look.
- `scripts/report_transfer.gd`, `scripts/network_diagnostics.gd` — bounded diagnostic collection and transfer.
- `scenes/rooms/`, `scripts/house_navigation.gd` — modular house and navigation; see [MAP-MODULES.md](MAP-MODULES.md).

## Release hygiene

Keep future ZIPs as local build outputs or GitHub Release assets, not source-history additions. Existing tracked releases are retained; no history is rewritten by this cleanup. The user requested this v0.62 publication on September 25, 2026; future automatic publishing remains paused. The release targets verified game commit `054709d`; later publishing-documentation commits do not change that executable.

Earlier design decisions and prototype changes are preserved in [historical README notes](docs/history/README-through-v060.md) and [historical network notes](docs/history/NETWORK-through-v060.md). Their old version-specific instructions are not the current playbook.
