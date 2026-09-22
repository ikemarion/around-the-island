# Future passes

## Character roster rollout

- Approved Round 02 concepts: Doughballs, Socklings, Pebble Pals, Patch Pals, Nubbins and Loopers.
- Socklings first (v0.50), then Loopers and a two-character lobby selector (v0.58). Doughballs, Pebble Pals, Patch Pals and Nubbins remain future passes. Reference and actual Godot captures: `docs/art/socklings/` and `docs/art/loopers/`.

## 0.60 Skin buttons and randomized practice bot

- Made both skin choices directly visible in the main menu and waiting lobby, with a selected-state highlight and standard button navigation. Local preference, online admission and match/connection locking still use the existing validated selection flow.
- Practice bots roll from the character catalog on each round start/restart, retaining their skin during the round. Repeats are allowed. Inactive slots, the local player and online humans are never randomized. A separate cosmetic random generator leaves spark/power-up randomness untouched.
- Skin-specific art fixtures now explicitly choose their subject so bot randomness cannot make those tests flaky. Deterministic bot tests cover the pool, round lifecycle, unchanged player preference and decoy copies. Protocol 17 and gameplay rules are unchanged.

## 0.59 Looper clay refinement

- Replaced the fuzzy velvet surface and close-up fibre geometry with matte modeling clay: subtle hand-worked relief, restrained color variation and broad, low-sheen highlights. Purple and cream share the clay treatment; Sockling's fleece is unchanged.
- Refined the approved silhouette: broader rounded cheeks/head, softly capped elongated sleepy eyes instead of angular wedges, and fuller fused mitten lobes. Preserved the open loop, smirk, continuous body/hip joins, sole geometry and rig anchors.
- Cosmetic only. Selection, decoy copying, movement, hitboxes, scores and power-up rules are unchanged. Build v0.59 keeps protocol 17; everyone should update for matching art. Native comparison/close-up/animation: `docs/art/loopers/v059/`.

## 0.58 Loopers join the roster

- Added the approved Looper as a separate selectable character: continuous purple plush pear body, rounded head with a genuinely open loop, half-lidded ivory eyes with sideways pupils, a small smirk, puffy mittens, soft feet and cream ankle cuffs. A distinct fine-pile velvet shader and short close-up fibre geometry distinguish it from Sockling's curly terry fleece.
- Reworked the first sculpt after native engine comparisons to remove visible chin/neck bands, broaden the body/head and bury the hip joins. Existing skeletal arm follow-through and grounded leg animation support walking, running, carrying, jumping, crouching, sliding and stun, with restrained loop motion. No changes to movement, hitboxes, camera, scores or abilities.
- Added a lobby selector with saved local preference, validated host admission/selection requests, player roster/snapshot replication, and late-rejoin cleanup. Selection locks once a match begins. Protocol 17 requires everyone to update to v0.58.
- Decoy Double now carries the selected character identity as well as its captured color. Both Looper and Sockling copies stay visible independently of hidden owners and retain the four-second lifetime.
- Tests cover four Looper palettes, real loop opening, materials/geometry budgets, limb rigs, movement states, visibility and replica resets; local two-process tests cover lobby selection, mixed characters/decoys and reconnecting with a different character. Native captures and animation: `docs/art/loopers/v058/`. These checks do not establish WAN/tunnel reliability or low-end performance.

## 0.57 Decoy Double copies its owner

- Replaced the deployed pickup doll with the actual full-size Sockling model, matching the activating player's rendered fleece color, face, cuff, feet and articulated arms. The collectible icon itself is unchanged.
- Copies have their own materials/rig and never inherit the owner's first-person hiding, invisibility, stun, input or abilities. They face their escape direction and animate from observed travel on host and replicas; a blocked copy settles into idle.
- Existing four-second duration, hidden owner with footprints, bot distraction, movement/collision rules and effect cleanup are preserved. Skin color and facing use existing effect fields; protocol 16 is unchanged. Friends need the new build to see the new model.
- Four-slot skin/rig isolation and client reconstruction tests passed, alongside buddy, chaos, Sockling, multiplayer and round-transition regressions. Two-process localhost tests verify both host and joining-player decoy appearances, visible animated copies with hidden originals, and expiry removal. This is not a WAN reliability or low-end performance test.

## 0.56 natural Sockling arms and motion

- Re-sculpted the wide, asymmetric bind-pose arms into relaxed hanging limbs with a tapered wrist, cupped palms and inward-facing thumbs; preserved the fleece, head, cuff and soft feet.
- Replaced arm bend morphs with a three-joint GPU-skinned chain per arm. Cached weights are shared across all four players, with fixed-length forearms, softly blended elbows and delayed wrist follow-through. Existing jaw and knee morphs remain.
- Continuous opposite arm swing and damped transitions replace abrupt shoulder reversals. Carrying reaches forward with bent elbows; airborne arms balance more quietly. Reduced sideways slouch, chest bounce, landing squash and stun jitter. Bounded animation substeps keep poses close at 30/60/144 FPS.
- Cosmetic only: no root motion, collider, camera, speed, power-up or network protocol changes. Visibility/teleport resets clear joint motion. Native Godot captures and the animation preview are in `docs/art/socklings/v056/`.

## 0.55 cartoon stun gun and clean doorways

- Removed the floating room-name text on both sides of every kitchen/living-room/garage passage. Door frames, headers, thresholds, collisions and navigation remain unchanged.
- Added regression checks for label-free doorways with intact frames, alongside the existing standing-player passage sweeps and modular room tests.
- Rebuilt the approved stun-gun collectible as a Blender-authored GLB: mint egg-shaped shell, convex cyan lens, thick cream muzzle collar, curved coral grip and cream foot, small gold ready dome, lightning medallions and three gold vents on each side.
- Refined badge fit, lens size/material, curved grip and foot through repeated actual Godot captures. Restrained cyan lighting, slower spin and a shallow bob keep the shapes readable; the sculpt stays above the saucer throughout its hover. Collection sphere dimensions, one-shot firing, stun duration/range, existing saucer and protocol 16 remain unchanged.
- Tests cover concept components, the under-50k triangle budget, hover clearance, local collection, remote spawn/removal/respawn and existing gun/game regressions. A two-process localhost test verifies the new model and one-shot inventory via the unchanged authoritative packets. This does not establish WAN/tunnel reliability or low-end performance.
- Rebuild source: `tools/build_stun_gun.py`. Runtime asset: `art/pickups/stun-gun/`. Approved reference and unretouched game-lighting captures: `docs/art/stun-gun-concept/`.

## 0.54 Score Ribbons leaderboard

- Implemented approved concept B: separate beveled ceramic pennants with real recessed score channels, rounded player-color fills/badges, a large mint countdown pill and a soft gold crown with a restrained sparkle animation.
- Smoothly animated, shared relative fill scale with fixed-position numeric scores (tenths preserved). Zero scores show an empty channel; labels never ride up into the crown or timer. Timer rounds up the last partial second and shows `00:00 / FINAL SCORES` when the round ends.
- Active players recenter into one/two/three/four ribbons without empty holes; each client labels its own slot YOU. Ties hide the leader crown. Disconnects, restarting and returning to the lobby clear the appropriate display state.
- Visual-only, existing authoritative snapshots and protocol 16. No player, map, physics, power-up or scoring-rule changes. The original tabletop score lanes remain.
- Rebuilt and checked multiple native Godot captures against the concept. Local two-process host/client tests cover countdown, scores, client badges, lead change, final scores, restart and disconnect; regressions cover post-match flow, multiplayer state, round transitions, kitchen and Sockling art. This does not establish WAN/tunnel reliability or low-end hardware performance.
- Reproducible Blender builder: `tools/build_score_ribbons.py`. Runtime GLB assets: `art/scoreboards/`. Fredoka font is bundled with its SIL OFL license. Actual game-lighting captures: `docs/art/leaderboard-concepts/v054/`.

## 0.53 Sockling reference-feel pass

- Broader, overhanging upper muzzle and reshaped grin/cheeks; smaller eyes sit into the head instead of above it. Refined tongue and felt lining remain animated with the mouth.
- Longer asymmetric noodle arms, three-lobed mitten hands, bowed legs, broader splayed soft feet and the rounded sock heel visible below the cuff. Resting body lean and head tilt follow the approved concept; existing action poses are preserved.
- Curly triplanar yarn replaces speckled noise, with reduced contrast/specular, a warmer gold palette and rounded fibre arches instead of pointed tips. Larger 28-column knitted cuff ribs and a thinner coral stripe.
- Multiple front/side/reference-angle Godot iterations and an updated animation capture. Base character remains under 100k triangles; unchanged collider and protocol 16. Morph, visibility, movement-pose and local host/client checks cover the updated asset. No low-end hardware or WAN reliability claim.
- Direct concept/native-render comparison, front/side views and animation: `docs/art/socklings/v053/`. Comparison preserves the actual game lighting; no paint-over or artificial studio-light replacement.

## 0.52 Sockling puppet animation

- Added soft elbow and knee morphs to the existing sculpt, with locally blended walk/run strides, foot clearance, opposite arm swing, body bounce, turn lean, secondary head motion and staggered blinks.
- Takeoff compression/stretch, rising/falling poses and impact-scaled landing squash do not delay input or alter the player/camera/collider. Carrying, crouching, sliding and stunned wobble blend over locomotion.
- Sample horizontal travel at physics cadence rather than render-frame displacement. Remote support queries keep airborne poses through the jump apex; visibility changes and motion epochs clear stale landing/stride state. No new network fields or RPCs (protocol 16).
- Tests cover sole clearance, joints, stance transitions, frame-rate tolerance, apex/landing, invisibility/teleport reset and unchanged physics. Two-process local hosting verifies remote walk/rise/fall/land/crouch with existing snapshots. WAN reliability and low-end performance are not established by these tests.
- Native Godot animated preview and stills: `docs/art/socklings/v052/` (staged art inspection, not a live match recording).

## 0.51 Sockling sculpt refinement

- Rebuilt the head, neck and torso as a continuous Blender sculpt with a real recessed mouth and a jaw morph that deforms the lining and lips together. Replaced bead fingers with connected soft hands and refined the asymmetric arms, bent legs, padded feet and smaller eyes against the approved roster.
- Stable fibre bump shading, knit stitches, a thicker striped cuff and cached close-up fleece tips add fabric detail. Fibre geometry disappears beyond seven metres; base sculpt stays below 100k triangles per character. No gameplay simulation or network traffic added.
- Blender authoring file and repeatable builder are in `tools/`; the GLB is the runtime asset. Source `.blend` is excluded from game exports.
- Repeated actual-level render checks and tests cover morphs, geometry budgets, four colors, first-person/normal/buddy hiding, crouch, stun and holding/running. Local host/client join/rejoin/effects passed; no WAN reliability or low-end hardware benchmark claimed.
- Staged Godot captures: `docs/art/socklings/v051/`. Soft cinematic concept lighting is not reproduced exactly by the game's directional lighting.

## 0.50 Sockling player model

- Replaced capsule characters with color-coded fleece puppets: raised ivory eyes, rounded upper muzzle, recessed mouth/tongue, animated lower jaw, floppy arms, three-finger hands, ribbed striped cuffs and coral feet.
- Walk sway, limb swing, airborne and holding poses are local presentation from observed movement. No animation packets or changes to player hitboxes, speeds, camera, abilities or protocol 16.
- All parts inherit BodyMesh facing, crouch and visibility. Verified first-person hiding, normal/buddy invisibility, independent stun material, four colors and local host/client join/rejoin/effects.
- Refined mouth and cuff through repeated actual-level Godot captures; procedural fleece is a lightweight approximation of the mockup texture, not strand fur. Staged captures hide loose props and scores for inspection.

## 0.49 kitchen visual refresh

- Rounded cream countertop with honeywood edge, recessed teal cabinet panels, brass-toned pulls and a shadowed toe kick. Bowl of oranges and a coral kettle dress the ends while keeping the score lanes clear.
- Larger, softer apricot/cream checkerboard tiles with narrow anti-aliased seams and a calm border. Neutral lighting replaces the strong yellow cast.
- Rounded wooden chair seat/back, teal splayed legs and brass pegs; matching wall paneling, wood caps and cream divider plaster.
- Visual-only art preserves the original island/no-hop collider, all floor and doorway collision geometry, 12 movable props and network IDs. No protocol change (16).
- Verified actual Godot captures, cabinet meshes, chair collision envelope, prior house props, buddy/speed rules and post-match flow. WAN reliability is not established by local tests.

## 0.48 double speed pickup

- Added 2× Speed to the random pool with a coral sneaker icon. Q / RB activates five seconds of doubled run/crouch speed, with a HUD countdown.
- Carrier slowdown remains proportional; charged boost does not multiply with x2 or consume its charge while x2 is active. Repeated pickups refresh duration rather than multiply speed.
- Host replicates duration; expiry, respawn and session reset clear the effect. Protocol 16.


## 0.47 buddy vanish and footsteps

- Activating Decoy Double hides its user for four seconds without hiding the visible buddy. Releases held props on activation.
- Alternating mint sole/heel prints show the moving user’s grounded route, fading over 1.4 seconds. Local reconstruction from replicated positions avoids particle/footprint network traffic.
- Dedicated replicated buddy timer keeps normal invisibility independent; trail clears on expiry, teleport, respawn, inactive slot or session reset.
- Protocol 15. Source and multiplayer lifecycle tests cover buddy use and replication.


## 0.46 house prop visual rebuild

- Shared visual-only prop kit: detailed cardboard cartons with flaps/tape/labels; cream-roofed coral car with curved cabin/glass, fenders, hubcaps and grille; fuller sofa cushions with fitted piping/pillows; cream CRT with rounded glass, tuning knobs, antennas and teal console.
- Refined using multiple native Godot render passes, then checked in the actual living room and garage. Original collider sizes, static body names and all 12 networked movable props remain unchanged.
- Protocol remains 14. Reference and native render previews are in docs/art/prop-refresh/.


## 0.45 charged boost and border doors

- F / left bumper activates a five-second 80% chaser running boost after eight seconds of recharge. Compact lightning meter shows charge/duration; authority replicates charge/time and validates activation.
- Shared rounded cream/coral door art for collectible and deployed portals: brass hardware, EXIT plaque, animated mint-gold passage and motes.
- Emergency doors choose safe outer-map border points: nearest clear entry and distant exit, oriented inward. Placement retains the item when no safe pair exists; orientation replicates to clients.
- Protocol 14 requires all players to update.


## 0.44 sparkler chase pass

- Tiny traveling gold HUD streaks and a short, faint world-space golden particle trail; trail clears on invisibility and teleports. Phantom HUD unchanged.
- Spark carrier runs 7% slower. Chasers build up to 15% extra running speed over six seconds of movement; charge drains over two seconds when stopped/crouched and resets on transfers/respawns. No extra input required; post-match movement remains normal.
- Magnet still attracts props to the farthest opponent, then flings nearby props outward at expiry (not disconnect/cleanup).
- Swap bell has a longer metallic strike/ring. Protocol 13 replicates chase charge; all players need this build.

## 0.43 spark and phantom HUD, bell and start rules

- Local-only animated gold perimeter stars while carrying spark; invisible players see blue-violet flowing haze and rising ghost motes, with no camera distortion.
- Swap bell selects farthest active opponent regardless of aim, including invisible opponents. Keeps item when no opponent is available.
- Host/solo randomly chooses starting spark holder among active slots each round; existing snapshots distribute the choice.
- State/expiry HUD and bell/random-starter regression tests passed; in-engine preview checked.

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
