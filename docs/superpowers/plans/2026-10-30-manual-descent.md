# Manual descent jet correction

User chose Space-controlled descent braking with arrow-controlled attitude, rather than automatic landing. Keep finite gas, off-center forces and white mist. Disable automatic landing by default; retain the optional exported assist for development. During airborne descent Space supplies body-up thrust without the takeoff forward bias and displays DESCENT BRAKE. Releasing Space restores ballistic descent unless attitude input is held. Update in-game hints and README.

- [x] Add failing physical checks for manual default, downward braking without forward boost, and release.
- [x] Correct default/direction/status and UI documentation.
- [x] Run physical/effect/track regression, review and synchronize.

Verification: 159/159 checks passed across all 14 scripts, including 11 real landing checks. Native capture confirmed white manual descent spray. Independent review found no substantive code issue; README and HUD were synchronized. Headless landing-test shutdown still reports two audio ObjectDB instances; no runtime/script errors occurred.
