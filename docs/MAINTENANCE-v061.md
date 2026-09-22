# v0.61 maintenance and character motion

This pass addresses the September 22 audit. Protocol 17 remains compatible, but everyone should use v0.61 to receive the fixes. Publication remains paused; the Windows package is prepared locally.

## Resolved

| Area | Change | Coverage |
| --- | --- | --- |
| Prediction | Duplicate/stale acknowledgements preserve pending motion for a bounded 500 ms interval; authoritative motion changes bypass the grace period. | prediction_audit_regression |
| Impulses and sliding | Epoch corrections restore the host's slide state instead of canceling only the guest's slide. Stun stops slide propulsion on both sides. | prediction_audit_regression, round_transition_regression |
| Throw feedback | Guests retain their local throw-held flag and see charging feedback. | network_audit_lobby |
| Reports | Completion requires a successful write; retries recover after blocked storage/quota, corrupt partial files do not count as delivered, and offline clients do not issue self-RPCs. | report_persistence_regression, report_transfer_smoke |
| Waiting lobby | Admitted guests receive diagnostic probe replies before the match starts. | network_audit_lobby |
| Controller menu | Start/Options toggles the session menu; B/Circle dismisses it, with device/focus/state guards. | menu_accessibility, kitchen_menu_smoke, menu_smoke |
| Small windows | Unscaled text/buttons, stacked layout and scrolling; focused controls remain visible after resize or direct-address expansion. | menu_accessibility at 1280x720, 800x600, 640x360, 540x720; native captures inspected |
| Animation | Smooth foot-turn/lift curves, gentle acceleration/braking balance, forward landing brace and clean blink/jaw/Looper secondary-motion resets. | character_motion_polish, existing animation/rig tests and real network character/decoy tests |
| Test reliability | Updated seven-button fixture, explicit deadlines/errors/completion, runner self-test, assertion-execution guard and synchronized reconnect fixture. | tools/run_tests.ps1 -SelfTest, full suite, exported test pack |
| Export/source hygiene | Development resources excluded from player export; separate test pack, current playbooks with historical notes retained; future ZIPs ignored. Session-menu presentation moved out of the main session script. | Actual export inventory and player-pack startup/resource smoke |

## Additional networking finding

The installed Godot engine accidentally maps the explicit channel count into an incoming bandwidth limit when creating a server. ATI's three channels can become a five-byte/second cap. The game now explicitly restores the intended unlimited ENet bandwidth before peers join. Application-level rate limits remain in place; no router/tunnel or timeout changes were made.

Controlled local A/B delivery improved from 400/471 packets to 471/471, with the throttle limit remaining at 32/32 instead of dropping to 1/32. The real-session regression separately delivered 327/327. [Technical evidence, upstream source references and diagnostic interpretation](../NETWORK-RELIABILITY.md).

## Verification

- Full automatic suite: **63/63 test processes passed**, including real localhost multiplayer pairs. Results: `build/test-results/20260922-070028-192-21216/results.json`.
- Test runner self-check rejects errors even alongside success text/exit zero, and terminates a deliberately hung child process.
- Exported Windows Tests resource pack: six smoke tests passed with an assertion side-effect sentinel proving assertions executed. This is an editor/debug-engine pack test, not a misleading standalone-template `--script` run.
- Native menu renders and both-character 9-second animation capture were inspected. Art, colliders and movement tuning remain unchanged by the animation work.
- Clean Windows player executable and its embedded pack were checked separately; test/reference resources are absent and both characters, arena props, scoreboards, spawns, menu and restart load.
- Four-player post-fix endurance check: **4/4 processes passed**, connected for 180 seconds across three host round starts. Final results: `build/test-results/20260922-070237-996-22416/results.json`. All guests retained a 100% bandwidth throttle ceiling during the observed run.

The full suite caught two intermediate failures rather than silently retrying them into a pass: a test that missed a rapid reconnect between polls (replaced with a reliable test-only acknowledgement), and real unreliable-traffic suppression that led to the engine bandwidth fix. Raw failed logs remain local for traceability.

## Limits

These are local automated and rendered checks, not a remote Playit/friends playtest or physical-controller hardware test. CI configuration was added but has not run on GitHub while publishing is paused. A broader architecture rewrite and GPU optimization were intentionally not bundled with this repair pass; further performance work should begin with measurements on the group's lowest-end machine. Historical releases and Git history were not removed.
