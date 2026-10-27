extends GutTest


func test_same_seed_same_sequence() -> void:
	var a := DeterministicRng.new(42)
	var b := DeterministicRng.new(42)
	for i in 100:
		assert_eq(a.next_u32(), b.next_u32())


func test_known_values_are_stable_across_versions() -> void:
	# Golden values: generated content depends on them. Changing the RNG
	# changes every generated level, so this must fail loudly.
	var r := DeterministicRng.new(1)
	var got: Array = []
	for i in 3:
		got.append(r.next_u32())
	assert_eq(got, GOLDEN_SEED_1)


func test_different_seeds_diverge() -> void:
	assert_ne(DeterministicRng.new(1).next_u32(), DeterministicRng.new(2).next_u32())


func test_range_is_inclusive_and_bounded() -> void:
	var r := DeterministicRng.new(7)
	var seen := {}
	for i in 2000:
		var v := r.range_int(3, 6)
		assert_between(v, 3, 6)
		seen[v] = true
	assert_eq(seen.size(), 4, "every value in range is produced")
	assert_eq(r.range_int(5, 5), 5)


func test_shuffle_is_a_permutation() -> void:
	var arr := range(20)
	DeterministicRng.new(3).shuffle(arr)
	var sorted := arr.duplicate()
	sorted.sort()
	assert_eq(sorted, range(20))
	assert_ne(arr, range(20))


const GOLDEN_SEED_1 := [3745685276, 411726028, 2229840677]  # from an independent Python xorshift32
