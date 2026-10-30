# Environment-aware falls and antialiasing

User-directed correction: no height-based airborne explosion. Visible sea -> splash, retained car sinks; visible land -> impact breaks car into recognizable parts. Preserve map selection, physics, checkpoints, record rules and +3s recovery. Water sequence 2.4s; land sequence 1.6s. These durations are implementation choices.

- [x] Add failing tests for coherent terrain classification/geometry, no midair destruction, land fragmentation vs water sinking, pause/reset/map cleanup and 4x MSAA.
- [x] Add shared terrain surface geometry/query driven by track JSON. Replace explosion with water splash and land impact effects. Trigger at actual surface height, preserve water car until submerged, recover once.
- [x] Run regression/real render checks, compare AA on/off, review, update docs and GitHub.

Architecture: terrain.gd is single source of visible surface and hit classification; impact_effect.gd owns ephemeral effects; main owns timed recovery. Compatibility MSAA4x; no unsupported FXAA/TAA claim.
