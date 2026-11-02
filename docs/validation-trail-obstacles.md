# Forest trail obstacles

Requested: rocks and fallen trees on the road, with physical collisions and useful driving choices.

- Added a course-owned `TrailObstacles` node after route/checkpoint construction.
- 23 deterministic sites, alternating blocked sides: 8 boulders, 8 fallen trunks, 7 four-rock gardens (44 main bodies).
- Reuses the forest rock/bark materials. Trunks have exposed end grain, broken branches and convex collision matching their meshes; branches have separate convex shapes.
- Fallen trees now include tapering trunk extensions, 15 forked crown limbs, 480 alpha-cut leaf sprays, 14 forked exposed roots and an uprooted soil plate with irregular clods. Trunk/major branches/root plates collide; leaf cards and fine root hairs do not form collision walls.
- Root placement is anchored 6.8 m laterally from each route site. The tree falls diagonally inward and along the route; local growth always runs from the root toward the crown, regardless of which roadside it grew on. Root plates are tested to remain more than 4 m from the actual sampled trail, and crown tips must be closer to the road than their roots. The opposite lane remains open.
- Placement samples terrain at trunk endpoints. Start/finish approaches, checkpoint recovery neighborhoods, deep/shallow river and canyon launch/landing region are excluded.
- A 2 m wide bypass is checked with real physics shape queries. Every main body is ray-tested against the active physics world.
- Timing triggers, manual jets, environment-dependent crash handling and mouse orbit remain active. No world signs are added.
- The full-route regression driver now slows near hazards and follows a smooth bypass; this assistance exists only in the test, not the playable car.

Verification: `tests/test_trail_obstacles.gd` checks site distribution, both obstacle families, checkpoint clearance, collider activation and car-width bypass. Existing full physical lap, shortcuts and vehicle/controller regression scripts are run before publishing. `tests/capture_trail_obstacles.gd` creates native game screenshots for all three obstacle types.
