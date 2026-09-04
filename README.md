# Around the Island

A chaotic first-person chase game for up to four friends, built with Godot. Steal the spark, improvise around the kitchen island, and use disruptive power-ups to turn every route into a bad decision.

## Play the current Windows build

Download the newest Windows ZIP from this repository's **Releases** page, extract it, and run the included ATI executable. Everyone must use the same version.

The configured host opens **Host lobby** and keeps Playit running. Friends choose **Join lobby**; no code or additional networking software is required. See [ONLINE-PLAY.md](ONLINE-PLAY.md) for the current hosting limitations and troubleshooting notes.

## Open and run

1. Launch Godot 4.7 or newer.
2. Import `project.godot` from this folder.
3. Press **F6** to run the current scene or **F5** to run the project.

The Steam installation on this machine is currently Godot `4.7.2`.

## Controls

| Player | Keyboard | Controller |
| --- | --- | --- |
| Player 1 | WASD | First connected gamepad, left stick |
| Player 2 | AI controlled | Chases while you hold the spark; flees while it holds the spark |

- Press **R** to reset the round.
- Press **Space** or gamepad **A** to jump.
- Hold **Shift** or press the left stick to crouch.
- Press crouch while moving quickly to begin a momentum slide.
- Hold **E** or gamepad **X** while aiming near a highlighted chair to grip it; release to drop it.
- While gripping a chair, press **left mouse** or the right trigger to throw it.
- Press **Q** or the right bumper to drop a slippery patch at your feet.
- Look with the **mouse** or **right stick**.
- Press **V** to switch between first-person and radial views.
- Press **Escape** for Resume / Leave Room. The match continues while this menu is open; leaving as host closes the room for everyone.
- The glowing player holds the spark and earns points over time.
- Touch the glowing player to steal the spark.
- Run into the colored blocks to shove them into routes.

First-person is now the default. The previous radial follow camera remains available with **V** for quick comparison. Movement stays camera-relative in either view. Player 2 is an arena-aware bot, so only one keyboard or gamepad is required.

## What to observe

Do not judge the art. Watch for these behaviors:

1. Players fake direction changes without being taught to.
2. Players commit to a route and regret it.
3. The colored obstacles are used intentionally.
4. A tag produces an immediate attempt at revenge.
5. Players ask for another round.

If both players merely mirror one another around the island forever, tune movement and route-breaking before adding more content.

## Learning map

- `scenes/main.tscn` — the arena, camera, lighting, players, and HUD
- `scenes/player.tscn` — one reusable player scene
- `scripts/player.gd` — input, acceleration, reversal commitment, gravity, and pushing
- `scripts/main.gd` — timer, scoring, tag transfer, and round reset
- `scripts/follow_camera.gd` — smooth world-space camera tracking for Player 1

Suggested first experiments:

1. Change `max_speed` and `reverse_acceleration` in `scripts/player.gd`.
2. Resize the island in `scenes/main.tscn`.
3. Move the colored obstacles to different routes.
4. Change `TAG_COOLDOWN` and `ROUND_DURATION` in `scripts/main.gd`.

## Intentionally deferred

Online multiplayer, finished characters, multiple arenas, progression, extra items, and more than two players are outside this first proof-of-fun test.

## Prototype 02 changes

- Player 2 now chases Player 1 when Player 1 has the spark.
- Player 2 selects distant escape points and routes around the island when it has the spark.
- The bot uses a small visibility graph around the centerpiece rather than a navigation mesh.
- The camera smoothly follows Player 1 while retaining the elevated prototype angle.

## Prototype 03 changes

- The camera now orbits automatically so Player 1 stays between it and the island center.
- Player 1 movement is camera-relative to keep controls intuitive while the view rotates.
- The arena now contains four independently shoveable obstacles.
- All obstacles return to their authored positions when the round resets.

## Prototype 04 changes

- First-person is now the default camera mode, with mouse and right-stick look.
- **V** toggles back to the radial follow view.
- Player 1's capsule, name, and spark marker are hidden locally in first-person.
- The island counter is now approximately waist height.
- Shoveable obstacles are lighter, less damped, and receive a stronger force from player contact.

## Prototype 05 changes

- Increased the camera FOV from 52° to 82°.
- Added jumping on **Space** or gamepad **A**.
- Added crouching on **Shift** or the left-stick button with a lowered collider and camera.
- Pressing crouch at speed starts a short momentum slide with limited steering.
- Sliding carries extra speed into shoveable obstacles.
- Round reset now uses **R** only.

## Prototype 06 changes

- Increased first-person FOV from 82° to 100°.
- Increased obstacle linear damping from 1.8 to 3.2 so chairs still shove easily but coast for less time.
- Added an invisible player-only blocker above the waist-high island.
- Chairs continue to collide with the visible counter but ignore the no-hop blocker.
- Began specifying a lightweight physical interaction system before implementing inventory or item content.

## Prototype 07 changes

- Fixed runaway acceleration when standing on a chair by ignoring floor-contact pushes.
- Side contacts now push chairs along the collision normal using actual impact speed.
- Added an 8 m/s defensive horizontal speed cap to every chair.
- Removed the screen-space timer and numeric score strip.
- Added a large world-space countdown above the counter.
- Added opposing blue and pink score lines that grow across the counter and meet at the final possession split.
- Locked **E** for physical interaction and **Q** for quick items in the interaction design.

## Prototype 08 changes

- Raised the world countdown and increased its font from 140 to 220.
- Increased physical score-line height from 0.075 to 0.18 meters.
- Added forgiving chair targeting with a world-space `[E] GRAB` prompt.
- Holding **E** or gamepad **X** grips a chair using a spring force in front of the camera.
- Releasing Interact drops the chair with its existing momentum.
- Held chairs temporarily ignore collision with their holder while continuing to collide with the arena and bot.

## Prototype 09 changes

- Increased chair grab reach and widened the forgiving aim cone.
- Strengthened the grip spring and raised the safe chair speed cap from 8 to 12 m/s.
- Added deliberate chair throwing on left mouse or right trigger.
- Added the first quick item: a bright slippery patch deployed with **Q** or right bumper.
- Slicks last 8 seconds, affect their owner and the bot, preserve momentum, and sharply reduce steering and braking without stunning.
- Added a four-second item cooldown with a lower-right ready indicator.

## Prototype 10 changes

- Replaced the plain slick cooldown text with a bordered item card, key prompt, readiness message, and animated recharge bar.
- Added synthesized placeholder audio without external assets or licensing dependencies.
- Added distinct effects for jumping, sliding, grabbing, throwing, deploying and entering slicks, tag transfers, item recharge, and round end.
- Player effects are spatialized in 3D; match events use a centered non-positional audio player.

## Prototype 11 changes

- Added the first world item source: a glowing spawn pad on the southwest route.
- The pad supplies a one-shot stun gun and visibly counts down its ten-second restock.
- Walking over the gun loads it into the quick-item card; **Q** or right bumper fires along the first-person aim and then consumes it.
- Counters, walls, and moveable props block the shot. A direct player hit produces a short 1.05-second stun rather than an elimination.
- Added tracer, color-flash, HUD, status-message, and synthesized sound feedback for pickup, firing, and impact.
- The regular slick remains the fallback quick item whenever no spawned item is held.

## Prototype 12 changes

- Added a centered aiming crosshair that appears only while the one-shot stun gun is loaded.
- The bot now detects moveable props in its route and jumps over them when it is grounded.
- Power-up pads relocate among four safe arena corners whenever a new item appears, avoiding immediate location repeats.
- The spawner alternates stun guns with a new one-shot slowing-field pickup so both effects appear consistently during playtests.
- Deploying a slowing field creates a large seven-second zone that reduces either player's speed to 48% while they remain inside.
- Added purple field, pickup, HUD, player-tint, status-message, and synthesized sound feedback.

## Prototype 13 changes

- Removed the slowing-field pickup and returned the mobile power-up source to stun guns only.
- Reduced the stun crosshair from 36 pixels to 16 pixels.
- Made the crosshair and every visual child ignore mouse events, fixing lost first-person mouse look while the gun is equipped.
- Added regression coverage for reticle size, input transparency, visibility after firing, and relocated stun-gun respawns.

## Prototype 14 changes

- Added a small floating gold crown above the physical score line of the player currently in the lead.
- The crown spins, gently bobs, switches sides with the lead, and hides during ties.
- Added left mouse as a second stun-gun fire input while retaining **Q** and right bumper.
- Left mouse still throws a held chair and will not accidentally spend the stun gun on the same click.

## Prototype 15 changes

- Expanded the mobile spawn source into a shuffled power-up bag. Stun gun remains the guaranteed first spawn; all six experimental items appear once before their pool repeats.
- **Air Horn:** A forward blast pushes both players and loose chairs without stunning them.
- **Swap Bell:** Exchanges the player and bot positions and current velocities.
- **Springboard:** Places a visible one-use pad that launches the first player to cross it.
- **Rewind Watch:** Restores the user's position and velocity from roughly two seconds earlier.
- **Chair Cannon:** Selects a visible chair near the aim direction and launches it forward at high speed.
- **Emergency Door:** Opens a ten-second two-way doorway to the mirrored side of the island; players and chairs can travel through it.
- Added item-specific pickup colors, HUD states, status feedback, synthesized sounds, round cleanup, and gameplay coverage.

## Prototype 16 changes

- Added a host/join lobby for one host and up to three remote friends, with every participant using their own first-person camera.
- Added compact room codes that encode the host address and UDP port, plus direct `IP:PORT` joining for LAN troubleshooting.
- Added automatic UPnP port-forward attempts and a clear manual UDP `27888` fallback when the router cannot be configured automatically.
- Added a free Playit UDP-tunnel fallback so only the host needs networking setup; friends can join with the public Playit address.
- Made the host authoritative for movement, tags, scoring, chairs, pickups, and power-up effects.
- Split network snapshots into player/match and world-item channels to stay below unreliable-packet limits.
- Expanded the physical scoreboard to four colored lanes and kept the floating crown on the current leader.
- Preserved the complete power-up pool, including synchronized pickup state, invisibility, and temporary slick and emergency-door visuals.
- Added a Windows export preset and an online-play handoff guide.

## Prototype 17 changes

- Added a kill box below the arena that returns fallen players to their assigned spawn point.
- Increased the air horn impulse from `9.5` to `15.0` for a more dramatic route-breaking blast.
- Removed the springboard from the power-up pool and deleted its unused world-object resources.
- Added a five-second invisibility pickup with opponent-hidden body, name, and spark marker, a countdown HUD, activation sound, and multiplayer synchronization.

## Prototype 27 changes

- Removed the large countdown from the tabletop while retaining all four physical score bars, player labels, and the leader crown.
- Replaced the shared generic power-up orb with ten item-specific cartoon models: air horn, swap bell, ghost, pocket watch, emergency door, decoy pair, magnet, brick wall, hot potato, and bungee hook.
- Kept the stun gun's existing dedicated pickup model.
