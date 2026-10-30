# Repeat jets and forest valley validation

User reported a one-flight-only experience and selected a denser forest valley environment.

## Jet reuse

- Reproduced the empty-held-Space recharge lockout and slow recovery between short jumps before correction.
- Empty tank latches a release requirement, but no longer prevents charging on supported ground while Space stays held. Release then press rearms actual thrust; no automatic sputtering.
- Normal-weighted suspension support >=35% body weight, >=2 tire contacts and upright dot >0.65 qualify for charging. Wall-grazing, airborne and inverted cases cannot refill.
- Ground charge rate 0.5 tank/s after 0.35s nozzle cooldown. Recovery pose retains its existing 0.8s delay and does not refill the tank. Manual thrust stays finite (1.2s equivalent full tank), with manual descent jets.
- Fourteen checks include three repeat launches, actual partial tank exhaustion -> landing -> full recharge -> new lift, plus a real two-ray vertical-wall grazing fixture. Old fuel/pause/impact recovery regressions remain covered.

## Forest valley

- 4311 trees, mixed branched prototypes with actual leaf cutouts and procedural bark, about 890 tree spatial batches (64m), collidable trunks, dense understory/reeds, mossy cliff formations and creek-bank detail.
- Main trail, marked grass shortcut and canyon launch/landing corridor have collision clearance. The grass shortcut test now follows the actual painted exit waypoint before CP3, rather than cutting through unmarked forest to an extrapolated goal.
- Continuous mountain backdrop replaces old cone mountains on off-road only. Switching to elevated maps restores their lights, fog and mountains.
- Eight forest checks cover density, batching, corridor clearance, cliff/bank/backdrop existence and clockwise face/normal consistency for rocks, trees/leaves and the mountain ridge.
- Native visual QA corrected inverted normals/shadow artifacts and overly strong water ripples. Current original assets remain stylized rather than photographic scans.
- Native OpenGL 1280x800 forest view on AMD Radeon 780M observed 55-60 FPS, 1729 draw calls and 2008 render objects. This is a static driving-view sample, not a universal FPS guarantee.

Original code-generated models/materials; no external asset licensing or download dependency. Native captures: tests/capture_offroad.gd. Test suite: tests/run.ps1. Final aggregate results are recorded in the implementation plan.
