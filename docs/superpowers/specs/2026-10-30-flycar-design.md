# FlyCar first playable design
Approved in chat on 2026-10-30.

Godot 4.7 desktop 3D single-car time trial. Original simplified mesh inspired by the second-generation Tesla Roadster, not a licensed production asset. Four raycast wheels on a rigid chassis simulate suspension, damping, tire grip, steering and weight transfer. Short finite cold-gas bursts apply forces at four nozzles; limited airborne torque control, real gravity, collision and rollover. Landing recharges the tank. W/S throttle/brake/reverse, A/D steer, Space burst, arrows airborne attitude, R checkpoint recovery, Enter restart, Esc pause.

A closed test circuit has a straight tuning section, bends, low barriers, broken bridge, optional aerial shortcut. Sequential checkpoints prevent skipping; timer, speed, fuel and wheel contact HUD. No multiplayer or AI in v1. Procedural original scenery and car geometry avoid downloaded asset licenses.

Approaches considered: arcade controller vs rigid-body physics. User explicitly chose physical simulation. Custom raycast suspension is chosen over VehicleBody3D for explicit, inspectable tire/nozzle forces and tunable handling.
