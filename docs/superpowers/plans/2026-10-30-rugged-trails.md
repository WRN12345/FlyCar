# Narrow rugged trail refinement

User requests narrower, more realistic off-road trails with frequent climbs/descents and actual rock terrain. Implement in place, preserving Roadster/manual finite jets and legacy tracks.

- [x] Add failing checks for repeated uphill/downhill segments, narrow trail classification, visible-width mask and physical trail rocks.
- [x] Keep terrain collision/query triangles identical; add continuous rolling elevations to the route and protect river/canyon launch calibration. Use a 0.5m raster trail mask for accurate 4.7m visual width without multiplying terrain collision polygons. Tighten surface classification and flags to the same half-width.
- [x] Place low protruding rock plates and shoulder boulders with real colliders, preserving a navigable center corridor.
- [x] Run physical lap and shortcuts, complete regression, native captures and independent review; update docs and sync GitHub.

Verification: full original regression plus new narrow-trail checks (204 checks total). After the last rock density/material refinement, reran all affected terrain, driving, lap and shortcut checks; green. Physical lap: 276.67s, no recovery; shortcuts 2/2. Measured >10% grade segments: uphill 545.2m/downhill 546.2m, 8/9 sign groups; route relief 32.3m. Native captures inspected after linearizing the trail texture; two independent review passes found no remaining blockers. The image mask costs approximately 40.5MB CPU and similar GPU storage, avoiding a global collision mesh subdivision. Godot reordered project.godot settings without changing their values; that unrelated working-file rewrite is preserved outside this commit.
