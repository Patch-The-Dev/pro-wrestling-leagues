param(
    [string]$StudioPath,
    [ValidateSet('All', 'Unit', 'Bootstrap', 'Integration')][string]$Suite = 'All',
    [switch]$Bootstrap,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
if ($Bootstrap) { $Suite = 'Bootstrap' }
$rojo = Join-Path $env:USERPROFILE '.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
if (-not (Test-Path -LiteralPath $rojo)) { $rojo = (Get-Command rojo -ErrorAction SilentlyContinue).Source }
if (-not $rojo -or -not (Test-Path -LiteralPath $rojo)) { throw 'Rojo was not found. Run rokit install first.' }
if (-not $StudioPath) {
    $StudioPath = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\Versions\*\RobloxStudioBeta.exe') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $StudioPath -or -not (Test-Path -LiteralPath $StudioPath)) { throw 'Studio was not found. Supply -StudioPath.' }

function Invoke-StudioCheck([string]$SelectedSuite) {
    $invocation = [guid]::NewGuid().ToString('N')
    $place = Join-Path $env:TEMP "PRO_WRESTLING_LEAGUES-$invocation.rbxlx"
    $output = Join-Path $env:TEMP "PRO_WRESTLING_LEAGUES-$invocation.log"
    $consoleOutput = Join-Path $env:TEMP "PRO_WRESTLING_LEAGUES-$invocation.console.log"
    $project, $runnerName, $marker = switch ($SelectedSuite) {
        'Unit' { 'test.project.json', 'RunInStudio.luau', 'PRO_WRESTLING_LEAGUES_TESTS_PASS' }
        'Bootstrap' { 'default.project.json', 'RunServerBootstrapInStudio.luau', 'PRO_WRESTLING_LEAGUES_SERVER_BOOTSTRAP_PASS' }
        'Integration' { 'integration.project.json', 'RunPlayTest.luau', 'PRO_WRESTLING_LEAGUES_INTEGRATION_PASS' }
    }
    Push-Location $repository
    try {
        & $rojo build $project --output $place | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "Build failed: $project" }
    } finally { Pop-Location }
    $runner = Join-Path $PSScriptRoot $runnerName
    $arguments = '--task RunScript --localPlaceFile "{0}" --runScriptFile "{1}" --outputFile "{2}" --quitAfterExecution' -f $place, $runner, $output
    $startedAt = Get-Date
    $process = Start-Process -FilePath $StudioPath -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $consoleOutput -PassThru
    $deadline = (Get-Date).AddSeconds(240)
    $report = ''
    $markerPattern = '(?m)^\s*' + [regex]::Escape($marker) + '\s*$'
    try {
        while ((Get-Date) -lt $deadline) {
            $report = ''
            if (Test-Path -LiteralPath $output) { $report = Get-Content -LiteralPath $output -Raw }
            if (Test-Path -LiteralPath $consoleOutput) {
                $report += "`n" + ((Get-Content -LiteralPath $consoleOutput -Raw) -replace '(?m)^.*\[FLog::Output\] ', '')
            }
            # Studio multiplayer runs in child processes. Require this run's ID.
            if ($SelectedSuite -eq 'Integration' -and $report -match '(?m)^PRO_WRESTLING_LEAGUES_RUN_ID:([a-fA-F0-9-]+)\s*$') {
                $runId = $Matches[1]
                $resultPattern = 'PRO_WRESTLING_LEAGUES_RESULT:' + [regex]::Escape($runId) + ':(PASS|FAIL):(.+)$'
                $logDirectory = Join-Path $env:LOCALAPPDATA 'Roblox\logs'
                $newLogs = Get-ChildItem -LiteralPath $logDirectory -Filter '*_Studio_*.log' -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -ge $startedAt }
                foreach ($log in $newLogs) {
                    $line = Select-String -LiteralPath $log.FullName -Pattern $resultPattern -ErrorAction SilentlyContinue | Select-Object -Last 1
                    if ($line -and $line.Line -match $resultPattern) {
                        if ($Matches[1] -eq 'PASS') { $report += "`n$($Matches[2]) integration checks passed`n$marker`n" }
                        else { $report += "`nPRO_WRESTLING_LEAGUES_INTEGRATION_FAILURE: $($Matches[2])`n" }
                        break
                    }
                }
            }
            if ($report -match $markerPattern) { break }
            if ($report -match '(?m)^\s*PRO_WRESTLING_LEAGUES_TESTS_FAIL\s*$|^PRO_WRESTLING_LEAGUES_INTEGRATION_FAILURE:|^RunScript:\d+:') { break }
            $process.Refresh()
            if ($process.HasExited) { break }
            Start-Sleep -Milliseconds 500
        }
        if ($report -notmatch $markerPattern) {
            if ($report) { Write-Host $report }
            throw "$SelectedSuite did not report a passing result. Logs: $output"
        }
        $checks = 1
        if ($SelectedSuite -eq 'Unit') {
            $summary = [regex]::Matches($report, '(?m)^\s*(\d+) passed, (\d+) failed, (\d+) skipped\s*$') | Select-Object -Last 1
            if (-not $summary -or $summary.Groups[2].Value -ne '0' -or $summary.Groups[3].Value -ne '0') { throw 'The TestEZ suite failed or skipped tests.' }
            $checks = [int]$summary.Groups[1].Value
        } elseif ($SelectedSuite -eq 'Integration') {
            if ($report -notmatch '(?m)^\s*(\d+) integration checks passed\s*$') { throw 'Missing integration count.' }
            $checks = [int]$Matches[1]
        }
        if ($checks -lt 1) { throw 'The suite executed no checks.' }
        Write-Host "$SelectedSuite`: $checks checks passed"
        return [pscustomobject]@{ suite = $SelectedSuite; status = 'passed'; checks = $checks }
    } finally {
        $exitDeadline = (Get-Date).AddSeconds(8)
        do {
            $process.Refresh()
            if ($process.HasExited) { break }
            Start-Sleep -Milliseconds 200
        } while ((Get-Date) -lt $exitDeadline)
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    }
}

$results = [System.Collections.Generic.List[object]]::new()
$completed = $false
$failureReason = $null
try {
    $selected = if ($Suite -eq 'All') { @('Unit', 'Bootstrap', 'Integration') } else { @($Suite) }
    foreach ($item in $selected) { $results.Add((Invoke-StudioCheck $item)) }
    $completed = $true
} catch {
    $failureReason = $_.Exception.Message
    throw
} finally {
    if ($ReportPath) {
        $absoluteReport = [System.IO.Path]::GetFullPath($ReportPath)
        New-Item -ItemType Directory -Path (Split-Path -Parent $absoluteReport) -Force | Out-Null
        [ordered]@{
            commit = (git -C $repository rev-parse HEAD)
            workingTreeDirty = [bool](git -C $repository status --porcelain)
            finishedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            status = $(if ($completed) { 'passed' } else { 'failed' })
            suites = @($results.ToArray())
            error = $failureReason
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $absoluteReport -Encoding utf8
    }
}
