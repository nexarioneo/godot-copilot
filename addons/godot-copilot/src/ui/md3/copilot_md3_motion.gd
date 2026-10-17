@tool
class_name CopilotMd3Motion
extends RefCounted
# Motion helpers for the Material 3 component library: token lookup, cubic
# bezier sampling, and Tween playback helpers.
# Durations, easings, and springs are defined in CopilotMd3Tokens.

static var _curve_cache: Dictionary = {}

static func duration_seconds(name: String) -> float:
	return float(CopilotMd3Tokens.DURATION_MS.get(name, 200)) / 1000.0

static func spring_duration_seconds(name: String) -> float:
	var entry: Dictionary = _spring_entry(name)
	return float(entry.get("duration", 500)) / 1000.0

static func easing_points(name: String) -> PackedFloat32Array:
	var raw: Variant = CopilotMd3Tokens.EASING.get(name, null)
	if not (raw is Array):
		raw = CopilotMd3Tokens.EASING["standard"]
	return PackedFloat32Array(raw)

static func spring_points(name: String) -> PackedFloat32Array:
	var entry: Dictionary = _spring_entry(name)
	var raw: Variant = entry.get("bezier", null)
	if not (raw is Array):
		raw = [0.2, 0.0, 0.0, 1.0]
	return PackedFloat32Array(raw)

static func bezier(points_array: PackedFloat32Array, x: float) -> float:
	if points_array.size() < 4:
		return x
	var t := _solve_parameter(points_array[0], points_array[2], clampf(x, 0.0, 1.0))
	return _axis_value(points_array[1], points_array[3], t)

static func curve(easing_name: String) -> Curve:
	var key := "easing:" + easing_name
	if not _curve_cache.has(key):
		_curve_cache[key] = _build_curve(easing_points(easing_name))
	return _curve_cache[key] as Curve

static func spring_curve(spring_name: String) -> Curve:
	var key := "spring:" + spring_name
	if not _curve_cache.has(key):
		_curve_cache[key] = _build_curve(spring_points(spring_name))
	return _curve_cache[key] as Curve

static func animate_eased(tween: Tween, setter: Callable, from_value: float, to_value: float, seconds: float, easing_name: String) -> void:
	_tween_value(tween, setter, from_value, to_value, seconds, curve(easing_name))

static func animate_spring(tween: Tween, setter: Callable, from_value: float, to_value: float, seconds: float, spring_name: String) -> void:
	_tween_value(tween, setter, from_value, to_value, seconds, spring_curve(spring_name))

static func _tween_value(tween: Tween, setter: Callable, from_value: float, to_value: float, seconds: float, sampled: Curve) -> void:
	var apply := func(weight: float) -> void:
		setter.call(lerpf(from_value, to_value, sampled.sample(weight)))
	tween.tween_method(apply, 0.0, 1.0, seconds).set_trans(Tween.TRANS_LINEAR)

static func _spring_entry(name: String) -> Dictionary:
	if CopilotMd3Tokens.SPRING.has(name):
		return CopilotMd3Tokens.SPRING[name]
	return CopilotMd3Tokens.SPRING["default-spatial"]

static func _solve_parameter(x1: float, x2: float, x: float) -> float:
	var low := 0.0
	var high := 1.0
	var t := x
	for _i in range(16):
		t = (low + high) * 0.5
		if _axis_value(x1, x2, t) < x:
			low = t
		else:
			high = t
	return t

static func _axis_value(c1: float, c2: float, t: float) -> float:
	var mt := 1.0 - t
	return 3.0 * mt * mt * t * c1 + 3.0 * mt * t * t * c2 + t * t * t

static func _build_curve(points_array: PackedFloat32Array) -> Curve:
	var sample_count := 32
	var values := PackedFloat32Array()
	values.resize(sample_count + 1)
	var max_value := 1.0
	for i in range(sample_count + 1):
		var x := float(i) / float(sample_count)
		var y := bezier(points_array, x)
		values[i] = y
		if y > max_value:
			max_value = y
	var built := Curve.new()
	built.min_value = 0.0
	built.max_value = max_value
	for i in range(sample_count + 1):
		built.add_point(Vector2(float(i) / float(sample_count), values[i]))
	return built
