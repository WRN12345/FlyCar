# Road corner repair plan

User-reported defect: overlapping independent road boxes and gaps at bends. Diagnosis also found uniform Catmull-Rom loops/cusps at unevenly spaced control points.

- [x] Reproduce with centerline and ribbon geometry regression tests, including tight turns and seam.
- [x] Replace centerline sampling with centripetal interpolation, arc-length resampling and small local smoothing. Build shared miter-limited cross sections and curvature-aware width taper at the tightest turns.
- [x] Generate continuous road, shoulder, curb, line and guard strips and collider triangles from those cross sections. Preserve only intentional bridge gaps.
- [x] Raycast full course lanes, test driving and existing gameplay regressions, render critical corners, independent review and push.

Constraints: preserve map layout identity, car physics, terrain effects and map lifecycle. Tight inner offsets must not fold; taper width gradually rather than allowing road edges to intersect. Existing true bridge gap remains.
