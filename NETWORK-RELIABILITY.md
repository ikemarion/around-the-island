# Network reliability pass — v0.35

## v0.39 automatic reports

Disconnect signals save a JSON report under `network-logs/reports`. Session exits also save a report before state resets, including intentional exits. These are observations, not a determination of why a connection ended. Connection reports buttons in the lobby and game menu save a current report and open the folder. Nothing is uploaded automatically.

Reports include up to 240 recent events, local RTT/probe state and per-peer last-probe timestamps/counts on the host. Host probe counts are not latency or packet-loss measurements. Collect both the host and friend's reports; the host cannot recover a friend's crash log remotely.

All participants must update: protocol 11 adds bounded obstacle batches.

## Changes

- Skip identical obstacle states between refreshes; repeat all props every 20 snapshots (about one second). This repairs missed final movement updates and supplies late joiners with state.
- Batch prop updates up to 900 serialized payload bytes per batch. RPC/transport headers are additional. Player and match updates remain separate to avoid creating large fragmented snapshots.
- Keep existing per-object sequence/epoch guards when unpacking batches.
- Record timestamped connection events, application round-trip time, probes unanswered for five seconds, maximum frame duration, accepted snapshot counts/gaps, and estimated prop traffic.
- No provider migration, timeout inflation, automatic reconnect, or claim that Internet disconnects are fixed.

## Collect evidence during the next remote playtest

Local validation: one host and three clients completed 180 seconds and three host round starts without unexpected disconnections. Final client application RTT samples were 6–8 ms. Quiet five-second windows recorded 15 prop batch broadcasts versus the previous 1,200 individual prop broadcasts (12 props × 20 Hz × 5 s); this is not a measurement of total wire bandwidth. The test is primarily an idle/round-transition soak, supplemented by separate item-action/rejoin tests, not a WAN or packet-loss stress test.

Also passed: multiplayer regression, two join/disconnect cycles with remote item activation, obstacle interaction, map smoke tests, chaos effects, and synthetic stale/lost prop-state recovery. The exported build passed the prop-batch regression.

1. Everyone runs v0.35. Host keeps the game and Playit running, ideally using Ethernet.
2. Play until the failure occurs; note whether the host game also freezes and the approximate time. Save the Playit console/log around that time.
3. Collect each player's newest file under `%APPDATA%\Godot\app_userdata\Around the Island\network-logs`.
4. Compare with a direct LAN run of the same build. The automated soak uses localhost, not the public tunnel, so it cannot validate ISP or Playit stability.

Log files contain peer IDs and timestamps, not credentials. Probe misses are not an ENet packet-loss percentage: they may include lost requests/replies, scheduling delays, or session transitions. Prop payload counters exclude protocol overhead and are counted once per broadcast, not multiplied by recipients. An absent RTT on the host is normal; each client measures its path to the host. Flushes occur every five seconds and on connection events.

If snapshots stop for all clients while host frames remain healthy, compare tunnel events and home-network connectivity. If host frame time spikes, investigate the game process. If only one client drops, inspect that client's path before changing the server.
