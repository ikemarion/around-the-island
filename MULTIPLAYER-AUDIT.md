# ATI multiplayer audit — September 3, 2026

## Verdict

The audit findings below have now been addressed in version 0.17 (protocol 3). Automated local regression tests pass. This is not yet an internet-quality certification: different machines, controllers, Playit traversal, and controlled latency/packet-loss playtests remain unverified.

## Repair and verification follow-up

- Input ownership: local mouse events cannot consume remote/replica weapons. Joining-player actions execute on the host, using reliable sequenced action messages. Input vectors are checked; stale input is neutralized after 500 ms.
- Round lifecycle: reliable final state plus continued periodic updates; movement and effect simulation stop at round end. Stale snapshots are rejected using round and per-object sequence numbers.
- Session lifecycle: full player/input/item/chair/effect reset between roles; chair reservations released on disconnect. Client-to-solo and preparation for hosting restore authoritative movement and chair physics.
- Presentation: crouch eye-height updates on clients, replicated item cooldown/stun/facing/held-chair state, sound events and stun beams. Remote held-chair collision exceptions match the host.
- Swap bell: aimed, visible active opponent within ten meters; missed targeting keeps the item.
- Responsiveness: local movement prediction with acknowledged-history correction, camera correction smoothing and remote-player interpolation. Static pocket walls also participate in client prediction. Moving chairs remain snapshot-driven rather than fully predicted.
- Transport: fast-changing player/chair/effect state uses separate unreliable updates instead of reliable full-world snapshots. Round transitions, effect membership and button actions remain reliable. This design change has not yet been bandwidth-profiled under loss.
- Compatibility: version handshake and timeout before slot admission. Everyone should replace older builds; very old builds without the handshake may only see a disconnect.
- Other gameplay fixes: global below-map fallback with spark forfeiture, temporary higher chair speed allowance for horn/magnet blasts, passed hot potato survives departure of its original owner.

Tests run after repairs:

1. Four separate Godot processes on isolated localhost UDP 27991: three distinct client slots/cameras, all three host crouch states true, all three client eye heights approximately 0.82, and all peers stopped at round end. Logs: build/network-test/fixed-*.log.
2. Host/client lifecycle test on isolated UDP 27992: two complete joins/disconnects, clean reused slot, all five chaos effects reconstructed, client Q action activates invisibility. Test: tests/network_lifecycle.gd.
3. tests/multiplayer_regression.gd: chair exclusivity/release, weapon input authority, reliable remote fire path, stale input, role cleanup, far-out respawn/spark forfeit, blast allowance, passed potato lifetime, HUD state and stale snapshot rejection. Zero failures.
4. Existing chaos, stun-gun/gameplay, room-code and sound smoke tests: exit 0, no script errors or assertion failures.

Godot still reports sandbox log-file/certificate-store warnings, plus small ObjectDB leak warnings in some direct smoke-test teardown paths. These were not resolved by this multiplayer pass. Diagnostic processes were stopped; the Playit service was not changed. Headless tests do not establish visual polish, actual audio perception, prediction quality under internet lag, or controller feel.

## Original audit record (pre-repair)

The remaining sections preserve the original findings and pre-repair line references; they do not describe the repaired build's current behavior.

## Tests actually performed

- Four separate headless Godot instances on localhost, isolated UDP port 27991: one host plus three clients.
- All three clients received distinct slots and the correct camera target.
- All three clients sent crouch inputs; the host simulated all three as crouched.
- Forced round expiration between snapshot intervals to test final-state delivery.
- Direct probes for input ownership, slot reuse, shared chair ownership, swap targets, and client-to-host role transitions.
- Existing gameplay smoke test and chaos-effect smoke test passed. The latter tests behavior and client reconstruction of all five new effects.
- Diagnostic scripts and network logs are in build/network-test. The test processes were stopped; the Playit service was not changed.

## Confirmed defects and code-level findings

### 1. P1 — Host mouse clicks can spend another player's stun gun
Reproduced: setting a remote-controlled player’s equipped item to stun gun and invoking its mouse-input handler consumed it. The handler checks AI and held chairs, but not network authority or replica ownership. Every player node receives local input events. Client replicas can also simulate a shot locally, using the client camera, independently of the authoritative server.

Source: [scripts/player.gd:685](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:685>). Fix direction: only the locally owned player should collect input; all real shots must execute once on the host.

### 2. P1 — Round end is not reliably delivered to clients
Reproduced with three clients: host round_running=false and time=0; clients remained round_running=true at the last pre-expiry time (72.95 in the deliberately shortened test). The host returns before broadcasting once the round ends, and no guaranteed final-state message is sent. Player/effect simulation can continue locally after snapshots stop. Winner text and round-end sound are also host-only.

Sources: [scripts/main_networked.gd:96](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:96>), [scripts/main_networked.gd:323](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:323>). Fix direction: reliable lifecycle events plus final snapshot; explicitly define whether movement/effects freeze after a round.

### 3. P1 — Session transitions and reused slots retain stale state
Probes confirmed a deactivated/reactivated slot retained its item, movement input, and held quick-item state. Connect/disconnect hooks do not reset the full player state or release held chairs. Client-to-host setup leaves Player 1 marked as a network replica, so it will not simulate movement. Separately, chairs frozen by client snapshots are never explicitly unfrozen when returning to solo/host play.

Sources: [scripts/main_networked.gd:167](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:167>), [scripts/main_networked.gd:208](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:208>), [scripts/main_networked.gd:233](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:233>), [scripts/main_networked.gd:402](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:402>). Fix direction: explicit enter/exit role reset for players, inputs, chairs, temporary effects, and peer state. The full reconnect/host-switch UI sequence remains to be tested after repair.

### 4. P2 — Joining players crouch physically but their camera stays standing
Reproduced on all three network clients: crouched=true, eye height=1.48 instead of 0.82. Replica physics exits before updating current_view_height; snapshot application changes body stance only. The client camera therefore also disagrees with the host's crouched aim origin.

Sources: [scripts/player.gd:360](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:360>), [scripts/player.gd:455](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:455>), [scripts/main_networked.gd:377](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:377>). Fix direction: client presentation update independent of authoritative physics.

### 5. P2 — Swap bell still uses the old fixed-opponent model
Four-player probe produced targets [1, 0, 0, 0]: P1 swaps with P2; everyone else swaps with P1. Aim is ignored, and the status message still says “bot.” An old target can also remain when no active opponent is available.

Sources: [scripts/main_networked.gd:474](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:474>), [scripts/player.gd:787](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:787>). Fix direction: choose a defined multiplayer target rule (aimed player, nearest player, or current spark holder), validate activity, and clear stale targets.

### 6. P2 — Two players can own the same chair
Reproduced: both player objects simultaneously stored the same held_chair. There is no host-owned reservation or owner identifier; both can apply grab forces. Remote clients also do not receive held-chair/highlight state.

Source: [scripts/player.gd:610](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:610>). Fix direction: atomic host-side chair ownership and release on disconnect, respawn, and role changes; client-specific highlighting.

### 7. P2 — Client feedback is incomplete
Code review: authoritative movement/item sounds and match sounds play on the host, without sound events sent to clients. Snapshot data omits slick cooldown, stun remaining/flash, held-chair state, and body-facing rotation. Clients can therefore show slick as ready while the host rejects its use. Stun beams are not temporary-item-group objects, so the world-effect replication path omits them. Local accidental gun simulation can mask some of these omissions.

Sources: [scripts/main_networked.gd:364](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:364>), [scripts/main_networked.gd:524](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:524>), [scripts/player.gd:888](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:888>), [scenes/stun_beam.tscn:21](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scenes/stun_beam.tscn:21>).

## Performance and robustness risks (not measured over the internet)

- P2: No local prediction, reconciliation, or interpolation. Client position is directly replaced by a 20 Hz snapshot. Movement feedback must wait for an input round trip plus snapshot scheduling; this is inherently less responsive than the host. A localhost handshake does not validate remote feel.
- P2: Full chair/effect snapshots are reliable at 20 Hz on channel 0, sharing ordered delivery with lifecycle/item messages. Packet loss can build a backlog of obsolete world states. Measure traffic and redesign transient state transport if needed.
- P2: Input packets contain button states over unreliable transport, with no acknowledged action sequence or stale-input timeout. A short press can be lost; stale held inputs can persist during interruption. Finite/range checks are also missing for supplied movement and aim.
- P2: No build/protocol compatibility handshake. Older/newer clients may connect before incompatible snapshots or RPCs fail.

Sources: [scripts/main_networked.gd:265](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:265>), [scripts/main_networked.gd:273](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:273>), [scripts/main_networked.gd:377](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:377>), [scripts/main_networked.gd:401](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:401>).

## Other gameplay risks noticed

- Kill-box coverage is only 30 × 24 meters. A sufficiently fast airborne launch can pass outside it before dropping below the map; there is no global below-height fallback.
- Chair horizontal velocity is clamped to 12, limiting how much the 75-impulse horn and magnet blast can actually increase horizontal flight.
- Hot potato depends on its original owner's active slot even after being passed. The effect disappears if that owner leaves, and slot-based references need explicit cleanup on reuse.

Sources: [scenes/main.tscn:22](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scenes/main.tscn:22>), [scripts/shoveable.gd:7](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/shoveable.gd:7>), [scripts/chaos_effect.gd:122](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/chaos_effect.gd:122>).

## Recommended order

1. Fix input authority, final round delivery, session/slot cleanup.
2. Fix crouch camera, targeting, chair ownership, and client audio/HUD feedback.
3. Add prediction/interpolation, action reliability, protocol checking, and transport profiling.
4. Retest four players through complete rounds, late join, disconnect/rejoin, and role changes.
5. Conduct a real remote playtest plus controlled latency/loss testing.

Limits: headless tests cannot prove visual polish or perceived responsiveness. This audit did not test physical controllers, different machines, actual Playit traversal, artificial packet loss, or a complete reconnect matrix. Existing audio/log-directory warnings are test-environment observations, not established multiplayer defects. One ENet send warning occurred during four-process teardown; retest graceful disconnect separately rather than assuming it affects normal play.
