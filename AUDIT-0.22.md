# ATI 0.22 audit

Audited September 3, 2026. Audit only: gameplay scripts, distributed builds, the live host, and Playit were not changed. Diagnostic files were added under build/network-test, which is excluded from exports.

## Findings

### Repair follow-up — version 0.23 / protocol 5

Both findings below are fixed. On the first accepted packet of a newer round, clients reset movement/action state while retaining role flags, retire previous-round effect replicas, and immediately clear their collision layers/masks before deferred deletion. Further packets in the same round do not repeat that reset or discard newly received state. Older-round packets remain rejected.

The permanent tests/round_transition_regression.gd covers pending jumps and held-button latches, immediate wall collision removal, a player-state packet arriving before the effect manifest, a manifest arriving first, stale prior-round packets, role preservation, and preservation of new-round items/actions. The original findings below are retained as a pre-repair record; audit3_probe.gd intentionally asserts the old behavior and is superseded by the permanent regression.

### P2 — Previous-round queued actions survive a client rematch

Sources: scripts/main_networked.gd:648 and :919; scripts/player.gd:547.

When a newer round epoch arrives, _accept_epoch clears sequence tracking and prediction history but does not clear the player's action_queue or button latches. The subsequent authoritative spawn/motion reset clears position, velocity, history and slide time, but still leaves that queue intact. In contrast, the host uses reset_movement_state when resetting the round.

Deterministic reproduction: queue a client jump before a round transition, accept a newer epoch, then deliver a new-round authoritative spawn. The previous-round jump remains queued after both steps. A pending action near round end can therefore be consumed by client prediction in the next round, while the host has discarded it, producing an unintended predicted action and correction. Retained crouch state was also observed, though the next live input sample normally refreshes it.

Fix direction: explicitly reset per-round local action queues and input latches at epoch transition, without overwriting newly received authoritative state or local role flags. Add a test that transitions rounds with a pending jump and held crouch.

### P2 — Old-round client walls persist until the new effect manifest arrives

Sources: scripts/main_networked.gd:648, :754 and :798.

A newer epoch clears effect IDs and sequence tracking, but leaves remote_temporary_items and their scene nodes alive. Those replicas have local simulation disabled; they do not expire themselves. Only a later reliable manifest removes them. Match/player updates can arrive on the unreliable channel before that manifest, so new-round client movement can encounter a previous-round pocket wall that no longer exists on the host.

Deterministic reproduction: create a replicated pocket wall in epoch 1, then accept epoch 2 while withholding its effect manifest. The old wall remains valid and is not queued for deletion. Delivering the epoch-2 empty manifest finally removes it. This establishes the ordering defect; it does not measure how frequently it occurs over the internet. The effect is transient when reliable delivery recovers.

Fix direction: retire all prior-round replicas on epoch advancement, including disabling collision immediately before deferred node deletion. Test a new-round movement update arriving before its reliable effect manifest.

## Checks passed

- Eleven existing direct tests: default_join_smoke, menu_smoke, kitchen_menu_smoke, multiplayer_regression, scaling_regression, routing_regression, chaos_smoke, network_code_smoke, distant_scoreboards_smoke, stun_gun_smoke, sfx_smoke. No script/assertion failures; explicit failure counters were zero.
- Four independent local processes on isolated UDP 27994: host plus three clients; waiting room, manual start, two round starts/ends, rematch, item actions from all clients, and up to forty reconstructed effects per client.
- Host/client lifecycle on isolated UDP 27992: two joins/disconnects, same-slot rejoin, correct camera, clean player slot, late-join effects, and client item use.
- One-click Join's destination, duplicate-click guard, cancel, retry, and timeout passed its mocked-network test. This does not verify the public Playit endpoint is reachable right now.
- Targeted diagnostic build/network-test/audit3_probe.gd reproduced both findings above. Logs use the audit3- prefix.

## Limits and deployment notes

- No live internet latency/loss test, real tunnel reachability check, GPU performance profiling, or physical controller test was performed.
- Log-directory and certificate-store warnings persist in this sandbox. They were not treated as game assertions or newly proven shipped-runtime defects.
- The fixed Join destination is intentional for the user's single-lobby setup. Moving that public endpoint requires a rebuilt client. Generic direct/LAN hosting remains a developer path and cannot be joined through the normal fixed-destination button.
- These findings do not invalidate the passing basic multiplayer flow. They are round-transition consistency gaps that the happy-path tests did not cover.

Recommended next step: fix both epoch-transition issues together, preserve the reproductions as permanent regressions, then test delayed/reordered traffic and an actual remote play session.
