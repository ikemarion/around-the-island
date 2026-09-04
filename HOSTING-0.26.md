# Hosting rework — 0.26 / protocol 7

## Implemented

- One normal game window per PC via a loopback TCP lifetime lock. Duplicate windows show a blocking explanation and cannot host, join or start solo play.
- Host lobby immediately opens the UDP listener in the current game. That window is Player 1, not a separate server process.
- Normal Host is limited to the previously configured host PC; Join targets its existing Playit address. Alternate hosting fields and misleading LAN/UPnP choices were removed from the user flow. Developer commands remain explicit overrides.
- Visible version, host/client role, roster and shared lobby ID. New hosted sessions get new IDs.
- A occupied hosting port produces Lobby NOT opened; no silent takeover and no killing unknown processes.
- Joined players keep their Start match button; requests show pending state with a five-second retry. Server checks membership and room state before starting.
- Closing the lobby disconnects guests and frees the listener. Everyone can reconnect to a newly hosted lobby without old round state.
- Roster/snapshot broadcasting after disconnect is deferred until ENet has finished removing the peer.

## Verification

- Real public Playit route: installed Godot runtime, one host plus three independent clients. All showed the same lobby ID, client-triggered start, gameplay entry, rematch, host closure, immediate rehost and successful rejoin with a new shared ID.
- Separate fifth client was not admitted to the full room during a six-second observation while the four-player lobby remained available.
- Duplicate-instance guard exercised using two ordinary runtime launches, without test bypass flags. Second instance printed ATI_INSTANCE_BLOCKED.
- Hosting regression: occupied UDP port, original listener preserved, three successive close/rehost cycles, shared lobby ID and Start-request retry.
- Other passing regressions: default join, menu, kitchen menu, multiplayer, round transition, scaling, routing, chaos, cartoon art, room-code parsing and distant scoreboards. Kitchen menu rendered and inspected at normal and small window sizes.
- Initial end-to-end harness incorrectly treated receipt of the new player epoch as proof that the separate running-state packet had arrived. The harness now waits for both; the corrected run passed. This was a test sequencing correction, not evidence that that earlier run had completed the rematch check.
- The old automatically launched v0.25 host was closed by verified process identity. Test hosts/clients were shut down afterward. Playit was left running.
- Final repeated public run passed all four participants' assertions. One ENet channel-send error remained during teardown without a script backtrace; deferring roster broadcasts removed the earlier repeated roster-call errors but does not establish an entirely warning-free shutdown.

## Release blocker

Export completed, but attempting to launch build/ATI-v0.26.exe outside the network sandbox was blocked by Windows Application Control. Code Integrity events 3033/3077 and Smart App Control event 3118 at approximately 20:49 on September 3 corroborate the rejection. The file is unsigned; the exact policy exception or signing solution has not been established. No renaming-based execution workaround, policy disabling, or trust-store changes were attempted.

Therefore the project-level public hosting flow is verified, but the standalone friend executable is **not release-certified**. Keep this version a release candidate until approved/trusted Windows distribution and standalone launch are verified. A different friend's network/machine has not been directly tested in this pass.

The high-latency item activation defect and the interrupted magnet/potato change are outside this rework and remain outstanding.
