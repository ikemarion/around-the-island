# ATI online play — v0.27 (protocol 7)

## One host window, one lobby

This build uses the existing Playit tunnel on ISAACSPC. It does not run a separate background game server and does not discover arbitrary hosts.

1. On the configured host PC, open ATI once and click **Host lobby**.
2. Stay in that window: it is both the server and Player 1. Do not open another game window or click Join on the host PC.
3. Friends launch the same build and click **Join lobby**. No address or code entry is required.
4. Compare the displayed lobby ID if needed. Everyone should see the same ID and roster.
5. Any admitted player can click **Start match →** once at least two players are present. Wait for the rest of the group before starting.
6. **Close lobby for everyone** disconnects guests and releases the port. The same window can immediately host a new lobby. Guests click Join again.

Playit must stay running on the configured host PC. Friends need no Playit account, VPN or tunnel software. Public endpoint: jakarta-oki.tun.ply.gg:23862, forwarding UDP to 127.0.0.1:27888. The game confirms it is listening locally; it does not automatically verify Internet reachability.

## No conflicting hosting choices

The normal menu has only Host lobby, Join lobby and Practice with a bot. Host is enabled only on the configured host computer (Windows computer name ISAACSPC); this is a usability guard, not authentication. Moving hosting to another computer requires configuring that computer's tunnel and updating the build's host identity/address.

Normal ATI launches hold a loopback TCP window lock on port 27887. A second window displays an error and cannot host, join or practice. Closing the game releases this lock. If an old-version host or another program owns UDP 27888, Host lobby reports **Lobby NOT opened**, returns to the menu and does not take over or kill that process. Close the earlier host and retry.

## Joining and errors

- Joining displays the current stage and elapsed time. Cancel returns to the menu.
- A 15-second timeout means the room could be offline, full or unreachable; the message does not pretend to distinguish these cases.
- Start requests show Starting and allow retry after five seconds without a response.
- Maximum four players, including the host. A fifth player is not admitted.
- Everyone must use the same current build. Do not mix v0.27 with older versions.

## Current online-play caveat

The exported Windows build has completed a real friend playtest and the lobby flow worked. That playtest also exposed severe latency followed by near-simultaneous guest disconnects. The cause has not yet been isolated between the game, the host connection and the Playit route. v0.27 is a visual update and does not claim to fix that networking issue.

## Developer testing

Command-line direct/LAN hosting and address overrides remain for diagnostics, not the normal menu:
- --ati-host: same configured-host action as the Host lobby button.
- --ati-host-local: direct UDP listener without router discovery.
- --ati-join=IP:PORT: explicit test destination.
- --ati-test-instance: permits controlled multi-process tests on one PC.

Arguments follow the engine's -- separator. Tests launched with --script also bypass the normal one-window guard. Test players must be shut down after testing.

## Gameplay carried forward

Four first-person players, cartoon art pass, all existing power-ups, and the round-transition fixes remain. The severe-latency missed item activation in LATENCY-0.23.md is still outstanding. The requested farthest-player magnet and potato heat visuals were interrupted before implementation and are not part of this hosting build.
