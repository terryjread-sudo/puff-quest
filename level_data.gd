class_name LevelData
extends RefCounted

const VERSION: int = 2
const LEVEL_COUNT: int = 3
const DEFAULT_TRACK: String = "cyberpunk-menu-music.mp3"
const MUSIC_TRACKS: Array = ["cyberpunk-menu-music.mp3", "murder-on-the-metrorail.ogg", "boss-fight.ogg"]

static func level_catalog() -> Array:
	return [
		{"name": "BONE CARNIVAL", "subtitle": "Kawaii skeleton chase", "track": "cyberpunk-menu-music.mp3", "bpm": 120.0, "theme": "skeleton", "length_beats": 184.0, "chase_beat": 92.0},
		{"name": "METRORAIL MAYHEM", "subtitle": "Ghost train pursuit", "track": "murder-on-the-metrorail.ogg", "bpm": 116.0, "theme": "metro", "length_beats": 196.0, "chase_beat": 0.0},
		{"name": "SLIME ESCAPE", "subtitle": "Platforms, splats and a wobbly pursuit", "track": "boss-fight.ogg", "bpm": 128.0, "theme": "slime", "length_beats": 210.0, "chase_beat": 0.0}
	]

static func default_level() -> Dictionary:
	return campaign_level(0)

static func campaign_level(index: int) -> Dictionary:
	var safe_index: int = clampi(index, 0, LEVEL_COUNT - 1)
	var catalog: Array = level_catalog()
	var meta: Dictionary = catalog[safe_index]
	var objects: Array = []
	var triggers: Array = []
	var number: int = 0
	var length_beats: float = float(meta["length_beats"])
	if safe_index == 0:
		for beat in range(4, 184):
			if beat % 7 == 0 or beat % 11 == 0:
				objects.append(_object("spike", beat, 0.0, {}, number)); number += 1
			if beat % 13 == 0:
				objects.append(_object("block", beat + 0.5, 0.0, {"height": 1.0}, number)); number += 1
			if beat % 5 == 0:
				objects.append(_object("star", beat + 0.4, 1.0 if beat % 10 == 0 else 0.6, {}, number)); number += 1
		for beat in [31.0, 67.0, 105.0, 151.0]:
			objects.append(_object("checkpoint", beat, 0.0, {}, number)); number += 1
		for beat in [22.0, 48.0, 76.0, 126.0, 164.0]:
			triggers.append(_quiz("quiz-%03d" % int(beat), beat, 2))
		objects.append(_object("catapult", 14.0, 0.0, {"delay_beats": 1.0, "launch_beats": 2.0}, number)); number += 1
		objects.append(_object("bounce_pad", 39.0, 0.0, {"strength": 1.0}, number)); number += 1
		objects.append(_object("moving_platform", 58.0, 1.0, {"travel_beats": 4.0, "distance_lanes": 2.0}, number)); number += 1
		objects.append(_object("gravity_portal", 88.0, 0.0, {"duration_beats": 8.0}, number)); number += 1
		objects.append(_object("speed_ring", 118.0, 1.0, {"multiplier": 1.25, "duration_beats": 4.0}, number)); number += 1
	elif safe_index == 1:
		for beat in range(4, 196):
			if beat % 6 == 0 or beat % 17 == 0:
				objects.append(_object("spike", beat, 0.0, {}, number)); number += 1
			if beat % 10 == 0:
				objects.append(_object("block", beat + 0.5, 0.0, {"height": 1.0 + float(int(beat / 10.0) % 2) * 0.35}, number)); number += 1
			if beat % 8 == 0:
				objects.append(_object("star", beat + 0.25, 0.8 + float(beat % 3) * 0.35, {}, number)); number += 1
		for beat in [32.0, 72.0, 120.0, 162.0]:
			objects.append(_object("checkpoint", beat, 0.0, {}, number)); number += 1
		for beat in [24.0, 56.0, 90.0, 130.0, 166.0]:
			triggers.append(_quiz("quiz-%03d" % int(beat), beat, 3))
		objects.append(_object("moving_platform", 18.0, 1.0, {"travel_beats": 3.0, "distance_lanes": 2.0}, number)); number += 1
		objects.append(_object("catapult", 44.0, 0.0, {"delay_beats": 1.0, "launch_beats": 2.0}, number)); number += 1
		objects.append(_object("speed_ring", 82.0, 1.0, {"multiplier": 1.3, "duration_beats": 5.0}, number)); number += 1
		objects.append(_object("gravity_portal", 108.0, 0.0, {"duration_beats": 7.0}, number)); number += 1
		objects.append(_object("bounce_pad", 145.0, 0.0, {"strength": 1.1}, number)); number += 1
	else:
		for beat in range(4, 210):
			if beat % 5 == 0 or beat % 9 == 0:
				objects.append(_object("spike", beat, 0.0, {}, number)); number += 1
			if beat % 12 == 0:
				objects.append(_object("block", beat + 0.5, 0.0, {"height": 1.25}, number)); number += 1
			if beat % 7 == 0:
				objects.append(_object("star", beat + 0.3, 0.7 + float(beat % 4) * 0.3, {}, number)); number += 1
		for beat in [30.0, 70.0, 116.0, 164.0]:
			objects.append(_object("checkpoint", beat, 0.0, {}, number)); number += 1
		for beat in [20.0, 50.0, 84.0, 124.0, 174.0]:
			triggers.append(_quiz("quiz-%03d" % int(beat), beat, 4))
		objects.append(_object("catapult", 16.0, 0.0, {"delay_beats": 0.75, "launch_beats": 2.0}, number)); number += 1
		objects.append(_object("moving_platform", 42.0, 1.0, {"travel_beats": 3.0, "distance_lanes": 2.5}, number)); number += 1
		objects.append(_object("gravity_portal", 76.0, 0.0, {"duration_beats": 9.0}, number)); number += 1
		objects.append(_object("speed_ring", 100.0, 1.0, {"multiplier": 1.35, "duration_beats": 6.0}, number)); number += 1
		objects.append(_object("bounce_pad", 142.0, 0.0, {"strength": 1.15}, number)); number += 1
		objects.append(_object("moving_platform", 178.0, 1.0, {"travel_beats": 2.5, "distance_lanes": 2.0}, number)); number += 1
		for platform_beat in [22.0, 38.0, 54.0, 71.0, 90.0, 108.0, 126.0, 146.0, 166.0, 188.0]:
			objects.append(_object("platform", platform_beat, 1.0 if int(platform_beat) % 2 == 0 else 1.5, {"width": 2.0, "height": 0.25}, number)); number += 1
	return {"version": VERSION, "level_index": safe_index, "display_name": meta["name"], "subtitle": meta["subtitle"], "theme": meta["theme"], "chase_beat": meta["chase_beat"], "music": {"track": meta["track"], "bpm": meta["bpm"], "beat_offset_seconds": 0.0}, "length_beats": length_beats, "objects": objects, "triggers": triggers}

static func _object(kind: String, beat: float, lane: float, properties: Dictionary, number: int) -> Dictionary:
	return {"id": "%s-%03d" % [kind, number], "type": kind, "beat": beat, "lane": lane, "properties": properties}

static func _quiz(id: String, beat: float, table: int) -> Dictionary:
	return {"id": id, "type": "quiz", "beat": beat, "table": table, "time_limit": 10.0}

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return default_level()
	var source: Dictionary = raw
	var safe_index: int = clampi(int(source.get("level_index", 0)), 0, LEVEL_COUNT - 1)
	var result: Dictionary = campaign_level(safe_index)
	result["version"] = int(source.get("version", VERSION))
	result["display_name"] = str(source.get("display_name", result["display_name"]))
	result["subtitle"] = str(source.get("subtitle", result["subtitle"]))
	result["theme"] = str(source.get("theme", result["theme"]))
	result["chase_beat"] = float(source.get("chase_beat", result["chase_beat"]))
	result["length_beats"] = clampf(float(source.get("length_beats", result["length_beats"])), 32.0, 1024.0)
	var catalog: Array = level_catalog()
	var default_meta: Dictionary = catalog[safe_index]
	var music: Dictionary = source.get("music", {}) if source.get("music", {}) is Dictionary else {}
	var requested_track: String = str(music.get("track", default_meta["track"]))
	var selected_track: String = requested_track if MUSIC_TRACKS.has(requested_track) else str(default_meta["track"])
	result["music"] = {"track": selected_track, "bpm": clampf(float(music.get("bpm", default_meta["bpm"])), 40.0, 240.0), "beat_offset_seconds": float(music.get("beat_offset_seconds", 0.0))}
	result["objects"] = _clean_objects(source.get("objects", []))
	result["triggers"] = _clean_triggers(source.get("triggers", []))
	return result

static func _clean_objects(raw: Variant) -> Array:
	var cleaned: Array = []
	if not raw is Array:
		return cleaned
	var allowed: Array = ["block", "spike", "catapult", "bounce_pad", "platform", "moving_platform", "gravity_portal", "speed_ring", "star", "checkpoint"]
	for item in raw:
		if not item is Dictionary or not allowed.has(str(item.get("type", ""))):
			continue
		var properties: Dictionary = item.get("properties", {}) if item.get("properties", {}) is Dictionary else {}
		cleaned.append({"id": str(item.get("id", "object-%03d" % cleaned.size())), "type": str(item.get("type")), "beat": clampf(float(item.get("beat", 0.0)), 0.0, 1024.0), "lane": clampf(float(item.get("lane", 0.0)), -2.0, 4.0), "properties": properties})
	return cleaned

static func _clean_triggers(raw: Variant) -> Array:
	var cleaned: Array = []
	if not raw is Array:
		return cleaned
	for item in raw:
		if not item is Dictionary or str(item.get("type", "quiz")) != "quiz":
			continue
		cleaned.append({"id": str(item.get("id", "quiz-%03d" % cleaned.size())), "type": "quiz", "beat": clampf(float(item.get("beat", 0.0)), 0.0, 1024.0), "table": clampi(int(item.get("table", 2)), 2, 12), "time_limit": clampf(float(item.get("time_limit", 10.0)), 1.0, 10.0)})
	return cleaned
