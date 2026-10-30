# Silver Roadster visual verification

Reference: user-supplied rear three-quarter image from https://www.tesla.cn/roadster/reserve#payment. The page is dynamic; the supplied image was used for the shape. No official image or CAD asset is redistributed.

- Original procedural silver body with wheel openings, fastback glass, window frames, five-spoke wheels, rear light bar and diffuser.
- All visible wheel parts spin together; brake calipers stay on the wheel carrier.
- Existing rigid-body dimensions, suspension, tire forces and thrusters retained. Land debris uses the new silver paint.
- Godot 4.7.2 import and 11 regression scripts: 130/130 checks passed, including 3 new geometry/wheel-motion checks.
- Native OpenGL captures inspected from rear three-quarter, front three-quarter, side and rear. Gameplay capture completed on all three maps with 4x MSAA, sinking and wreck capture.
- Simplified game geometry; not a production CAD model or exact reproduction.

Reproduce: run tests/run.ps1 with Godot 4.7.2. Studio renders: godot --path . --script tests/capture_car.gd -- <output-directory>. Gameplay renders: godot --path . --script tests/capture.gd -- <output-directory>.
