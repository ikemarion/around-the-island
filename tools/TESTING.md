# Automated checks

From the project folder, use PowerShell 7.2 or later:

```powershell
pwsh -File tools/run_tests.ps1
pwsh -File tools/run_tests.ps1 -Suite All
pwsh -File tools/run_tests.ps1 -Suite Network
pwsh -File tools/run_tests.ps1 -Test scaling_regression,network_lifecycle
pwsh -File tools/run_tests.ps1 -Suite All -List
pwsh -File tools/run_tests.ps1 -SelfTest
```

The default is the short `Smoke` suite. `Gameplay`, `Art`, and `Network` select
focused checks; `All` runs every automated correctness test. `Soak` explicitly
runs the three-minute, four-player loopback soak separately. The modular-map test
also exercises the live bot crossing all three rooms.

Pass `-Godot C:\path\to\Godot.exe` or set `GODOT`. On the original workstation,
the runner also finds the bundled runtime two folders above this project. Use
the project's Godot 4.7.2 runtime. A fresh checkout is imported first; use
`-SkipImport` only when resources are already imported. Logs and JSON results
go to `build/test-results/<run-id>/` and remain ignored by Git.

Each test gets a 45-second wall-clock deadline (`-TimeoutSeconds` overrides it).
The soak gets at least 230 seconds. A test passes only after natural exit code 0,
no engine/script errors, and its explicit success marker. Three older tests
(`network_code_smoke`, `sfx_smoke`, and `stun_gun_smoke`) intentionally use a clean
exit 0 without a marker. A failed GDScript assertion can otherwise leave Godot
running or exit 0; both are detected. The runner never uses `--quit-after` to
manufacture success. Existing object-leak warnings are retained in logs but are
not silently converted into test failures. The only generic error exemption is
Windows' unavailable certificate store; the expected ENet bind-conflict error
is allowed only in its dedicated hosting regression.

Network tests launch the host, wait for `HOST_READY`, then launch clients on
loopback. Pairs run serially because legacy fixtures share fixed ports. A locked
runner file prevents concurrent runner instances; occupied UDP ports cause a
failure without stopping another server. Timeout/interrupt cleanup terminates
only processes created by that invocation. `--ati-test-instance` avoids the
normal one-window lock and profile persistence, and source runs use workspace
diagnostics. `hosting_end_to_end` and `router_discovery` remain manual because they
can use the configured public tunnel or real router. Preview/capture scripts
also remain manual; headless execution cannot verify their images.

# Player and test exports

`Windows Desktop` retains all runtime resources (including dynamically loaded
characters, room art, fonts and power-ups), but excludes `tests`, `docs`, `tools`,
old `releases`, build output, Markdown, and the obsolete `scripts/main.gd`.

Use the separate test preset for tests against an exported resource pack:

```powershell
& $env:GODOT --headless --path . --export-pack 'Windows Tests' build/ATI-tests.pck
pwsh -File tools/run_tests.ps1 -TestPack build/ATI-tests.pck -Suite Smoke
```

The test pack runs in the editor/debug engine, from the pack's folder rather
than the source tree. Its first check proves `assert()` executes using a side
effect sentinel, and fails explicitly if assertions were removed. Official
standalone templates do not support `--path` and ignore `--script`; including
tests in a debug executable therefore does not make them runnable by these flags.
Packaged checks use the game's normal writable user-data diagnostics folder;
they need permission to write there. `Smoke` is the verified packaged suite.
Some other fixtures explicitly write screenshots or diagnostic reports under
`res://build`, and should run against the source checkout instead of a read-only
resource pack.
The clean player executable intentionally has no test scripts. Smoke-test it by
starting that executable in an isolated
folder with `--headless --quit-after 120 -- --ati-test-instance`; inspect logs for
errors, then perform a normal interactive start/join/play check. That bounded
launch checks startup, not assertion-based correctness or visual quality.

# Continuous integration and future release storage

`.github/workflows/tests.yml` runs the same source runner on Windows for pushes
and pull requests and retains test logs. It downloads the official pinned Godot
4.7.2 engine. Local validation is still required for rendered art and WAN play.

The existing tracked ZIP download links remain intact. A future release can
attach its verified ZIP to a GitHub Release instead of committing another large
binary: package the player export, compute a SHA-256 checksum, upload both to a
versioned draft release, verify the download, and update README to that asset.
Historical ZIP removal or Git history rewriting is a separate decision; neither
is needed for this test/export cleanup.
