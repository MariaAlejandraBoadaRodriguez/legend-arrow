# Save format (schema_version 3, v0.2)

File `user://save.json` (+ `.tmp`, `.bak`, `.corrupt`). Envelope: `{"format":"legend_arrow_save","sha256":<hex of payload>,"payload":<JSON text>}`.

Payload keys: `schema_version`, `levels{id:{completed,best_time_ms?,best_stars?}}` (v0.2 level id = dragon id), `creatures{id:{unlocked,awakening_seen}}`, `transactions{"complete:<level>"|"unlock:<creature>":true}`, `in_progress{level_id,removed[],completed,elapsed_ms,timer_started,hints_used}`, `hints{free_used{level:n},ad_entitlements}`, `ad_receipts{presentation_id:true}`, `tutorial_done`, `settings{music_volume,sfx_volume,creature_volume,reduce_motion,haptics}` (a `language` key written by v0.1 is dropped on load, D-41).

Not stored: advertising identifiers, consent details, names, ages, tap streams.

Write: tmp written fully → valid main rotated to `.bak` → tmp renamed to main. Load order: main → tmp → bak; a corrupt main is renamed `.corrupt` (never deleted) and a restored backup shows "Progress restored". Interrupted rename (main missing, tmp complete) loads silently.
Migration: `SaveSchema.migrate()`; v1 is a test-only legacy fixture; v2 (v0.1.x) → v3 by `migrate_v2_to_v3()` (D-46), tested on the real v0.1.1 save `tests/fixtures/save_v0_1_1.json`. `sanitize()` drops negative/non-numeric best times and clamps best stars to 1..3. Every move/unlock saves immediately and on app pause.
Android backup: disabled (`user_data_backup/allow=false`); no cross-device sync or uninstall recovery is claimed.
