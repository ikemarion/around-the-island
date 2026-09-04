# ATI 0.23 controlled latency test

Tested September 3, 2026. Production gameplay code, packaged builds, live host and Playit were not modified.

## Method

Two independent headless Godot processes communicate through a local UDP forwarding proxy. The proxy applies randomized per-direction delay and packet loss to actual ENet traffic (including acknowledgments/retransmission). It binds only to loopback: host UDP 28001, proxy UDP 28002. No operating-system network rules or router settings were changed.

Each profile runs a waiting room, manual start, two five-second rounds, rematch, movement reversals followed by stopping, one attempted invisibility activation per round, and pocket-wall replication. A no-delay proxy provides a comparable baseline. Delay values are configured additional round-trip delay, not measured Internet ping. Jitter is independently applied per direction. Loss is per forwarded UDP datagram, not a claim about application-level loss.

## Results

| Added RTT | Per-direction jitter | Configured loss | Client join time | Two rounds/effects/final convergence | Item activations observed |
|---|---|---|---|---|---|
| 0 ms | 0 ms | 0% | 89 ms | Pass | 2/2 |
| 100 ms | ±10 ms | 0% | 287 ms | Pass | 2/2 |
| 200 ms | ±30 ms | 2% | 472 ms | Pass | 2/2 |
| 400 ms | ±60 ms | 5% | 889 ms | Pass | **1/2 — failed** |
| 400 ms repeat | ±60 ms | 5% | 896 ms | Pass | **1/2 — failed again** |

Actual datagram drops in the initial runs: 0/3681, 0/3689, 70/3700, 177/3534. Both processes exited normally; the severe-case client intentionally exited with code 1 because its item assertion failed. No script or parser failures occurred. Host/client final coordinates matched in each profile. This final agreement does not establish that motion felt smooth throughout.

## Confirmed outstanding issue

**P2 — An item press can fail under severe delay/loss.** On the instrumented repeat, the client pressed Q 63 ms into its observed first round. The host finished that round with invisibility still equipped and never observed activation. In round two the client pressed Q at 21 ms, the host activated at 527 ms after its own round start, and the client observed invisibility at 516 ms after its observed round start. Those ages use different round-start observations and must not be subtracted as an exact action-latency measurement.

This rules out the first failure being only a missed visual observation after successful host activation. It does not yet identify whether action transmission, reliable-channel delay, action eligibility, or queue clearing caused the loss. Inspect the reliable action path alongside the 500 ms stale-movement timeout; do not assume the root cause without further instrumentation. The initial and repeat severe runs both missed round-one activation and succeeded in round two.

## Movement measurements and limits

Approximate position-step residual is sampled displacement minus current velocity times elapsed sample time. Maximum residual increased from 0.234 m at baseline to 0.181 m at 100 ms, 0.337 m at 200 ms, and 0.594 m at 400 ms (0.700 m on repeat). The 95th percentile was 0.070, 0.073, 0.124, and 0.136 m respectively (0.153 m on repeat). These values combine network corrections, acceleration, collisions, and sampling timing; they are **not** pure correction distances, teleport counts, or a visual smoothness benchmark.

The camera correction vector was also sampled, but was zero throughout the delayed runs. This does not mean correction-free motion: authoritative-motion fallback can clear that vector. Do not use that field alone as a latency quality metric.

This is a short, one-client-per-profile functional test. It does not certify four-player bandwidth behavior, long sessions, burst outages, asymmetrical links, real Playit routing, physical controllers, or rendered camera feel. No end-to-end real Internet connection was measured.

## Reproduction

- Proxy/orchestration: build/network-test/latency_runner.cjs
- Game probe: build/network-test/latency_probe.gd
- Initial matrix: build/network-test/latency-results.json
- Severe repeat: build/network-test/latency-retest-results.json
- Individual logs: build/network-test/latency-*-host.log and latency-*-client.log. Severe logs contain the instrumented repeat; initial metrics are preserved in the initial JSON.
- Run with Node from the workspace. Optional LATENCY_PROFILE=400ms-rtt-5pct-loss selects the severe case. Requires the local .godot-export-runtime engine. The runner closes its sockets and terminates only its own diagnostic children.

Next step: trace and fix the missed item activation, rerun this matrix, then extend to three clients and burst loss before an actual remote playtest.
