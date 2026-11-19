extends GutTest
## Par times and exact star thresholds (v0.2 §3, D-45).


func test_par_grows_with_arrows_and_depth_and_is_whole_seconds() -> void:
	assert_eq(StarRating.par_ms(0, 0), 5000)
	assert_eq(StarRating.par_ms(8, 3), 20000, "5 + 11.2 + 3.6 = 19.8 s -> 20 s")
	assert_gt(StarRating.par_ms(9, 3), StarRating.par_ms(8, 3))
	assert_gt(StarRating.par_ms(8, 4), StarRating.par_ms(8, 3))
	for n in range(0, 80, 7):
		for d in range(0, 20, 3):
			assert_eq(StarRating.par_ms(n, d) % 1000, 0)


func test_thresholds_are_exact_at_the_boundaries() -> void:
	var par := 30000
	assert_eq(StarRating.stars(par, par, 0), 3, "exactly par, no hints")
	assert_eq(StarRating.stars(par + 1, par, 0), 2, "1 ms over par")
	assert_eq(StarRating.stars(0, par, 0), 3)
	assert_eq(StarRating.stars(2 * par, par, 0), 2, "exactly 2x par")
	assert_eq(StarRating.stars(2 * par + 1, par, 0), 1, "1 ms over 2x par")
	assert_eq(StarRating.stars(par, par, 1), 2, "fast with a hint")
	assert_eq(StarRating.stars(2 * par, par, 5), 2, "hints allowed for 2 stars")
	assert_eq(StarRating.stars(2 * par + 1, par, 1), 1)
	assert_eq(StarRating.stars(10, 0, 0), 1, "no par: completion only")


func test_replaying_the_solution_at_human_pace_earns_three_stars() -> void:
	for n in range(1, 80):
		for d in [1, maxi(1, n / 4), n]:
			var human := StarRating.human_replay_ms(n)
			assert_eq(StarRating.stars(human, StarRating.par_ms(n, d), 0), 3, "n=%d d=%d" % [n, d])
