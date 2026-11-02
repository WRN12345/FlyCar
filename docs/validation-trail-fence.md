# Roadside wooden fences

- Main road receives left/right wooden posts and two rails at 0.48/1.0 m, sampled approximately every 3 m. Fence center offset is 2.95 m from the road center, beyond the 2.35 m trail and 0.3 m soft edge.
- Consecutive panels share edge vertices. Heights use the actual terrain; rails slope between their endpoints. Mesh scaling is applied in local axes so rotated rails meet the posts without skew or gaps.
- Each panel has a full-height physical shape; the vehicle cannot squeeze through the gap between the visible rails. Post feet embed slightly in the ground.
- Fence contact uses friction 0.3 and zero bounce, allowing a glancing car to slide along the rail while the normal collision still prevents crossing.
- Existing shortcut corridor checks are shared with boundary enforcement. Opening panels omit both rendered geometry and collision shapes. Flight corridors retain their open space.
- Rendering uses one box mesh and 64 m MultiMesh chunks. Collision bodies use the same chunk ownership, and all fence nodes belong to the active course.
- 2,171 main-road panels in the current valley map. Fence tests validate both sides, road clearance, terrain height, shortcut openings, rail orientation, collision rays and a real rigid-body side impact. Full-lap and shortcut tests verify integration with existing racing behavior.
- The test driver uses a 1.1 m obstacle bypass offset to keep the vehicle inside the physically fenced road on steep cross-slopes, and reverses briefly if pinned at low speed. This assistance is limited to tests.
