class_name LevelData
extends RefCounted

const VERSION: int = 2
const LEVEL_COUNT: int = 3
const DEFAULT_TRACK: String = "cyberpunk-menu-music.mp3"
const MUSIC_TRACKS: Array = ["cyberpunk-menu-music.mp3", "murder-on-the-metrorail.ogg", "boss-fight.ogg"]
const FLOOR_HAZARD_CLUSTER_WINDOW_BEATS: float = 1.75
const MAX_FLOOR_HAZARDS_IN_JUMP_WINDOW: int = 3
const BOSS_CORRIDOR_AFTER_BEATS: float = 0.50
const DIFFICULTIES: Array = ["Easy", "Normal", "Hard"]

static func level_catalog() -> Array:
	return [
		{"name": "BONE CARNIVAL", "subtitle": "Kawaii skeleton chase", "track": "cyberpunk-menu-music.mp3", "bpm": 120.0, "theme": "skeleton", "length_beats": 184.0, "chase_beat": 92.0},
		{"name": "METRORAIL MAYHEM", "subtitle": "Ghost train pursuit", "track": "murder-on-the-metrorail.ogg", "bpm": 116.0, "theme": "metro", "length_beats": 196.0, "chase_beat": 0.0},
		{"name": "ZOMBIE VILLAGE RUN", "subtitle": "A relentless villager pursuit", "track": "boss-fight.ogg", "bpm": 128.0, "theme": "zombie", "length_beats": 210.0, "chase_beat": 0.0}
	]

static func default_level() -> Dictionary:
	return campaign_level(0)

static func difficulty_settings(difficulty: int) -> Dictionary:
	var safe_difficulty: int = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	var shields: Array = [4, 3, 2]
	var perfect_windows: Array = [0.15, 0.10, 0.08]
	var good_windows: Array = [0.30, 0.24, 0.18]
	return {"name": DIFFICULTIES[safe_difficulty], "shields": shields[safe_difficulty], "perfect_window": perfect_windows[safe_difficulty], "good_window": good_windows[safe_difficulty]}

static func migrate_best_scores(legacy_scores: Variant, tier_scores: Variant) -> Array:
	var result: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	if tier_scores is Array and tier_scores.size() >= 9:
		for i in range(9): result[i] = maxi(0, int(tier_scores[i]))
	elif legacy_scores is Array:
		for i in range(mini(LEVEL_COUNT, legacy_scores.size())): result[i * 3 + 1] = maxi(0, int(legacy_scores[i]))
	return result

static func normalize_difficulty_unlocks(raw: Variant) -> Array:
	var result: Array = [0, 0, 0]
	if raw is Array:
		for i in range(mini(LEVEL_COUNT, raw.size())): result[i] = clampi(int(raw[i]), 0, 2)
	return result

static func campaign_level(index: int, difficulty: int = 1) -> Dictionary:
	var safe_index: int = clampi(index, 0, LEVEL_COUNT - 1)
	var safe_difficulty: int = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
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
		# Hand-authored split route: the low route is dangerous, while the raised
		# route offers a safer line with extra stars for confident players.
		number = _add_pattern(objects, number, [
			["platform", 60.0, 1.15, {"width": 2.7, "height": 0.25}],
			["star", 60.5, 1.85, {}],
			["spike", 61.5, 0.0, {}],
			["platform", 63.0, 1.35, {"width": 2.7, "height": 0.25}],
			["star", 63.5, 2.05, {}],
			["spike", 64.5, 0.0, {}],
			["platform", 66.0, 1.05, {"width": 2.7, "height": 0.25}],
			["star", 66.5, 1.65, {}]
		])
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
		# Metro fork: players can stay low and dash through the rail hazards or
		# climb the marked platform route for collectibles.
		number = _add_pattern(objects, number, [
			["platform", 94.0, 1.0, {"width": 2.5, "height": 0.25}],
			["star", 94.5, 1.7, {}],
			["spike", 95.5, 0.0, {}],
			["platform", 97.0, 1.4, {"width": 2.5, "height": 0.25}],
			["star", 97.5, 2.1, {}],
			["spike", 98.5, 0.0, {}],
			["platform", 100.0, 1.0, {"width": 2.5, "height": 0.25}],
			["star", 100.5, 1.7, {}]
		])
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
		# Early practice platforms, followed by a deliberately spaced safe route
		# just before each zombie strike (113, 133, 153, 173 and 193).
		for platform_beat in [22.0, 38.0, 54.0, 71.0, 90.0, 111.0, 131.0, 151.0, 172.0, 191.0]:
			var platform_lane: float = 1.0 if int(platform_beat) % 2 == 0 else 1.5
			var platform_width: float = 2.8 if platform_beat >= 111.0 else 2.0
			var platform_properties: Dictionary = {"width": platform_width, "height": 0.25}
			if platform_beat >= 111.0: platform_properties["boss_runway"] = true
			objects.append(_object("platform", platform_beat, platform_lane, platform_properties, number)); number += 1
		# A final village fork gives players a choice between a risky diamond line
		# and the safer ground route before the alternating boss attacks.
		number = _add_pattern(objects, number, [
			["platform", 102.0, 1.15, {"width": 2.8, "height": 0.25}],
			["star", 102.5, 1.85, {}],
			["spike", 103.5, 0.0, {}],
			["platform", 106.0, 1.45, {"width": 2.8, "height": 0.25}],
			["star", 106.5, 2.15, {}],
			["spike", 107.5, 0.0, {}],
			["platform", 110.0, 1.15, {"width": 2.8, "height": 0.25}],
			["star", 110.5, 1.85, {}]
		])
	_apply_difficulty_layout(objects, safe_difficulty, safe_index, length_beats)
	_repair_generated_playability(objects, safe_index, length_beats, safe_difficulty)
	return {"version": VERSION, "level_index": safe_index, "difficulty": safe_difficulty, "display_name": meta["name"], "subtitle": meta["subtitle"], "theme": meta["theme"], "chase_beat": meta["chase_beat"], "music": {"track": meta["track"], "bpm": meta["bpm"], "beat_offset_seconds": 0.0}, "length_beats": length_beats, "objects": objects, "triggers": triggers}

static func _apply_difficulty_layout(objects: Array, difficulty: int, level_index: int, length_beats: float) -> void:
	if difficulty == 1: return
	if difficulty == 0:
		var hazard_number := 0
		for i in range(objects.size() - 1, -1, -1):
			if _is_hazard(objects[i]):
				hazard_number += 1
				if hazard_number % 5 == 0: objects.remove_at(i)
		return
	var number := 9500
	for beat in range(14, int(length_beats) - 4, 23):
		var offset := float((beat + level_index * 3) % 5) * 0.25
		objects.append(_object("spike", float(beat) + offset, 0.0, {}, number))
		number += 1

static func _add_pattern(objects: Array, number: int, pattern: Array) -> int:
	for entry in pattern:
		if entry.size() < 3: continue
		var properties: Dictionary = entry[3] if entry.size() > 3 and entry[3] is Dictionary else {}
		objects.append(_object(str(entry[0]), float(entry[1]), float(entry[2]), properties, number))
		number += 1
	return number

static func _object(kind: String, beat: float, lane: float, properties: Dictionary, number: int) -> Dictionary:
	return {"id": "%s-%03d" % [kind, number], "type": kind, "beat": beat, "lane": lane, "properties": properties}

static func _quiz(id: String, beat: float, table: int) -> Dictionary:
	return {"id": id, "type": "quiz", "beat": beat, "table": table, "time_limit": 10.0}

static func boss_attack_interval(index: int, difficulty: int = 1) -> float:
	var safe_difficulty: int = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	if index == 0: return [10.0, 8.0, 6.0][safe_difficulty]
	if index == 1: return [22.0, 18.0, 15.0][safe_difficulty]
	return [24.0, 20.0, 16.0][safe_difficulty]

static func boss_attack_windows(index: int, difficulty: int = 1) -> Array:
	var safe_index: int = clampi(index, 0, LEVEL_COUNT - 1)
	var catalog: Array = level_catalog()
	var length_beats: float = float(catalog[safe_index]["length_beats"])
	var windows: Array = []
	match safe_index:
		0:
			var skeleton_beat: float = 92.0 + boss_attack_interval(safe_index, difficulty)
			while skeleton_beat < length_beats:
				windows.append({"beat": skeleton_beat, "kind": "skeleton_slam", "runway_beats": 1.50})
				skeleton_beat += boss_attack_interval(safe_index, difficulty)
		1:
			var ghost_beat: float = length_beats * 0.5 + 8.0
			var ghost_final_beat: float = length_beats - 30.0
			while ghost_beat < ghost_final_beat:
				windows.append({"beat": ghost_beat, "kind": "ghost_wave", "runway_beats": 1.50})
				ghost_beat += boss_attack_interval(safe_index, difficulty)
			windows.append({"beat": ghost_final_beat, "kind": "ghost_wave", "runway_beats": 1.50})
		2:
			var zombie_beat: float = length_beats * 0.5 + 8.0
			var zombie_final_beat: float = length_beats - 17.0
			while zombie_beat < zombie_final_beat:
				windows.append({"beat": zombie_beat, "kind": "zombie_shockwave", "runway_beats": 2.50})
				zombie_beat += boss_attack_interval(safe_index, difficulty)
			windows.append({"beat": zombie_final_beat, "kind": "zombie_shockwave", "runway_beats": 2.50})
	return windows

static func playability_report(index: int, raw_objects: Variant = null) -> Dictionary:
	var safe_index: int = clampi(index, 0, LEVEL_COUNT - 1)
	var source_objects: Array = []
	if raw_objects is Array:
		source_objects = _clean_objects(raw_objects)
	else:
		source_objects = campaign_level(safe_index)["objects"]
	return _build_playability_report(safe_index, source_objects, 1)

static func difficulty_playability_report(index: int, difficulty: int) -> Dictionary:
	var safe_index: int = clampi(index, 0, LEVEL_COUNT - 1)
	var safe_difficulty: int = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	return _build_playability_report(safe_index, campaign_level(safe_index, safe_difficulty)["objects"], safe_difficulty)

static func _build_playability_report(index: int, source_objects: Array, difficulty: int = 1) -> Dictionary:
	var sorted_hazards: Array = []
	for object in source_objects:
		if _is_hazard(object): sorted_hazards.append(object)
	sorted_hazards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["beat"]) < float(b["beat"]))
	var hazard_conflicts: Array = []
	for i in range(sorted_hazards.size()):
		var current: Dictionary = sorted_hazards[i]
		if not _is_floor_hazard(current): continue
		var cluster_count := 1
		var last_cluster_hazard: Dictionary = current
		for j in range(i + 1, sorted_hazards.size()):
			var next_hazard: Dictionary = sorted_hazards[j]
			if float(next_hazard["beat"]) - float(current["beat"]) > FLOOR_HAZARD_CLUSTER_WINDOW_BEATS: break
			if _is_floor_hazard(next_hazard):
				cluster_count += 1
				last_cluster_hazard = next_hazard
		if cluster_count > MAX_FLOOR_HAZARDS_IN_JUMP_WINDOW:
			hazard_conflicts.append({"type": "dense_floor_hazards", "hazard_id": last_cluster_hazard["id"], "beat": last_cluster_hazard["beat"], "count": cluster_count})
	var runways: Array = []
	for window in boss_attack_windows(index, difficulty):
		var attack_beat: float = float(window["beat"])
		var runway_start: float = attack_beat - float(window["runway_beats"])
		var runway_end: float = attack_beat - 0.75
		var platform_available := false
		for object in source_objects:
			if (object["type"] == "platform" or object["type"] == "moving_platform") and float(object["beat"]) >= runway_start and float(object["beat"]) <= runway_end:
				platform_available = true
				break
		var floor_launch_clear := true
		for object in sorted_hazards:
			var object_beat: float = float(object["beat"])
			if object_beat >= runway_start and object_beat <= runway_end and _is_blocking_jump_hazard(object):
				floor_launch_clear = false
				break
		var blocking_hazards: Array = []
		for object in sorted_hazards:
			var object_beat: float = float(object["beat"])
			if object_beat >= attack_beat - 1.0 and object_beat <= attack_beat + BOSS_CORRIDOR_AFTER_BEATS and _is_blocking_jump_hazard(object):
				blocking_hazards.append(object["id"])
		var runway_passes: bool = platform_available or floor_launch_clear
		if not runway_passes:
			hazard_conflicts.append({"type": "missing_boss_runway", "beat": attack_beat})
		if not blocking_hazards.is_empty():
			hazard_conflicts.append({"type": "boss_jump_corridor_blocked", "beat": attack_beat, "hazard_ids": blocking_hazards})
		runways.append({"beat": attack_beat, "platform_available": platform_available, "floor_launch_clear": floor_launch_clear, "blocking_hazards": blocking_hazards, "pass": runway_passes and blocking_hazards.is_empty()})
	return {"level_index": index, "difficulty": difficulty, "boss_attack_beats": boss_attack_windows(index, difficulty).map(func(window: Dictionary) -> float: return float(window["beat"])), "runways": runways, "hazard_conflicts": hazard_conflicts, "pass": hazard_conflicts.is_empty()}

static func _is_hazard(object: Dictionary) -> bool:
	return object["type"] == "spike" or object["type"] == "block" or object["type"] == "saw"

static func _is_floor_hazard(object: Dictionary) -> bool:
	return _is_hazard(object) and float(object["lane"]) <= 0.05

static func _is_blocking_jump_hazard(object: Dictionary) -> bool:
	if not _is_hazard(object): return false
	if object["type"] == "spike": return float(object["lane"]) > 0.05
	return true

static func _repair_generated_playability(objects: Array, index: int, length_beats: float, difficulty: int = 1) -> void:
	var repair_count := 0
	while repair_count < 32:
		var report: Dictionary = _build_playability_report(index, objects, difficulty)
		if bool(report["pass"]): return
		var repaired := false
		for conflict in report["hazard_conflicts"]:
			if conflict["type"] == "missing_boss_runway":
				var runway_beat: float = float(conflict["beat"]) - 1.0
				objects.append(_object("platform", runway_beat, 1.0, {"width": 2.8, "height": 0.25, "boss_runway": true, "generated_safety_fallback": true}, 9000 + repair_count))
				repaired = true
				break
			var hazard_id: String = str(conflict.get("hazard_id", ""))
			if hazard_id.is_empty() and conflict.get("hazard_ids", []).size() > 0:
				hazard_id = str(conflict["hazard_ids"][0])
			for object in objects:
				if str(object["id"]) != hazard_id: continue
				var repaired_beat: float = _find_safe_hazard_beat(objects, object, length_beats, index, difficulty)
				if repaired_beat >= 0.0:
					object["beat"] = repaired_beat
					repaired = true
				break
			if repaired: break
		if not repaired: return
		repair_count += 1

static func _find_safe_hazard_beat(objects: Array, hazard: Dictionary, length_beats: float, index: int, difficulty: int = 1) -> float:
	var original_beat: float = float(hazard["beat"])
	for step in range(1, 25):
		for direction in [1.0, -1.0]:
			var candidate: float = snappedf(original_beat + direction * float(step) * 0.25, 0.25)
			if candidate < 2.0 or candidate > length_beats - 1.0: continue
			var candidate_is_safe := true
			for other in objects:
				if other == hazard or not _is_hazard(other): continue
				if _is_floor_hazard(hazard) and _is_floor_hazard(other) and absf(float(other["beat"]) - candidate) <= FLOOR_HAZARD_CLUSTER_WINDOW_BEATS:
					var cluster_count := 1
					for cluster_other in objects:
						if cluster_other == hazard or not _is_floor_hazard(cluster_other): continue
						if absf(float(cluster_other["beat"]) - candidate) <= FLOOR_HAZARD_CLUSTER_WINDOW_BEATS: cluster_count += 1
					if cluster_count > MAX_FLOOR_HAZARDS_IN_JUMP_WINDOW:
						candidate_is_safe = false
						break
			if not candidate_is_safe: continue
			if _is_blocking_jump_hazard(hazard):
				var inside_boss_corridor := false
				for window in boss_attack_windows(index, difficulty):
					var attack_beat: float = float(window["beat"])
					if candidate >= attack_beat - 1.0 and candidate <= attack_beat + BOSS_CORRIDOR_AFTER_BEATS:
						inside_boss_corridor = true
						break
				if inside_boss_corridor: continue
			return candidate
	return -1.0

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return default_level()
	var source: Dictionary = raw
	var safe_index: int = clampi(int(source.get("level_index", 0)), 0, LEVEL_COUNT - 1)
	var result: Dictionary = campaign_level(safe_index)
	result["difficulty"] = clampi(int(source.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)
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
	var allowed: Array = ["block", "spike", "saw", "catapult", "bounce_pad", "platform", "moving_platform", "gravity_portal", "speed_ring", "star", "checkpoint"]
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
