# Forest trail obstacles

Requested: rocks and fallen trees on the road, with physical collisions and useful driving choices.

- Added a course-owned `TrailObstacles` node after route/checkpoint construction.
- 23 deterministic sites, alternating blocked sides: 8 boulders, 8 fallen trunks, 7 four-rock gardens (44 main bodies).
- Reuses the forest rock/bark materials. Trunks have exposed end grain, broken branches and convex collision matching their meshes; branches have separate convex shapes.
- Placement samples terrain at trunk endpoints. Start/finish approaches, checkpoint recovery neighborhoods, deep/shallow river and canyon launch/landing region are excluded.
- A 2 m wide bypass is checked with real physics shape queries. Every main body is ray-tested against the active physics world.
- Timing triggers, manual jets, environment-dependent crash handling and mouse orbit remain active. No world signs are added.
- The full-route regression driver now slows near hazards and follows a smooth bypass; this assistance exists only in the test, not the playable car.

Verification: `tests/test_trail_obstacles.gd` checks site distribution, both obstacle families, checkpoint clearance, collider activation and car-width bypass. Existing full physical lap, shortcuts and vehicle/controller regression scripts are run before publishing. `tests/capture_trail_obstacles.gd` creates native game screenshots for all three obstacle types.
