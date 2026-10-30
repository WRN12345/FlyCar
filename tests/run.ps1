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
foreach ($name in @('math', 'physics', 'race', 'world', 'obstacles', 'catalog', 'china', 'china_obstacles', 'surfaces', 'road_corners', 'car_visual', 'jets', 'landing', 'jet_effects', 'offroad_model', 'offroad', 'offroad_drive', 'rugged_trails', 'repeat_jets', 'forest_scene', 'mouse_look')) {
    Invoke-Check $name @('--script', "tests/test_$name.gd")
}
Invoke-Check 'offroad_lap' @('--fixed-fps','120','--script','tests/test_offroad_lap.gd')
Invoke-Check 'offroad_shortcuts' @('--fixed-fps','120','--script','tests/test_offroad_shortcuts.gd')
Write-Output 'PASS: all FlyCar checks completed.'
