param(
    [string]$StudioPath,
    [switch]$Bootstrap
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$place = Join-Path $env:TEMP 'ProWrestlingLeaguesStudioCheck.rbxlx'
$output = Join-Path $env:TEMP 'ProWrestlingLeaguesStudioCheck.log'
$rojo = (Get-Command rojo -ErrorAction SilentlyContinue).Source
if (-not $rojo) {
    $rojo = Join-Path $env:USERPROFILE '.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
}
if (-not (Test-Path -LiteralPath $rojo)) {
    throw 'Rojo was not found. Install the pinned tools with rokit install.'
}

if (-not $StudioPath) {
    $StudioPath = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\Versions\*\RobloxStudioBeta.exe') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $StudioPath -or -not (Test-Path -LiteralPath $StudioPath)) {
    throw 'Roblox Studio was not found. Pass -StudioPath with the installed executable.'
}

$project = if ($Bootstrap) { 'default.project.json' } else { 'test.project.json' }
$runner = if ($Bootstrap) { 'RunServerBootstrapInStudio.luau' } else { 'RunInStudio.luau' }
$sentinel = if ($Bootstrap) { 'PRO_WRESTLING_LEAGUES_SERVER_BOOTSTRAP_PASS' } else { 'PRO_WRESTLING_LEAGUES_TESTS_PASS' }

Push-Location $repository
try {
    & $rojo build $project --output $place
    if ($LASTEXITCODE -ne 0) {
        throw "The Rojo build failed: $project"
    }
} finally {
    Pop-Location
}

Remove-Item -LiteralPath $output -ErrorAction SilentlyContinue
$runnerPath = Join-Path $PSScriptRoot $runner
$arguments = '--task RunScript --localPlaceFile "{0}" --runScriptFile "{1}" --outputFile "{2}" --quitAfterExecution' -f $place, $runnerPath, $output
$process = Start-Process -FilePath $StudioPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
try {
    Wait-Process -Id $process.Id -Timeout 180 -ErrorAction Stop
} catch {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw 'Studio did not finish the check within three minutes.'
}
$process.Refresh()

if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $output)) {
    throw "Studio did not produce a passing report. Exit code: $($process.ExitCode)"
}
$report = Get-Content -LiteralPath $output -Raw
if ($report -notmatch "(?m)^\s*$sentinel\s*$" -or (-not $Bootstrap -and $report -notmatch '(?m)^\s*\d+ passed, 0 failed, 0 skipped\s*$')) {
    Write-Output $report
    throw 'Pro Wrestling Leagues Studio check failed.'
}
$report -split '\r?\n' | Where-Object { $_ -match '^\d+ passed, 0 failed, 0 skipped$|^PRO_WRESTLING_LEAGUES_.*_PASS$' }
