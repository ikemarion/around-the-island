# Future passes

## 0.38 post-match celebration

- Players keep moving and interacting after the buzzer, including remote input/prediction and fall respawns. Scores and spark transfers stop.
- Local confetti and winner/tie announcement trigger once per round on each peer. Restart and lobby cleanup remove the overlay.
- Regression covers actual movement, frozen scores, respawn, client snapshot handling, duplicate celebration suppression, restart and lobby boundaries.

## 0.37 floating ceramic score shelves

- Four world-space displays now use cream ceramic shelves, teal scallops, gold trim, rounded vertical player-colored columns, score labels, player badges and spinning leader crowns.
- Fixed score scale preserves comparisons; inactive seats hide and ties hide the crown. Existing replicated scores remain the source of truth, with no new networking traffic.
- Removed gameplay keybind overlay and floating obstacle instructions; retained charge/restart progress feedback.

## 0.36 local status effects

- Replaced the explicit spark banner with a subtle breathing gold edge vignette.
- Invisibility adds a travelling blue/lilac edge shimmer visible only to its owner. Both effects can overlap, leave the center clear, and disappear in menus.
- State regression covers spark transfer, invisibility expiry, overlapping effects and menu cleanup; in-engine screenshots checked.

## 0.35 reliability work

- Small obstacle batches, unchanged-state suppression, one-second full refresh; protocol 11.
- Per-session JSONL connection diagnostics, application RTT and missed probes, frame stalls, snapshot gaps and prop payload counters.
- Local multi-round four-player soak plus rejoin and dropped/stale-state regression checks. Remote Internet/Playit verification still requires the next friend session.
- Reconnect/resume and alternative hosting remain future work, not implemented.

## 0.34 approved round-two collectibles

- Coral horseshoe magnet with cream polarity caps; staggered cream/coral ceramic wall; worried tan potato with cream mitts; paired teal decoy and translucent twin.
- Deployed wall and decoy reuse collectible geometry. Carried potato shares the collectible model and retains its six-second heat progression, pulsing glow, transfer and explosion logic.
- Collision dimensions, impulse tuning, durations, and protocol 10 unchanged.

## Approved concept implementation, one piece at a time

- 0.33: mockup ghost, pocket watch, and air horn completed. Continuous scalloped sheet, porcelain coloring, gold watch case with twelve ticks and raised hands, teal loop; coral/teal air horn with hollow cream trumpet and embossed gust badge. Held horn reuses pickup geometry. All four mockup collectibles use restrained warm lighting and slower float/spin. Other collectibles retain their existing designs; their materials no longer self-illuminate.

- 0.32: swap bell + ceramic spawn saucer. Revolved silhouettes, gold material, cream lip, teal base, recessed ready ring, subdued empty state, slower bell bob/spin, two sparkles. Spawn labels hidden. Collision remains nonblocking.
- Next: ghost, pocket watch, air horn, then remaining collectibles to match the approved cream/teal/coral/gold mockup.
- Pending: restore angular cardboard-box art. Spark vignette completed in 0.36.
- Reference: generated_images/01a0593e-5e63-7d63-b8d1-dbe462487ed2/exec-a47f3a07-f3d3-4ebc-95cf-224be7fc9895.png under the user's Codex directory.

## Visual pass 0.31

- Shared cached bevel geometry across kitchen furniture, room props, cabinetry, and pickup models; collision and network identities unchanged.
- Consistent toon shading and softer highlights, smoother spheres, upholstery buttons, toy belly patch, car trim, tire treads.
- Toy ray-gun stun pickup and rounded kitchen-tile pocket wall.
- Local spark badge, gold corner accents, and acquisition/loss text follow replicated ownership; hidden in menus.
- Existing readable bell, ghost, watch, crown, and doorway silhouettes retained. Further bespoke art polish remains possible.

Current tuning (0.30.1): push/pull impulse reduced from 50 to 15, a 70% reduction. Charged throws and air horn unchanged. Protocol remains 10; host determines physics strength.

- Visual object pass: revisit silhouettes, scale, rounded cartoon styling, and consistency across kitchen, living room, garage, and power-ups.

# 0.30 changes

- Removed bungee hook from gameplay and removed the default slick trap.
- M1 / RT pushes obstacles with 10× the original impulse (50).
- M2 / LT pulls targeted obstacles toward you with matching impulse.
- Charged throws and air horn strength are unchanged.
- Protocol 10: all players need 0.30.

# Obstacle controls (0.29)

- Hold E / X to grab; release to drop. Wider reach and sticky target selection.
- Empty-handed M1 / RT shoves the targeted prop (stun gun retains fire priority).
- While grabbing, hold M1 / RT for up to one second, then release for a throw up to 2.5 times normal strength.
- Gravity-compensated, damped carry spring with a wall-aware anchor; physical collisions remain enabled.
- Host/solo: hold Y / Triangle for one second to restart; R still works.
- Protocol 9: all players must use the same build.
