param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $project '.godot/test-logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
function Invoke-Check([string]$Name, [string[]]$Arguments) {
    $output = & $Godot --headless --path $project --log-file (Join-Path $logs "$Name.log") @Arguments 2>&1
    $code = $LASTEXITCODE
    $output | Write-Output
    if ($code -ne 0 -or ($output | Select-String 'SCRIPT ERROR:|^ERROR:')) {
        throw "$Name failed (exit $code); see $logs"
    }
}
Invoke-Check 'import' @('--editor', '--import')
foreach ($name in @('math', 'physics', 'race', 'world', 'obstacles', 'catalog', 'china', 'china_obstacles', 'surfaces', 'road_corners', 'car_visual', 'jets', 'landing', 'jet_effects')) {
    Invoke-Check $name @('--script', "tests/test_$name.gd")
}
Write-Output 'PASS: all FlyCar checks completed.'
