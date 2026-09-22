# Connection diagnostics — current playbook

Use **v0.61 on the host and all guests** (protocol 17). Normal Join uses the configured Playit endpoint; Direct connection test bypasses it. See [ONLINE-PLAY.md](ONLINE-PLAY.md) for setup. No public connectivity test or automatic router/firewall change is implied by the host's local-listening confirmation.

## Collecting reports

Open **Connection reports** from the lobby or session menu. The folder is normally:

`%APPDATA%\Godot\app_userdata\Around the Island\network-logs`

- `reports` contains this computer's automatically saved ATI JSON reports.
- `received` contains reports uploaded by admitted guests.
- Session JSONL files contain timestamped events and periodic samples.

Disconnects and session exits save reports. On a later successful join, guests automatically send previously unsent ATI reports, newest first. No unrelated files, GitHub uploads or third-party report storage are involved. The lobby explains this sharing before joining.

A friend's final disconnect report normally arrives **when they reconnect**, not after the broken connection is already gone. Reports remain local until a verified save is acknowledged. v0.61 fixes the retry case that could incorrectly mark a failed host save as delivered.

Transfers are bounded: 800-byte chunks, at most four chunks/second per guest, 256 KiB per report, 2 MiB received per connection, 50 MiB host inbox. Interrupted transfers retry; oversized reports remain local. Archive the host inbox manually when full. Do not delete unsent reports just to silence a warning.

## Next remote playtest

1. Everyone uses the same build. Host keeps ATI and Playit running; prefer Ethernet when available.
2. Wait in the lobby for at least ten seconds. Guests should obtain an RTT reading without accumulating unanswered probes solely from waiting.
3. Play several rounds. If someone drops, note the approximate time, whether everyone dropped together, and whether the host froze.
4. Have guests reconnect so their saved reports can upload. Collect host reports and received guest reports covering the same timestamps; preserve nearby Playit logs if available.
5. Compare against a same-build direct LAN session. A direct Internet comparison additionally requires a reachable public IPv4 address and UDP forwarding; the game does not set these up.

## Interpreting the evidence

- Application RTT is measured by each guest. An absent host RTT is normal.
- Unanswered probes are **not** a packet-loss percentage. Requests, replies or scheduling can be delayed. v0.61 answers admitted peers while waiting in the lobby, removing one source of false misses.
- Snapshot silence records how long authoritative updates have stopped arriving.
- ENet samples include reliable RTT/variance, loss estimates, connection state and throttle ratio. They do not expose the exact reason for every timeout or the pending reliable queue.
- Maximum frame duration helps distinguish a stalled game process from a transport problem. Compare both sides and the same timestamps before blaming the host, ISP or tunnel.
- Estimated obstacle payload bytes exclude protocol overhead and do not represent total wire bandwidth.

If all guests lose snapshots while the host remains responsive, compare tunnel and host-network events. If the host also stalls, investigate game frame time. If only one guest drops, inspect that guest's path as well.

## Validation and limits

### Engine bandwidth issue found during this pass

The installed Godot 4.7.2 build (`ed1daf0bf`) passes the requested channel count plus two into the server's incoming-bandwidth argument. ATI requests three channels, producing a five-byte/second cap instead of the intended unlimited default. This is visible in the [server creation call](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/modules/enet/enet_multiplayer_peer.cpp) and [connection method signature](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/modules/enet/enet_connection.h).

A controlled local transport comparison delivered 400 of 471 packets with that setup and reached a throttle/limit of 1/32. Explicitly restoring unlimited bandwidth delivered 471 of 471, with both remaining at 32/32. The game now calls `bandwidth_limit(0, 0)` immediately after server creation, before admitting peers. The client's argument forwarding was inspected separately; it does not have this mismatch. Game-level input/report rate limits remain unchanged.

Reports now include `throttle_limit_ratio` alongside `throttle_ratio`, distinguishing a bandwidth-imposed ceiling from the current sending rate. These local results identify a concrete problem, but do not prove it caused every historical disconnect or establish that the Playit route is healthy.

The audit reproduced repeated-ack prediction resets, missing guest throw feedback, a report-persistence acknowledgement bug and misleading waiting-room probes. Targeted regressions accompany their fixes. The pre-fix local host-plus-three-guests run lasted 180 seconds across three host round starts without a disconnect; this is a localhost lifecycle check, **not proof of WAN reliability**. Release verification records the post-fix results separately.

No provider migration, timeout inflation, automatic reconnection or public-server restart is part of this maintenance pass. Historical investigations are preserved in [the archive](docs/history/NETWORK-through-v060.md), including older behavior that no longer describes the current build.
