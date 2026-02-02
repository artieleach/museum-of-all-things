class_name CollectionUtils
extends RefCounted

static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	var n := len(arr)
	for i in range(n - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var temp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

static func biased_shuffle(rng: RandomNumberGenerator, arr: Array, sd_to_start: float) -> void:
	var n := len(arr)
	for i in range(n - 1, 0, -1):
		var fi := float(i)
		# use gaussian distribution to bias towards current position
		var j := roundi(clamp(rng.randfn(fi + 1.0, fi / sd_to_start), 0.0, fi))
		var temp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
