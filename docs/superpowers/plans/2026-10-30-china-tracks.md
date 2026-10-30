# China Tracks Implementation Plan

Goal: three switchable Chinese circuit-inspired elevated tracks and one-shot falling explosion/recovery.
Architecture: JSON track definitions -> validated catalog and resampled centerline -> shared track builder. Main owns race/menu/death state; isolated effect owns debris and fireball. Keep original course as an explicit regression fixture.
Tech Stack: Godot 4.7 / GDScript / JSON, original procedural meshes.
Spec: docs/superpowers/specs/2026-10-30-china-tracks-design.md (approved in chat).

## Global constraints
Shanghai, Zhejiang, Zhuhai; adapted elevated layouts, not surveyed replicas. M pauses and opens map selection. Per-map records. Drop 8m below local road -> one explosion -> 1.6s -> checkpoint recovery +3s, no free fuel. Pause/restart/switch cancel or suspend state safely.

## Review focus
Switch during explosion; menu opened from pause; invalid track file; duplicate recovery; nearest road height; honest geometry labels and no old collision leftovers.

## Tasks
- [x] 1. Add failing catalog tests for three distinct closed paths, finite valid data, real gap and valid spawn/gates. Implement scripts/track_catalog.gd and tracks/*.json. Add data-only extension guide.
- [x] 2. Add shared scripts/course.gd to build roads, gates and obstacles from sampled track data. Move old course into scripts/legacy_course.gd fixture. Make minimap fit arbitrary bounds. Verify loading each course and physical road/gap raycasts.
- [x] 3. Add scripts/track_menu.gd and integrate selection, paused cancel, switch, per-map bests, spawn and HUD with main.gd. Preserve car physics. Test clean switch, independent records, restart, pause and inputs.
- [x] 4. Add failing explosion lifecycle checks, implement scripts/explosion.gd and controlled death/recovery. Verify no duplicate penalty, fuel preserved, pause, restart and switch safe.
- [x] 5. Run all regression and new integration tests, render map selector and three courses plus explosion, independent review, update README and push to authorized GitHub repository.

Execution: inline as the continuation of the approved implementation. Work directly in requested folder (user's active Godot project); preserve pre-existing project.godot formatting-only reorder. No worktree relocation. Record verification in docs/validation-china.md.
