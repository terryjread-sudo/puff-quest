class_name LevelData
extends RefCounted

const VERSION := 1
const MUSIC_BPM := 120.0
const MUSIC_OFFSET := 0.0

static func default_level() -> Dictionary:
	var objects: Array = []
	var triggers: Array = []
	var id := 0
	for beat in range(4, 184):
		if beat % 7 == 0 or beat % 11 == 0:
			objects.append(_object("spike", beat, 0, {}, id)); id += 1
		if beat % 13 == 0:
			objects.append(_object("block", beat + 0.5, 0, {"height": 1.0}, id)); id += 1
		if beat % 17 == 0:
			objects.append(_object("laser_gate", beat + 0.25, 0, {"period": 4.0, "on_beats": 2.0}, id)); id += 1
		if beat % 5 == 0:
			objects.append(_object("star", beat + 0.4, 1 if beat % 10 == 0 else 0.6, {}, id)); id += 1
	for beat in [31.0, 67.0, 105.0]:
		objects.append(_object("checkpoint", beat, 0, {}, id)); id += 1
	for beat in [22.0, 48.0, 76.0]:
		triggers.append({"id": "quiz-%03d" % beat, "type": "quiz", "beat": beat, "table": 2, "time_limit": 10.0})
	objects.append(_object("catapult", 14.0, 0, {"delay_beats": 1.0, "launch_beats": 2.0}, id)); id += 1
	objects.append(_object("bounce_pad", 39.0, 0, {"strength": 1.0}, id)); id += 1
	objects.append(_object("moving_platform", 58.0, 1, {"travel_beats": 4.0, "distance_lanes": 2.0}, id)); id += 1
	objects.append(_object("gravity_portal", 88.0, 0, {"duration_beats": 8.0}, id)); id += 1
	objects.append(_object("speed_ring", 118.0, 1, {"multiplier": 1.25, "duration_beats": 4.0}, id)); id += 1
	return {"version": VERSION, "music": {"track": "circuit-punk-game-menu.mp3", "bpm": MUSIC_BPM, "beat_offset_seconds": MUSIC_OFFSET}, "length_beats": 184, "objects": objects, "triggers": triggers}

static func _object(kind: String, beat: float, lane: float, properties: Dictionary, number: int) -> Dictionary:
	return {"id": "%s-%03d" % [kind, number], "type": kind, "beat": beat, "lane": lane, "properties": properties}

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return default_level()
	var source: Dictionary = raw
	var result := default_level()
	result["version"] = int(source.get("version", VERSION))
	result["length_beats"] = clamp(float(source.get("length_beats", 184.0)), 32.0, 1024.0)
	var music: Dictionary = source.get("music", {}) if source.get("music", {}) is Dictionary else {}
	result["music"] = {"track": "circuit-punk-game-menu.mp3", "bpm": clamp(float(music.get("bpm", MUSIC_BPM)), 40.0, 240.0), "beat_offset_seconds": float(music.get("beat_offset_seconds", MUSIC_OFFSET))}
	result["objects"] = _clean_objects(source.get("objects", []))
	result["triggers"] = _clean_triggers(source.get("triggers", []))
	return result

static func _clean_objects(raw: Variant) -> Array:
	var cleaned: Array = []
	if not raw is Array: return cleaned
	var allowed := ["block", "spike", "catapult", "bounce_pad", "moving_platform", "gravity_portal", "laser_gate", "speed_ring", "star", "checkpoint"]
	for item in raw:
		if not item is Dictionary or not allowed.has(str(item.get("type", ""))): continue
		var properties: Dictionary = item.get("properties", {}) if item.get("properties", {}) is Dictionary else {}
		cleaned.append({"id": str(item.get("id", "object-%03d" % cleaned.size())), "type": str(item.get("type")), "beat": clamp(float(item.get("beat", 0.0)), 0.0, 1024.0), "lane": clamp(float(item.get("lane", 0.0)), -2.0, 4.0), "properties": properties})
	return cleaned

static func _clean_triggers(raw: Variant) -> Array:
	var cleaned: Array = []
	if not raw is Array: return cleaned
	for item in raw:
		if not item is Dictionary or str(item.get("type", "quiz")) != "quiz": continue
		cleaned.append({"id": str(item.get("id", "quiz-%03d" % cleaned.size())), "type": "quiz", "beat": clamp(float(item.get("beat", 0.0)), 0.0, 1024.0), "table": clamp(int(item.get("table", 2)), 2, 12), "time_limit": clamp(float(item.get("time_limit", 3.2)), 1.0, 10.0)})
	return cleaned
