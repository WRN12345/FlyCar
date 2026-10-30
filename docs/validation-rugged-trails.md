# Narrow rugged trails verification

User correction: narrower realistic-feeling routes, repeated climbing/descending and actual rock ground.

- 4.7m classified trail width, 0.3m soft shoulder on each side. Flags placed 2.9m from center. Texture width and tire classification use the same constants.
- 0.5m-per-pixel world-space mask keeps road boundaries narrow on the unchanged 4m collision grid. RGBA colors are explicitly linearized for Compatibility rendering, with mipmaps and distance-filtered procedural detail.
- Repeated rolling terrain changes the actual collider and vehicle load. The starting grid is relatively flat. Steepest main-route surface still passes the previous normal.y >=0.88 guard.
- Main-route elevation relief 32.3m. Grade threshold +/-10% groups yield 8 climbs/9 descents, covering 545.2m uphill and 546.2m downhill. These are original game terrain metrics, not survey data.
- Physical convex shoulder boulders and low bedrock plates; dense rocks excluded from calibrated canyon launch/landing corridor. Roadster suspension, damage and manual finite gas retained.
- Full regression plus six new checks: 204 checks green. Last rock-density update reran affected terrain, drive, full physical lap and both shortcuts. Lap 276.67 seconds without recovery; 2/2 shortcuts returned through ordered checkpoints.
- Native climb/descent/rock/river/menu screenshots inspected. Shader color correction removed overly bright yellow road; rock face is continuous through the inside bend.
- Independent read-only review completed twice. Mask storage approximately 40.5MB CPU plus similar GPU; fixed per-course allocation, no per-frame regeneration.

Run tests/run.ps1 -Godot <console-exe>. tests/capture_offroad.gd writes the native views. Terrain remains procedural and stylized; this update improves physical route scale and roughness, not a photogrammetric replica.
