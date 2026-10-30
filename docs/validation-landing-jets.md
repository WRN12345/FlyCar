# Landing jets verification

Current control override (2026-10-30): user selected manual descent. Automatic assist is disabled by default. Space during descent supplies body-up braking without takeoff forward bias; arrows control attitude. HUD reads DESCENT BRAKE. The earlier automatic-assist measurements below remain regression coverage for the optional developer setting.

User approved the linked Bilibili reference as inspiration for a three-phase gas effect. The game parameters are original tuning, not measured Tesla specifications.

## Behavior

- Space retains the existing full manual short burst. Airborne arrows allocate actual nozzle duties; no gas means no free attitude torque.
- Automatic touchdown braking only runs while descending, upright, above upward-facing marked track collision with at least three valid probes. No automatic rescue above terrain, water, empty gaps or an inverted chassis.
- The same tank supplies manual/attitude/landing jets. Last fractional gas scales all forces, and partial duty costs proportional gas. Recharge retains the 0.8s grounded delay.
- White soft-edge mist sprites (448 particles maximum) follow actual thrust direction. Contact mist uses independent exhaust-direction physics rays. Existing gas fades when emission stops; freeze, impact or recovery clears old emission and audio.
- Explicit white unshaded billboard shader replaces a StandardMaterial particle path that produced black discs on the native Compatibility renderer. Native captures verified white semi-transparent clouds.

## Validation

Godot 4.7.2 Compatibility / OpenGL on AMD Radeon 780M, 120 Hz Jolt.

- Controller: 11 checks for ascent, inversion, road exclusion, bounds, torque and proportional fuel.
- Real physics: 8 checks including paired drops, no-gas control, terrain exclusion, pitch force and pause/reset.
- Effect lifecycle: 7 checks including freeze/hide/reset, surface contact, natural fading and tilted exhaust alignment.
- Paired drop from chassis y=6m with initial vertical velocity -8m/s: first tire contact speed 12.181m/s without assist, 2.411m/s with full gas and assist.
- Native screenshots: takeoff, attitude, landing brake and touchdown via tests/capture_jets.gd. Native rendering checked after replacing the black-disc particle material.
- Prior 130 physics/race/track/surface/mesh checks remain part of tests/run.ps1.

Run tests/run.ps1 -Godot <Godot-console.exe>. Render tests/capture_jets.gd with -- <output-directory>. No external assets required. Final full suite result recorded in the implementation plan.
