# Road boundary and 1.5x jet endurance

- Off-road racing is limited to the sampled main road (2.35 m half width plus the existing 0.3 m visual soft edge) and designated shortcut corridors. Boundary checks use the vehicle's horizontal reference position at any altitude.
- Grass shortcut, canyon runway, flight corridor and exit connectors remain legal; other forest/shoulder driving and airborne corner cutting trigger an immediate terminal land wreck.
- Boundary wrecks stop the timer, freeze/hide the car and retain the wreck after its animation. R and checkpoint crossings are blocked; only explicit restart/map switch clears failure. Existing non-boundary sinking/terrain-impact handling and city barriers remain available.
- Full-power fuel budget increases from 1.2 to 1.8 seconds. Per-nozzle force and recharge rate are unchanged; both consumption helpers use the same constant. Partial duty still consumes proportional fuel.
- Route boundary test covers main road, legal airspace, illegal ground/airspace, both shortcuts and runway, terminal wreck, frozen timer, fuel preservation, persistent failure, disabled recovery and explicit restart. Endurance tests verify the old 1.2-second burn leaves one third and the new tank runs out at 1.8 seconds.
- Terrain-impact tests explicitly disable race boundaries to keep independently testing sinking/crash behavior outside the legal course. Full race and shortcut driver tests keep boundary enforcement enabled and reject any recovery.
