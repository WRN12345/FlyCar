# First playable validation — 2026-10-30

Environment: Windows, Godot 4.7.2 official ed1daf0bf, Jolt, 120Hz physics, Compatibility / OpenGL 3.3 on AMD Radeon 780M.

## Evidence

- Vehicle math: 6 checks — empty/airborne/ground fuel behavior and tire friction limits.
- Physical vehicle: 8 checks — four-wheel settling, chassis support, acceleration, steering, lift, fuel exhaustion, gravity after exhaustion, reset momentum.
- Race state: 7 checks — ordered forward crossings, duplicate/skip rejection, finish last, restart.
- Playable circuit: 10 checks — actual missing bridge collision, intact approach, gate count, recovery fuel/penalty, restart after countdown, pause/resume, immutable completed result.
- Obstacles/HUD: 4 checks — real-input physics clears barrier and bridge; timer/speed HUD inside viewport.
- Actual viewport renders inspected; corrected procedural mesh triangle winding, wheel stance, HUD anchors, status overlap, hint contrast and start position to keep the start gantry behind the chase camera.
- Independent code review identified post-finish recovery changing recorded time. Added a regression that failed, fixed `recover()` to preserve the result, and confirmed the regression passes.

Run all 35 checks with `tests/run.ps1`. Source scripts are loaded by real Godot processes; the obstacle tests drive real rigid-body simulation, not a mocked vehicle. Editor import and screenshot capture are separate checks.

## Execution decisions

- Implemented inline after the user's explicit design approval and push authorization. Initial folder had no Git repository and target remote was empty; initialized its first main branch without replacing existing history.
- Chose four custom raycast suspension wheels so tire/load/nozzle forces remain inspectable. Did not use VehicleBody3D or scripted flight trajectories.
- APPDATA and LOCALAPPDATA were redirected to this chat's writable work/runtime only for sandboxed validation. The game uses normal Godot user data when run by its owner.
- Production code, tests, README, original procedural geometry and screenshots are included. Generated `.godot` cache is excluded.

## Limits

The car is an original simplified second-generation Roadster-inspired mesh, not an exact latest-production CAD reconstruction. No external reference assets copied. Main-line obstacle crossings are automated and reproducible; optional aerial shortcut and a complete human-driven lap still need playtesting. No audio, AI opponents, multiplayer, detailed interiors or standalone executable in this first code delivery.
