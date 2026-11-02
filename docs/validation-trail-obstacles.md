# Mandatory flight obstacles

- 16 deterministic flight sites: 6 three-boulder barriers, 5 full-road fallen trunks and 5 five-rock piles (43 rocks and 5 trees).
- Real convex colliders fill the legal road width. Car-width ground shape sweeps verify there is no side bypass; fences and fatal boundary enforcement prevent off-road bypasses.
- Tree roots remain 6.8 m off the road. Main trunks are about 9.8 m long and 0.92-1.16 m in diameter, falling nearly perpendicular to the road. Extended forked leafy crowns attach beyond the enlarged trunk; root coordinates remain unchanged.
- Sites are selected near the original spacing, with at least 70 m separation, bank <=7%, grade <=16% and nearly straight approach/landing directions. Checkpoint neighborhoods, ford and canyon runway are excluded.
- Each site is physically tested twice using real car forces: ground throttle must fail, manual Space takeoff/attitude input must cross and land. No teleport, direct force or special invulnerability is used during a trial. Current result: 32/32 checks across all 16 sites.
- Full-route regression driver uses jet and attitude inputs instead of a ground bypass. This assistance exists only in the test; playable controls remain manual.
- Boundary failure is terminal and does not automatically restore the car. Wrecks include a substantial chassis and larger shards; airborne wreck debris falls to the local terrain instead of an invisible elevated floor.
