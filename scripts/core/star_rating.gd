class_name StarRating
extends RefCounted
## Par time and 1–3 stars (v0.2 §3, D-45).
##
## Par is derived from the certified level: a fixed reading time, a per-arrow
## budget and a per-level-of-dependency budget (the longest chain of arrows
## that must leave before another can). Rounded up to whole seconds.
##   3 stars: time <= par and no hints
##   2 stars: time <= 2 x par (hints allowed)
##   1 star : completed
## The par is generous enough that replaying the certified solution at a
## realistic human pace (HUMAN_TAP_MS per arrow plus a READ_MS first look)
## always earns 3 stars; tests/content checks this for every shipped level.

const BASE_MS := 5000
const PER_ARROW_MS := 1400
const PER_DEPTH_MS := 1200
const HUMAN_TAP_MS := 1000     # realistic tap-to-tap pace when the order is known
const READ_MS := 3000          # first look at the board


static func par_ms(arrow_count: int, depth: int) -> int:
	var raw := BASE_MS + PER_ARROW_MS * maxi(0, arrow_count) + PER_DEPTH_MS * maxi(0, depth)
	return int(ceil(raw / 1000.0)) * 1000


static func par_for_level(level: Dictionary) -> int:
	var board := LevelData.to_board(level)
	return par_ms(board.total_count(), PuzzleSolver.dependency_depth(board))


## Time a realistic player needs to replay the certified solution.
static func human_replay_ms(arrow_count: int) -> int:
	return READ_MS + HUMAN_TAP_MS * maxi(0, arrow_count)


static func stars(time_ms: int, par: int, hints_used: int) -> int:
	if par <= 0:
		return 1
	if time_ms <= par and hints_used <= 0:
		return 3
	if time_ms <= 2 * par:
		return 2
	return 1
