# Surface impact correction and antialiasing — 2026-10-30

Replaces the former 8m-below-road explosion with visible-environment response. Terrain rectangles now drive visible geometry, land collisions and queries. Shanghai uses land plus a water region, Zhejiang land, Zhuhai water plus a land coast. These are original game scenery choices, not surveyed real circuit terrain.

Water contact retains the frozen, visible vehicle, splashes and generates ripples; the car sinks 3.6m over 2.4s and is occluded by the water surface. Land impact replaces the car with recognizable hood, roof, doors, four wheels and small shards, with gravity and ground bounce. Distinct procedural impact sounds replace the blast. No fireball or arbitrary midair destruction remains in production.

Car recovery, record isolation, pause and map/restart cleanup retained. Independent review identified that a fixed origin-height threshold could miss sideways or nose-first land contacts. Two gravity regressions failed before implementing an orientation-aware lowest point from the actual chassis collision box. Both then passed.

Native render snapshots inspected: water sinking, land wreck, all three tracks, map menu, MSAA off vs4x. Project and actual Viewport report 4x MSAA; Compatibility FXAA/TAA are not claimed. White lines widened from 0.12/0.13 to0.18m; metallic roughness increased from0.28 to0.38 to reduce specular shimmer.

Verification: prior90 regression checks plus18 surface checks =108. New cases cover no airborne destruction, real gravity contact, sideways/nose-first impacts, no hidden land collision under water, sinking progress, no duplicate recovery, pause, fuel preservation and actual viewport MSAA.

Limits: stylized fragments and water shader, no full soft-body deformation, fluid simulation or exact real-world terrain. Desktop performance and full-lap tuning still need continued playtesting.
