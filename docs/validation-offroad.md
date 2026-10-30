# Valley off-road validation

Approved original multi-terrain time trial; Godot 4.7.2 Compatibility / Jolt 120 Hz.

- 3.32km closed route, eight ordered gates, distinct valley record ID. Off-road defaults in the selection menu; three Chinese track indices remain stable.
- Dirt, gravel, mud, grass, water and rock have per-wheel grip and rolling resistance. Dirt/mud/water color and terrain match driving feedback; four pooled tire emitters provide dust and shallow water spray.
- Single 4m height grid defines render and concave collider triangles, exact barycentric queries and surface normals. Cached per-grid vertex colors/normals reduce build cost.
- River crossing has ~0.24m depth. Off-route pool exceeds 1m and uses sinking. Ordinary ground driving/hops survive; 12m/s normal point speed triggers debris. Jolt contact velocities include rotation; body-first, sideways and inverted hard drops are covered.
- Grass shortcut reaches CP3. Canyon shortcut reaches CP6 with ~19.4m/s approach in the test fixture, 0.85s takeoff plus ~0.25s manual descent jet input. No automatic stabilization, no unlimited fuel. A broad safe main bypass remains.
- Main-route controller uses only throttle/brake/steering input, no teleport during the lap, and triggers all eight gates. Latest elapsed 274.05s without recovery.
- Full suite: 198/198 checks across 19 scripts, exit 0. Original elevated-track physical obstacles, surface impacts, records and pause/reset remain green.
- Native screenshots inspected: menu, dirt, gravel, mud, grass, river, canyon and overview. Fixed high-frequency checker pattern and vertex-color brightness from first render.
- Fresh independent review completed; substantive findings corrected and rechecked.

Reproduce with tests/run.ps1 -Godot <Godot-console.exe>. The long lap/shortcut tests use --fixed-fps 120 to advance the same 120Hz physical simulation faster; they do not appear as game autopilot.

Visuals remain procedural and simplified. No AI opponents, weather or upgrade system. Keep gas for descent; landing technique and lap times remain dependent on the player. The older elevated-track off-road fall rule is intentionally retained only on those maps.
