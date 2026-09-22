#Requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('Smoke', 'Gameplay', 'Network', 'Art', 'All', 'Soak')]
    [string]$Suite = 'Smoke',
    [string[]]$Test = @(),
    [string]$Godot = $env:GODOT,
    [string]$TestPack,
    [ValidateRange(1, 600)] [int]$TimeoutSeconds = 45,
    [switch]$SkipImport,
    [switch]$SelfTest,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
$testDirectory = Join-Path $projectRoot 'tests'
$pairs = @{
    chaos_network_smoke = @{ HostFlag = '--chaos-host'; ClientFlag = '--chaos-client'; Port = 27995; Clients = 1 }
    network_lifecycle = @{ HostFlag = '--lifecycle-host'; ClientFlag = ''; Port = 27992; Clients = 1 }
    client_start_regression = @{ HostFlag = '--start-host'; ClientFlag = ''; Port = 27996; Clients = 1 }
    character_selection_network = @{ HostFlag = '--character-host'; ClientFlag = ''; Port = 27996; Clients = 1 }
    decoy_skin_network = @{ HostFlag = '--decoy-host'; ClientFlag = ''; Port = 27997; Clients = 1 }
    score_ribbons_network = @{ HostFlag = '--ribbons-host'; ClientFlag = ''; Port = 27994; Clients = 1 }
    sockling_network_animation = @{ HostFlag = '--animation-host'; ClientFlag = ''; Port = 27993; Clients = 1 }
    stun_gun_network_art = @{ HostFlag = '--stun-host'; ClientFlag = ''; Port = 27996; Clients = 1 }
    report_transfer_smoke = @{ HostFlag = '--report-host'; ClientFlag = ''; Port = 27993; Clients = 1 }
    network_audit_lobby = @{ HostFlag = '--network-audit-host'; ClientFlag = '--network-audit-client'; Port = 27996; Clients = 1 }
    network_soak = @{ HostFlag = '--soak-host'; ClientFlag = ''; Port = 27994; Clients = 3 }
}
# These three reviewed legacy tests explicitly quit(0) but have no success print.
# They still must exit naturally before the deadline, without engine/script errors.
$intentionalSilentExit = @('network_code_smoke', 'sfx_smoke', 'stun_gun_smoke')
$completionOverrides = @{
    network_lifecycle = 'NETWORK_LIFECYCLE (host: two joins/disconnects clean|client: rejoin, effects and quick action passed)'
    chaos_network_smoke = 'CHAOS_NETWORK (all five effects replicated|host created all five effects)'
    sockling_network_animation = 'SOCKLING_NETWORK (host: existing snapshots sent|client: remote walk/rise/apex/fall/land/crouch)'
    network_audit_lobby = 'NETWORK_AUDIT_LOBBY (host|client) failures=0\b'
    network_bandwidth_regression = 'NETWORK_BANDWIDTH .*failures=0\b'
}
$smoke = @('network_code_smoke', 'scaling_regression', 'multiplayer_regression', 'obstacle_interaction', 'modular_house_smoke', 'menu_smoke')
$artPattern = 'art|animation|arm_rig|visual|decoy_skin$|house_prop|kitchen_art|pickup_visual|spark_indicator|distant_scoreboard'
$networkPattern = 'network|hosting|routing|default_join|client_start|report|diagnostic|round_transition|scaling|obstacle_batch'
$allTests = @(Get-ChildItem -LiteralPath $testDirectory -Filter '*.gd' | Select-Object -ExpandProperty BaseName | Sort-Object)
# These are capture tools or external-router/tunnel diagnostics, not automated
# local tests. In particular hosting_end_to_end rejoins the real Playit address.
$manualOnly = @($allTests | Where-Object { $_ -match '_preview$' }) + @('router_discovery', 'hosting_end_to_end')
$automated = @($allTests | Where-Object { $_ -notin $manualOnly -and $_ -ne 'network_soak' })
if ($Test.Count -gt 0) {
    $selected = @($Test | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Select-Object -Unique)
    foreach ($name in $selected) {
        if ($name -notin $allTests) { throw "Unknown test '$name'. Use -List to see available tests." }
        if ($name -in $manualOnly) { throw "'$name' is a manual capture/external-network diagnostic; see tools/TESTING.md." }
    }
} else {
    $selected = @(switch ($Suite) {
        'Smoke' { $smoke }
        'Gameplay' { $automated | Where-Object { -not $pairs.ContainsKey($_) -and $_ -notmatch $networkPattern -and $_ -notmatch $artPattern } }
        'Network' { $automated | Where-Object { $pairs.ContainsKey($_) -or $_ -match $networkPattern } }
        'Art' { $automated | Where-Object { -not $pairs.ContainsKey($_) -and $_ -match $artPattern } }
        'All' { $automated }
        'Soak' { 'network_soak' }
    })
}
if ($List) {
    foreach ($name in $selected) {
        $mode = if ($pairs.ContainsKey($name)) { 'paired loopback' } else { 'single process' }
        Write-Output "$name ($mode)"
    }
    exit 0
}
if ($selected.Count -eq 0) { throw 'No tests selected.' }
if (-not $Godot) {
    $bundled = Join-Path $projectRoot '../../.godot-export-runtime/godot.windows.opt.tools.64.exe'
    if (Test-Path -LiteralPath $bundled) { $Godot = $bundled }
    else {
        $command = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $Godot = $command.Source }
    }
}
if (-not $Godot) { throw 'Pass -Godot <Godot 4.7.2 executable> or set GODOT.' }
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$packPath = if ($TestPack) { (Resolve-Path -LiteralPath $TestPack).Path } else { '' }
$resourceRoot = if ($packPath) { Split-Path -Parent $packPath } else { $projectRoot }
$outputRoot = Join-Path $projectRoot 'build/test-results'
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
# Avoid two runner invocations racing over the suites' fixed loopback ports.
$runnerLock = [IO.File]::Open((Join-Path $outputRoot 'runner.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
$runDirectory = Join-Path $outputRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff') + '-' + $PID)
[IO.Directory]::CreateDirectory($runDirectory) | Out-Null
$ownedProcesses = [Collections.Generic.List[object]]::new()
$results = [Collections.Generic.List[object]]::new()

function Start-CheckedProcess([string]$Name, [string[]]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $enginePath
    $info.WorkingDirectory = $resourceRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "Could not start $Name" }
    $record = [pscustomobject]@{
        Name = $Name; Process = $process; Started = [DateTime]::UtcNow
        Stdout = $process.StandardOutput.ReadToEndAsync(); Stderr = $process.StandardError.ReadToEndAsync()
        EngineLog = Join-Path $runDirectory "$Name.engine.log"; TimedOut = $false
    }
    $ownedProcesses.Add($record)
    return $record
}

function Stop-OwnedProcess($Record) {
    if (-not $Record.Process.HasExited) {
        # This Process handle came from this invocation; never kill by image name.
        $Record.Process.Kill($true)
        $Record.Process.WaitForExit(5000) | Out-Null
    }
}

function Get-CompletionPattern([string]$Name) {
    if ($completionOverrides.ContainsKey($Name)) { return $completionOverrides[$Name] }
    $source = Get-Content -LiteralPath (Join-Path $testDirectory "$Name.gd") -Raw
    $markers = @([regex]::Matches($source, '(?m)^\s*print\("([^"\r\n]+)"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -match '(?i)\bpass(?:ed)?\b|failures=$' })
    $patterns = @($markers | ForEach-Object {
        if ($_.EndsWith('failures=')) { [regex]::Escape($_) + '0\b' }
        else { [regex]::Escape($_) }
    })
    if ($patterns.Count -eq 0 -and $Name -notin $intentionalSilentExit) { throw "No completion marker registered for $Name" }
    return ($patterns -join '|')
}

function Get-Outcome($Record, [string]$Pattern, [bool]$AllowSilent = $false) {
    $Record.Process.WaitForExit()
    $stdout = $Record.Stdout.GetAwaiter().GetResult()
    $stderr = $Record.Stderr.GetAwaiter().GetResult()
    $combined = $stdout + [Environment]::NewLine + $stderr
    [IO.File]::WriteAllText((Join-Path $runDirectory ($Record.Name + '.log')), $combined)
    # Windows sandbox/certificate-store availability does not affect these
    # local tests. All other errors, including assert() followed by exit(0), fail.
    $badLines = @($combined -split '\r?\n' | Where-Object {
        $_ -match '^\s*(SCRIPT ERROR:|ERROR:)' -and
        $_ -notmatch '^ERROR: Failed to read the root certificate store\.$' -and
        -not ($Record.Name -eq 'hosting_regression' -and $_ -match '^ERROR: (Couldn.t create an ENet host\.|Condition "!host" is true\. Returning: ERR_CANT_CREATE)')
    })
    $reasons = @()
    if ($Record.TimedOut) { $reasons += 'wall-clock timeout' }
    if ($Record.Process.ExitCode -ne 0) { $reasons += "exit $($Record.Process.ExitCode)" }
    if ($badLines.Count -gt 0) { $reasons += $badLines }
    if (-not $AllowSilent -and ($Pattern.Length -eq 0 -or $combined -notmatch $Pattern)) { $reasons += 'missing completion marker' }
    return [pscustomobject]@{
        Name = $Record.Name; Passed = $reasons.Count -eq 0
        Seconds = [Math]::Round(([DateTime]::UtcNow - $Record.Started).TotalSeconds, 2)
        Reasons = $reasons; Log = Join-Path $runDirectory ($Record.Name + '.log')
    }
}

function Wait-CheckedProcesses([object[]]$Records, [int]$DeadlineSeconds) {
    while (@($Records | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
        foreach ($record in $Records) {
            if (-not $record.Process.HasExited -and ([DateTime]::UtcNow - $record.Started).TotalSeconds -gt $DeadlineSeconds) {
                $record.TimedOut = $true
                Stop-OwnedProcess $record
            }
        }
        Start-Sleep -Milliseconds 100
    }
}

function Assert-PortAvailable([int]$Port) {
    $probe = [Net.Sockets.UdpClient]::new()
    try {
        $probe.Client.ExclusiveAddressUse = $true
        $probe.Client.Bind([Net.IPEndPoint]::new([Net.IPAddress]::Any, $Port))
    } catch { throw "UDP $Port is already occupied. The runner will not stop an existing server." }
    finally { $probe.Dispose() }
}

function Start-Test([string]$Name, [string]$Role, [string[]]$Extra) {
    $label = if ($Role) { "$Name-$Role" } else { $Name }
    $arguments = @('--headless', '--path', $resourceRoot)
    # Use the debug/editor engine with the exported pack. Official templates
    # disable --path/--script, so a test .exe silently runs the game instead.
    if ($packPath) { $arguments += @('--main-pack', $packPath) }
    $arguments += @('--log-file', (Join-Path $runDirectory "$label.engine.log"), '--script', "res://tests/$Name.gd", '--', '--ati-test-instance')
    # res:// is writable in a source checkout, but read-only inside a PCK.
    # Packaged tests use the same user:// diagnostics directory as the game.
    if (-not $packPath) { $arguments += '--diagnostics-workspace' }
    if ($Name -eq 'modular_house_smoke') { $arguments += '--check-bot' }
    $arguments += @($Extra | Where-Object { $_ })
    return Start-CheckedProcess $label $arguments
}

try {
    Write-Host "Logs: $runDirectory"
    if (-not $TestPack -and -not $SkipImport) {
        $import = Start-CheckedProcess 'import' @('--headless', '--editor', '--path', $projectRoot, '--log-file', (Join-Path $runDirectory 'import.engine.log'), '--import', '--quit')
        Wait-CheckedProcesses @($import) 120
        $outcome = Get-Outcome $import '' $true
        if (-not $outcome.Passed) { throw "Godot import failed: $($outcome.Reasons -join '; '). See $($outcome.Log)" }
    }
    if ($SelfTest) {
        if ($TestPack) { throw '-SelfTest checks the runner itself; omit -TestPack.' }
        $errorProbe = Join-Path $runDirectory 'error_probe.gd'
        [IO.File]::WriteAllText($errorProbe, "extends SceneTree`nfunc _initialize():`n`tpush_error('Expected runner self-test error')`n`tprint('HARNESS_PROBE PASS')`n`tquit(0)`n")
        $record = Start-CheckedProcess 'error-probe' @('--headless', '--path', $projectRoot, '--log-file', (Join-Path $runDirectory 'error-probe.engine.log'), '--script', $errorProbe)
        Wait-CheckedProcesses @($record) 10
        $outcome = Get-Outcome $record 'HARNESS_PROBE PASS'
        if ($outcome.Passed -or $record.Process.ExitCode -ne 0 -or @($outcome.Reasons | Where-Object { $_ -match 'Expected runner self-test error' }).Count -ne 1) { throw 'Runner failed to reject an engine error followed by success text and exit 0.' }
        $timeoutProbe = Join-Path $runDirectory 'timeout_probe.gd'
        [IO.File]::WriteAllText($timeoutProbe, "extends SceneTree`nfunc _initialize():`n`tprint('HARNESS_PROBE PASS')`n")
        $record = Start-CheckedProcess 'timeout-probe' @('--headless', '--path', $projectRoot, '--log-file', (Join-Path $runDirectory 'timeout-probe.engine.log'), '--script', $timeoutProbe)
        Wait-CheckedProcesses @($record) 1
        $outcome = Get-Outcome $record 'HARNESS_PROBE PASS'
        if ($outcome.Passed -or -not $record.TimedOut) { throw 'Runner failed to reject a hung process that printed success.' }
        Write-Host 'RUNNER_SELF_TEST PASS: errors override exit 0 and success text; timeout kills only the owned process.'
        exit 0
    }
    # Both source and packaged runs must retain assertions, even if a caller
    # accidentally supplies a release executable with test files embedded.
    $guard = Start-Test 'test_export_environment' '' @()
    Wait-CheckedProcesses @($guard) $TimeoutSeconds
    $guardResult = Get-Outcome $guard 'TEST_EXPORT_ENVIRONMENT PASS'
    if (-not $guardResult.Passed) { throw "Test environment rejected: $($guardResult.Reasons -join '; '). See $($guardResult.Log)" }
    foreach ($name in $selected) {
        $records = @()
        $pattern = ''
        $deadline = if ($name -eq 'network_soak') { [Math]::Max(230, $TimeoutSeconds) } else { $TimeoutSeconds }
        try {
            $pattern = Get-CompletionPattern $name
            if ($pairs.ContainsKey($name)) {
                $pair = $pairs[$name]
                Assert-PortAvailable $pair.Port
                $hostRecord = Start-Test $name 'host' @($pair.HostFlag)
                $records += $hostRecord
                $readyDeadline = [DateTime]::UtcNow.AddSeconds([Math]::Min(12, $deadline))
                $ready = $false
                while (-not $hostRecord.Process.HasExited -and [DateTime]::UtcNow -lt $readyDeadline) {
                    if (Test-Path -LiteralPath $hostRecord.EngineLog) {
                        $ready = (Get-Content -LiteralPath $hostRecord.EngineLog -Raw) -match 'ATI_NETWORK HOST_READY'
                        if ($ready) { break }
                    }
                    Start-Sleep -Milliseconds 100
                }
                if (-not $ready) { throw 'host did not advertise its ready listener' }
                for ($client = 1; $client -le $pair.Clients; $client++) {
                    $records += Start-Test $name "client$client" @($pair.ClientFlag)
                }
            } else {
                $source = Get-Content -LiteralPath (Join-Path $testDirectory "$name.gd") -Raw
                foreach ($port in @([regex]::Matches($source, '(?:host_room|create_server)\((\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Select-Object -Unique)) { Assert-PortAvailable $port }
                $records += Start-Test $name '' @()
            }
            Wait-CheckedProcesses $records $deadline
            foreach ($record in $records) {
                $outcome = Get-Outcome $record $pattern ($name -in $intentionalSilentExit)
                $results.Add($outcome)
                $status = if ($outcome.Passed) { 'PASS' } else { 'FAIL' }
                Write-Host ("{0} {1} ({2}s) {3}" -f $status, $outcome.Name, $outcome.Seconds, ($outcome.Reasons -join '; '))
            }
        } catch {
            foreach ($record in $records) {
                Stop-OwnedProcess $record
                $saved = Get-Outcome $record $pattern ($name -in $intentionalSilentExit)
                $results.Add($saved)
            }
            $results.Add([pscustomobject]@{ Name = $name; Passed = $false; Seconds = 0; Reasons = @($_.Exception.Message); Log = $runDirectory })
            Write-Host "FAIL $name : $($_.Exception.Message)"
        }
    }
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDirectory 'results.json')
    $failed = @($results | Where-Object { -not $_.Passed }).Count
    Write-Host "$($results.Count - $failed)/$($results.Count) test processes passed. Logs: $runDirectory"
    if ($failed -gt 0) { exit 1 }
} finally {
    foreach ($record in $ownedProcesses) {
        Stop-OwnedProcess $record
        $record.Process.Dispose()
    }
    $runnerLock.Dispose()
}
