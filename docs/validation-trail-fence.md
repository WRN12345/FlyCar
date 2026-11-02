# Roadside wooden fences

- Main road receives left/right wooden posts and two rails at 0.48/1.0 m, sampled approximately every 3 m. Fence center offset is 2.95 m from the road center, beyond the 2.35 m trail and 0.3 m soft edge.
- Consecutive panels share edge vertices. Heights use the actual terrain; rails slope between their endpoints. Mesh scaling is applied in local axes so rotated rails meet the posts without skew or gaps.
- Each visible rail and post has its own exact box collider (0.14 m rail thickness, 0.2 m post width). The former full-height panel collider is removed, so empty gaps no longer form an invisible wall. Rendering and collision share a single dimension/transform helper. Post feet embed slightly in the ground.
- Fence contact uses friction 0.3 and zero bounce, allowing a glancing car to slide along the rail while the normal collision still prevents crossing.
- Existing shortcut corridor checks are shared with boundary enforcement. Opening panels omit both rendered geometry and collision shapes. Flight corridors retain their open space.
- Rendering uses one box mesh and 64 m MultiMesh chunks. Collision bodies use the same chunk ownership, and all fence nodes belong to the active course.
- 2,171 main-road panels and 6,513 visible-piece colliders in the current valley map. Fence tests validate both sides, road clearance, terrain height, shortcut openings, rail orientation, an empty-gap ray, visible-piece/collider correspondence, rail collision rays and a real rigid-body side impact. Full-lap and shortcut tests verify integration with existing racing behavior.
- The test driver now uses manual jet and attitude inputs to cross full-width flight obstacles, and reverses briefly if pinned at low speed. This assistance is limited to tests.
