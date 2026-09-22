# ATI online play — v0.61 (protocol 17)

Use **v0.61** on everyone's PC for the prediction, diagnostic, menu and animation fixes; protocol 17 is unchanged. Choose **Sockling** or **Looper** under **Choose your skin** in the main menu or waiting lobby. Both play identically; your choice is saved and shared with other players. Decoy Double copies that character and its color. Selection locks while connecting or playing. The practice bot gets a random character each round; human choices are preserved. Character animation changes do not alter hitboxes or movement tuning. Stun now correctly cancels active sliding.

The five-second 2× Speed sneaker pickup (Q / right bumper) remains synchronized by the host. It does not stack with the charged chaser boost. The buddy hides its user for four seconds while the decoy remains visible. Other players see fading footprints when the user moves on the ground. This is independent of regular invisibility. The charged chaser burst remains: recharge for eight seconds, then press F / left bumper for five seconds at 80% extra running speed. A small lightning meter shows charge/burst time. Charge is retained while idle, cannot refill during a burst, and resets on spark transfer, respawn or restart. The 7% carrier slowdown stays. Redesigned emergency doors spawn near a clear outer border and across the map, with inward landings.

## Direct route comparison

Host uses Host lobby as usual (listens on UDP 27888). Friend enables Direct connection test and enters the host's numeric IP:port, then Join direct address. This bypasses the default Playit hostname. On the same LAN use the host's local IPv4 address; across the Internet use its public IPv4 address with router UDP 27888 forwarding to the host PC and firewall permission. A private 10.x/192.168.x address will not work for a remote friend. The game does not create that forwarding or change firewall rules. Turn the test switch off for normal Playit joining.

Saved reports send newest first. Connection logs distinguish default_tunnel from custom_address, without recording the custom IP.

Joining automatically shares previously unsent ATI JSON diagnostic reports with the configured host; no other files are sent. Connection reports opens the network-logs folder: reports contains your own files, received contains reports uploaded by friends. Interrupted transfers retry on the next join. The final disconnect report cannot arrive until the player reconnects.

Uploads use 800-byte acknowledged chunks, at most four chunks/second per player, 256 KiB per report, 2 MiB of received chunks per connection, and a 50 MiB host inbox cap. Oversized reports stay local; a full inbox requires the host to archive reports manually. Receipt hashes prevent duplicates. There is no GitHub or third-party upload.

Reports include one-second ENet transport statistics and snapshot-silence timing. Disconnect wording does not assume the host closed the lobby. Timeouts are unchanged. Failed saves now remain pending rather than receiving an incorrect success acknowledgement, and healthy waiting-room probes receive replies.

Post-match free movement and confetti/winner announcements remain. Scores freeze at the buzzer; the host can restart when ready.

Press **Escape** or **Start / Options** for the session menu; **B / Circle** dismisses it. The match keeps running. In smaller windows the lobby rearranges and scrolls, keeping controls readable; keyboard/controller focus brings off-screen buttons into view.

Score Ribbons display scores and remaining time; the gold spark vignette and local-only invisibility shimmer remain. Gameplay keybind overlays and obstacle instructions are hidden. See NETWORK-RELIABILITY.md for log locations and the next remote-test procedure.

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
- Use v0.61 for matching fixes, menus and animations. Protocol 17 is required; older protocol versions are rejected when joining.

## Current online-play caveat

v0.61 also removes an unintended engine-side bandwidth cap on the host. This materially improved packet delivery in controlled local testing. Everyone should update, especially the hosting PC; remote Internet/Playit testing is still needed. Details and evidence are in NETWORK-RELIABILITY.md.

An earlier friend playtest exposed severe latency followed by near-simultaneous guest disconnects. The cause has not yet been isolated between the game, the host connection and the Playit route. Local tests validate admission, waiting-room probes, character/decoy replication and round flow. They do not establish remote Internet or tunnel reliability. See NETWORK-RELIABILITY.md for one current evidence-collection procedure; historical notes are archived under docs/history.

## Developer testing

Command-line direct/LAN hosting and address overrides remain for diagnostics, not the normal menu:
- --ati-host: same configured-host action as the Host lobby button.
- --ati-host-local: direct UDP listener without router discovery.
- --ati-join=IP:PORT: explicit test destination.
- --ati-test-instance: permits controlled multi-process tests on one PC.

Arguments follow the engine's -- separator. Tests launched with --script also bypass the normal one-window guard. Test players must be shut down after testing.

## Gameplay carried forward

Four first-person players can chase through the kitchen, living room, and garage. The power-up pool includes the farthest-opponent magnet, animated air horn gust, and the carried potato that heats to red before exploding. The severe-latency missed item activation in LATENCY-0.23.md is still outstanding.
