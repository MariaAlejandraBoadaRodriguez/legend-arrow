class_name DeterministicRng
extends RefCounted
## Small xorshift32 generator. Implemented here (instead of Godot's RNG) so
## generated content stays bit-identical across engine versions and platforms.

const MASK := 0xFFFFFFFF

var _state: int


func _init(seed_value: int = 1) -> void:
	_state = (seed_value ^ 0x9E3779B9) & MASK
	if _state == 0:
		_state = 0x6D2B79F5
	for i in 8:  # decorrelate nearby seeds
		next_u32()


func next_u32() -> int:
	var x := _state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	_state = x & MASK
	return _state


## Uniform-ish integer in [lo, hi] (inclusive).
func range_int(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + next_u32() % (hi - lo + 1)


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := range_int(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
