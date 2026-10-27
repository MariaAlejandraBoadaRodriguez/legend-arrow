# Requirements → tests matrix

Maps every testing requirement of the brief (§4) to the tests that execute it.
Levels, so nothing is mislabelled:

- **U** unit (pure model, GUT)
- **C** content/property (packaged data, generated boards, GUT)
- **I** in-engine integration: real screens mounted in a test tree, touch events sent to the board's `_gui_input` (GUT; `tests/helpers/app_driver.gd`)
- **D** desktop E2E: the real game process (`scripts/desktop_e2e.sh`), every tap an `InputEventScreenTouch` through `Input.parse_input_event` at window pixels, process **killed** (`kill -9`) between `_a`/`_b` halves; phone 720×1280 and tablet 1200×1920
- **A** Android E2E: the same journeys inside the **debug APK on an emulator** (`scripts/android_e2e.sh`, CI job `android-emulator-e2e`), launched with `am start`, killed with `am force-stop`, evidence = logcat + in-app PNGs + system `screencap`

Not used: Android instrumentation/UiAutomator. Godot draws the whole UI into one GL surface, so UiAutomator cannot see Godot controls; the A level drives the real app from inside instead (debug builds only, D-37).

Status and run links: see `docs/PROGRESS.md` (a row is PASS only with an executed run).

## Unit
| Requirement | Tests | Level |
|---|---|---|
| Exits in all four directions | `test_puzzle_board`: `test_exit_right_on_empty_row`, `test_exit_left`, `test_exit_up`, `test_exit_down` | U |
| Swept-body collision incl. clear head + blocked body | `test_puzzle_board`: `test_clear_head_but_blocked_body`, `test_body_ray_blocked_by_cell_outside_heads_column`, `test_far_blocker_at_board_edge_still_blocks`, `test_bent_arrow_exits_in_final_segment_direction`, `test_blocked_in_each_direction` | U |
| Blocked moves leave state unchanged | `test_puzzle_board.test_blocked_move_leaves_state_unchanged`, `test_puzzle_session.test_blocked_tap_changes_nothing_and_names_blocker` | U |
| Undo and restart | `test_puzzle_session`: `test_undo_restores_exactly_previous_arrow`, `test_undo_after_blocked_tap_only_undoes_real_moves`, `test_restart_after_partial_progress`, `test_restart_after_completion_allows_replay`, `test_undo_after_hint` | U |
| Completion and two-puzzle unlock | `test_progression`: `test_first_puzzle_shows_one_of_two_without_unlocking`, `test_second_puzzle_unlocks_creature_once`, `test_replay_is_idempotent` | U |
| Save serialization, migration, corrupt-file recovery | `test_save_repository` (12 tests incl. `test_kill_at_every_step_never_yields_half_state`, `test_migrates_v1_save`, `test_corrupt_main_recovers_from_backup_and_quarantines`) | U |
| Idempotent completion and rewards | `test_progression.test_ad_hint_grant_is_idempotent_per_presentation`, `test_ad_service`: `test_duplicate_reward_callbacks_grant_once`, `test_late_reward_after_close_grants_once`, `test_receipt_survives_restart_so_redelivery_cannot_regrant` | U |
| Hint selection and ad frequency boundaries | `test_puzzle_session`: `test_hint_returns_removable_arrow_without_changing_state`, `test_hint_follows_any_order_and_is_empty_when_done`; `test_interstitial_policy` (10 tests) | U |

## Content and solver
| Requirement | Tests | Level |
|---|---|---|
| Validate all 24 packaged levels | `test_packaged_content`: `test_every_campaign_level_is_packaged_valid_and_owned`, `test_full_roster_is_twelve_creatures_and_twenty_four_levels`, `test_no_orphan_level_files` | C |
| Execute every recorded solution | `test_recorded_solutions_play_through_a_session`, `test_full_campaign_completes_and_unlocks_each_creature_once` | C |
| Reject invalid/overlapping/malformed paths | `test_level_validator` (15 tests) | U |
| 1,000 deterministic generated boards | `test_generated_boards`: `test_every_seed_generates_a_board`, `test_generated_levels_pass_validator_after_json_round_trip`, `test_recorded_solutions_succeed_and_solver_agrees`, `test_generation_is_deterministic` | C |
| Monotonicity, no deadlocks | `test_removal_is_monotone_and_random_play_never_deadlocks`, `test_exhaustive_search_on_small_boards_finds_no_deadlock`, `test_solver_matches_brute_force_on_random_boards`, `test_packaged_levels_have_no_reachable_deadlock` (≤14 arrows, exhaustive), `test_large_levels_never_deadlock_under_random_play` (>14 arrows, 40 seeds each) | C |

## Integration
| Requirement | Tests | Level |
|---|---|---|
| Puzzle → save → reload | `test_game_flow.test_journey_partial_puzzle_survives_termination`, `test_app_pause_saves_in_progress_state` | I |
| Completion → progression → awakening → bestiary | `test_journey_fresh_install_tutorial_to_first_creature`, `test_awakening_skip_replay_and_bestiary` | I |
| Ad earned, duplicate, dismissal, failure callbacks | `test_ads_flow` (7 tests), `test_ad_service` (22 tests) | I, U |
| Consent refusal, restricted audience, offline | `test_ads_flow.test_consent_refused_hides_ad_option`, `test_ad_service`: `test_consent_refused_blocks_ads_but_not_the_game`, `test_consent_error_or_offline_blocks_ads`, `test_unknown_audience_is_restricted`; `test_interstitial_policy.test_never_for_child_or_unknown_audience` | I, U |
| Background/resume and interrupted animations | `test_app_pause_saves_in_progress_state`, `test_kill_during_awakening_replays_without_duplicate_unlock`, `test_audio_director.test_mute_reasons_stack` | I, U |
| Sound preferences and reduced motion | `test_language_and_settings_persist_across_relaunch`, `test_board_input.test_reduced_motion_shortens_exit`, `test_reduced_motion_awakening_finishes_quickly`, `test_audio_director.test_players_use_the_settings_buses` | I, C, U |

## End-to-end journeys
| # | Journey | I (in-engine) | D + A (real app) |
|---|---|---|---|
| 1 | Fresh install → tutorial → first creature | `test_journey_fresh_install_tutorial_to_first_creature` | `fresh_install` |
| 2 | Partial puzzle → termination → relaunch → restored | `test_journey_partial_puzzle_survives_termination` | `partial_a` → kill → `partial_b` |
| 3 | Blocked → undo/restart → completion | `test_journey_blocked_then_undo_restart_then_complete` | `blocked_undo` |
| 4 | Rewarded hint success + ad-unavailable fallback | `test_rewarded_hint_success_journey`, `test_ad_unavailable_fallback_keeps_playing` | `hint_ad` (mock ads) |
| 5 | Awakening → skip/replay → bestiary | `test_awakening_skip_replay_and_bestiary` | `awakening_replay` |
| 6 | Language/settings → restart → persisted | `test_language_and_settings_persist_across_relaunch` | `settings_a` → kill → `settings_b` |
| — | Cold start without test hooks | — | `cold_start_smoke` (A only) |

## Coverage (brief targets)
Measured by `tools/coverage.py` (statement-line instrumentation of the GDScript sources, full GUT suite re-run; there is no maintained GDScript coverage tool). Counted lines: statement starts inside function bodies; not counted: declarations, `elif`/`else`, `match` patterns, bracket continuations. Report: CI artifact `test-reports/coverage/`.

| Group | Target | Files |
|---|---|---|
| Puzzle, solver, progression | 90% | `arrow_path`, `puzzle_board`, `puzzle_session`, `puzzle_solver`, `level_validator`, `level_generator`, `level_data`, `deterministic_rng`, `campaign`, `progression` |
| Save and reward handling | 80% | `save_repository`, `save_schema`, `ad_service`, `interstitial_policy`, `remote_config` |

## Outside automated tests
| Requirement | Status |
|---|---|
| Physical-device performance, memory, thermal | **BLOCKED**: no Android phone (D-18); `scripts/measure_device.sh` (M6) |
| Visual animation quality | Screenshots only; human review needed |
| Live ads / real consent form | **NOT RUN** by design in CI (test IDs + mock); manual check on an emulator with Google test IDs before release |
