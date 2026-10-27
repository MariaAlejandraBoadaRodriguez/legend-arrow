# Save format (schema_version 2)

File `user://save.json` (+ `.tmp`, `.bak`, `.corrupt`). Envelope: `{"format":"legend_arrow_save","sha256":<hex of payload>,"payload":<JSON text>}`.

Payload keys: `schema_version`, `levels{id:{completed}}`, `creatures{id:{unlocked,awakening_seen}}`, `transactions{"complete:<level>"|"unlock:<creature>":true}`, `in_progress{level_id,removed[],completed}`, `hints{free_used{level:n},ad_entitlements}`, `ad_receipts{presentation_id:true}`, `tutorial_done`, `settings{music_volume,sfx_volume,creature_volume,reduce_motion,haptics,language}`.

Not stored: advertising identifiers, consent details, names, ages, tap streams.

Write: tmp written fully → valid main rotated to `.bak` → tmp renamed to main. Load order: main → tmp → bak; a corrupt main is renamed `.corrupt` (never deleted) and a restored backup shows "Progress restored". Interrupted rename (main missing, tmp complete) loads silently.
Migration: `SaveSchema.migrate()`; v1 is a test-only legacy fixture. Every move/unlock saves immediately and on app pause.
Android backup: disabled (`user_data_backup/allow=false`); no cross-device sync or uninstall recovery is claimed.
