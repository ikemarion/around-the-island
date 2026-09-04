# ATI 0.19 scaling audit

Audited September 3, 2026. Gameplay and distributed builds were not modified. Diagnostic scripts and logs were added under build/network-test (excluded from game exports).

## Verdict

### Repair follow-up — version 0.20 / protocol 5

The seven reproduced defect groups and hosting-portability limitation below have been addressed. The original findings are preserved as a pre-repair record.

- Missing prediction history now rebases position and velocity to the host instead of silently dropping correction. This is a conservative recovery that may visibly snap during loss; internet feel is still unverified.
- Local gun firing checks stun, mouse capture and menu state. Camera recapture consumes the click. Network action queues carry their own aim through execution.
- Spark and hot-potato contact transfers check for solid obstruction. Horn blast penetration was not changed.
- Both camera modes use eye-origin rays toward a camera-derived target for host and joining players.
- Effect manifests respect newer per-effect updates. Tied round results are announced consistently.
- Hosting no longer silently substitutes the original PC's Playit endpoint. The menu accepts/saves a per-computer tunnel address, separately from direct/LAN hosting. The original host can still use jakarta-oki.tun.ply.gg:23862 in that field; friends must use their own tunnel if they host.
- Router discovery and cleanup tasks are serialized so canceled old attempts are cleaned before newer mappings begin. Interactive cancellation no longer calls the router on the main thread. Shutdown still waits for any outstanding router request.
- Escape opens Resume / Leave Room. The online match continues; closing as host disconnects everyone. The obsolete automatic-start assumption in the chaos networking test was removed.

Verification: scaling_regression reproductions now assert the corrected outcomes; routing_regression passed with mocked router operations (no real mapping changes); the existing direct smoke tests passed, with rendered mouse-fire coverage separately. The four-process stress test passed two shortened rounds with all three clients activating items and reconstructing forty effects. Real internet loss/latency, low-end GPU profiling and physical controllers remain future validation, not certified by these tests. Existing sandbox warnings and smoke-test teardown leak warnings remain.

The four-player lobby, manual start, rematch, reconnect, and effect replication paths passed the checks below. Seven groups of gameplay/network defects were reproduced with targeted local probes. A further hosting-portability limitation is visible directly in the code. The largest remaining concern is recovery under imperfect networking, not basic localhost connectivity.

## Findings, in repair order

### 1. P1 — Movement correction silently stops when the acknowledged history entry is missing

Source: [player.gd:538](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:538>).

The predicted player corrects position/velocity only on a motion-epoch change or an exact match in its 120-entry prediction history. There is no fallback when a snapshot acknowledges an entry already discarded or not recorded. This can occur after a sufficiently long input interruption, or for repeated acknowledgments after the corresponding entry was removed.

Reproduced by delivering an authoritative position ten meters from the local position, with the same motion epoch and a missing history entry: the full ten-meter error remained. This was a deterministic injected-state test, not a measurement of normal internet play. New matching acknowledgments or a teleport can restore correction; it is not necessarily permanent.

Fix direction: explicit missing-history recovery, bounded correction error, and tests with delayed/repeated acknowledgments and loss bursts. Verify collision-safe reconciliation rather than only translating historical positions.

### 2. P2 — Host mouse firing bypasses stun and released-mouse state

Source: [player.gd:811](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:811>).

The direct local mouse handler checks ownership, but not stun time or mouse capture. The host spent and fired a gun with two seconds of stun remaining; the equivalent remote-player physics action did not fire. A direct mouse event also consumed the weapon while the mouse was released. Consequently clicking to return to the game can also spend the gun.

Fix direction: route local and remote item activation through the same gameplay eligibility checks, and consume the mouse-recapture click before weapon handling.

### 3. P2 — Queued item actions can use a different aim than the one sent with the press

Sources: [main_networked.gd:379](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:379>), [player.gd:1022](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:1022>).

The reliable action receiver stores its aim in the player's mutable current aim, then queues only the action name. A subsequent movement packet or action can overwrite the aim before physics consumes the queue. Reproduced by queuing a forward shot followed by a right-facing movement update: the resulting beam fired right, ninety degrees from the action's aim.

Fix direction: queue the action together with its aim and sequence, and apply that aim specifically for its authoritative execution. Test rapid flicks and multiple input packets arriving within one physics frame.

### 4. P2 — Pocket walls stop movement but do not stop a spark transfer

Source: [main_networked.gd:145](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:145>).

Tagging checks center-to-center distance only. Reproduced with players 1.2 meters apart on opposite sides of a pocket wall: a ray confirmed a solid wall between them, yet the spark transferred. The thin wall is compatible with players being inside the 1.22-meter tag distance while separated by geometry.

Fix direction: define and enforce obstruction/contact rules for tagging. Hot-potato transfer also uses proximity alone and should follow an explicitly chosen rule. Air-horn blasts likewise do not test obstruction; whether those should penetrate walls is a separate design choice.

### 5. P2 — Alternate camera mode has different aiming rules for host and joiners

Sources: [player.gd:997](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/player.gd:997>), [follow_camera.gd:122](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/follow_camera.gd:122>).

For the local host, aim originates at the camera. For network-controlled players, it originates at their eye height, even when V moves the camera behind and above them. For the same player position, switching the network-controlled flag produced a 13.81-meter origin difference in radial mode. The remote view direction still comes from the elevated camera, so the host's shot and the joining player's shot do not follow the same ray. Grabbing and targeted items share these helpers.

Fix direction: use a common body-origin aiming model with a camera-derived target, or disable unsupported alternate-camera aiming consistently. Validate inputs on the host rather than accepting an unrestricted client-supplied origin.

### 6. P2 — Delayed reliable effect manifests overwrite newer effect state

Sources: [main_networked.gd:669](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:669>), [main_networked.gd:713](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:713>).

Manifest ordering is tracked separately from individual effect ordering. Applying a manifest also writes positions, rotations, timers and targets for existing effects, without comparing their individual update sequences. Reproduced by delivering effect update 20 and then manifest 10: the effect jumped from x=5 back to x=0 and its displayed timer went from one second back to five.

This is most relevant under delayed/retransmitted reliable traffic, especially when other effects are created or removed. A later state update can repair the display, but temporary wall positions and potato targets can be wrong in between.

Fix direction: separate membership/creation from mutable state, or apply per-effect sequence checks to state contained in manifests. Test cross-channel reordering.

### 7. P2 — Ties announce a winner despite the scoreboard recognizing a tie

Sources: [main_networked.gd:490](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:490>), [main_networked.gd:613](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/main_networked.gd:613>).

With both active players at ten seconds, the round-end text announced Player 1 as winner while the crown was hidden for a tie. The final message uses the first highest-scoring slot, unlike the crown and projection leader indicators.

Fix direction: calculate the round result once, including tied winners, and use it for host/client messages and every score display.

### 8. P2 — Internet-host fallback is specific to one computer's Playit tunnel

Source: [network_session.gd:13](<C:/Users/ikema/OneDrive/Desktop/Project Yoshi/projects/around-the-island/scripts/network_session.gd:13>).

When router discovery fails, every distributed copy advertises the same hard-coded Playit address. This supports the currently configured host, but does not make a friend's computer an internet host: their Host button can advertise a tunnel that routes to the original computer instead. This is a code-confirmed deployment limitation, not a newly reproduced failure of the existing tunnel.

Fix direction: distinguish the configured Playit host from generic hosting; support a per-host endpoint or label unsupported hosting paths clearly. Do not promise arbitrary-host internet rooms until relay/Steam support exists.

## Additional risks and maintenance gaps

- No in-match leave-room/main-menu action. The Leave room button is only in the lobby; Escape merely releases the mouse. Switching sessions mid-match requires closing/reopening the app. Add an explicit pause/session menu when refining UX.
- Router cancellation is not fully isolated. Old worker results delete their port mapping, potentially overlapping a newer worker configuring the same UDP port. Cancellation/cleanup still invokes mapping deletion on the main thread, and shutdown waits for workers. This is code review only; no router or port mappings were changed to test it.
- The older tests/chaos_network_smoke.gd still waits for automatic hosting-to-game transition and never presses Start. It is stale under the new lobby flow. The current lifecycle test covers the five effects, but that older test should be updated or retired.
- Existing headless tests do not certify internet latency, bandwidth, low-end rendering performance, different GPUs, or controller usability. Forty replicated effects passing on localhost is not a performance benchmark. Distant projections add 4 boards and 20 labels, updated from the shared score state; their normal functional test passed, but GPU cost was not profiled here.
- Some smoke-test exits still report ObjectDB leaks. Log-directory, certificate-store and shader-cache warnings also occur in this sandbox. No growth-over-time or shipped-runtime cause was established in this pass.

## Verification performed

- Seven existing direct smoke tests: multiplayer_regression, chaos_smoke, stun_gun_smoke, network_code_smoke, sfx_smoke, menu_smoke, distant_scoreboards_smoke. All completed with exit 0 and no script/assertion failures; explicit failure counts were zero where supplied.
- Real host plus three independent client processes on isolated localhost UDP 27994. Confirmed waiting room, manual start, two shortened round start/end cycles and rematch. Every client observed both starts and stops, activated its assigned invisibility twice, and reconstructed up to forty simultaneous effects. These were deliberately injected stress effects, not normal pickup spawn rates.
- Host/client lifecycle test on isolated UDP 27992: waiting room, manual start, disconnect/rejoin into the same slot, effect reconstruction, and client item use passed.
- Deterministic probes in build/network-test/scale_audit_probe.gd reproduced the gameplay/ordering findings above. Output: audit2-scale_audit_probe.log. Stress output: scale-host.log and scale-client-*.log. Lifecycle output: audit2-lifecycle-*.log.
- All diagnostic child processes were stopped. Playit, the running game host (if any), export executables and friend ZIP were not changed.

## Recommended next pass

1. Unify action eligibility and preserve action-time aim; block tags through solid walls.
2. Repair prediction recovery and effect ordering, then exercise controlled latency/loss and interruption scenarios.
3. Unify camera targeting and tie results; add an in-game leave/menu path.
4. Clarify hosting portability, update stale tests, and profile the actual packaged game during a remote four-person playtest.
