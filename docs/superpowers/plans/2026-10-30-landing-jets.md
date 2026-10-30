# Landing jets implementation plan

> Implement inline using executing-plans; test physics first and request a fresh final review.

**Goal:** Extend the approved short-burst driving model with fuel-limited attitude jets, automatic road touchdown braking, white exhaust, surface mist and generated jet audio.

**Architecture:** A pure thruster controller returns four normalized nozzle duties. Car owns ray queries and applies actual off-center forces; a separate pooled effect component reads actual duties and surface hits. Existing suspension and full manual burst remain.

**Constraints:** Godot 4.7.2 Compatibility; no external assets/dependencies; game tuning is not Tesla hardware data. Preserve land fragmentation/water sinking. User has authorized implementation in the existing project and GitHub synchronization.

**Implementation decisions:** Space retains manual thrust; arrows now spend gas through differential nozzle forces. Landing assist only detects marked track collision, upright car, downward motion and an upward-facing surface with at least three probes; no assist over sea/terrain/gap or upside down. Limited gas/force cannot guarantee a safe landing. Reset/freeze/pause must stop jet/audio output.

- [x] Add failing controller tests: descent braking, ascent/inversion/terrain rejection, force bounds, differential torque and proportional fuel exhaustion.
- [x] Implement scripts/thruster_control.gd; integrate probes, duty/fuel/forces and road metadata; add real paired drop/empty tank/attitude/lifecycle checks.
- [x] Add scripts/jet_effect.gd for four directional white plumes, bounded world-space surface mist and generated looping audio. Update HUD guidance.
- [x] Run complete suite, inspect native airborne/touchdown captures, independent review, document and synchronize repository.

Validation: Godot 4.7.2 import + 14 regression scripts, 156/156 checks passed. Native captures confirmed white mist after correcting the Compatibility particle material. Fresh review found two effect issues, both fixed and covered by regression. Headless audio teardown warnings were removed by explicitly stopping/freeing test scenes and allowing an audio frame before exit.
