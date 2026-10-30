# Road corner repair validation — 2026-10-30

Root causes: independently rotated rectangular road/curb/guard pieces did not share corner edges; uniform Catmull-Rom with unevenly spaced control points produced tiny loops and near-cusps (up to about90 degrees in the old sampled tangent).

Repair: centripetal interpolation, closed arc-length2.5m resampling and6m smoothing. Continuous shared, miter-limited cross sections drive road, shoulder, line, curb and low guard strips. Curvature-aware width taper prevents inner offsets folding in pinched hairpins; nominal asphalt18m, minimum6m. The road/guard collider uses the same triangle vertices. Support scenery still uses batched instances. True bridge gaps are not filled.

19 road-specific checks pass: every quad's two top triangles preserve orientation; tangent angle stays below25 degrees; drivable width retained; raycasts at left/centre/right on every cross-section include lap seam for all three tracks; masked gap has solid approaches and no internal collision; gap deck end cap catches horizontal ray. Added a gap crossing lap start fixture, observed18/19 failure, fixed mask to use circular arc distance, then19/19 passed.

Independent review numerically reproduced the three routes and found no centerline or individual shoulder-edge self-intersections. Actual rendered critical Shanghai/Zhejiang/Zhuhai bends inspected, including the reported Shanghai turn. No fan-like overlap or open road joins visible.

Full suite: previous108 checks +19 road checks =127. Native captures in tests/capture_corners.gd. Layout lengths now approximately3.96km /2.86km /3.12km after removing spline artefacts and smoothing. These are game layouts, not measured real-circuit lengths. Arbitrary future control points still require geometric and driving validation; the repair does not guarantee all possible JSON layouts are non-self-intersecting.
