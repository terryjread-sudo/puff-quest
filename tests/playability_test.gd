extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	for level_index in range(LevelData.LEVEL_COUNT):
		for difficulty in range(3):
			var report: Dictionary = LevelData.difficulty_playability_report(level_index, difficulty)
			if not bool(report["pass"]):
				_fail("Level %d difficulty %d playability report failed: %s" % [level_index + 1, difficulty, JSON.stringify(report)])
			var campaign: Dictionary = LevelData.campaign_level(level_index, difficulty)
			if int(campaign["difficulty"]) != difficulty:
				_fail("Campaign level did not retain its selected difficulty")
	var level_3_report: Dictionary = LevelData.playability_report(2)
	if level_3_report["boss_attack_beats"].size() != 5:
		_fail("Level 3 should expose five zombie attack windows")
	for runway in level_3_report["runways"]:
		if not bool(runway["pass"]):
			_fail("Level 3 runway is not playable: %s" % JSON.stringify(runway))
	var normal_objects: Array = LevelData.campaign_level(0, 1)["objects"]
	var easy_objects: Array = LevelData.campaign_level(0, 0)["objects"]
	var hard_objects: Array = LevelData.campaign_level(0, 2)["objects"]
	if easy_objects.size() >= normal_objects.size() or hard_objects.size() <= normal_objects.size():
		_fail("Easy and Hard should provide visibly different obstacle layouts")
	var easy_settings: Dictionary = LevelData.difficulty_settings(0)
	var normal_settings: Dictionary = LevelData.difficulty_settings(1)
	var hard_settings: Dictionary = LevelData.difficulty_settings(2)
	if easy_settings["shields"] != 4 or normal_settings["shields"] != 3 or hard_settings["shields"] != 2:
		_fail("Difficulty shield counts are incorrect")
	if easy_settings["good_window"] <= normal_settings["good_window"] or hard_settings["good_window"] >= normal_settings["good_window"]:
		_fail("Difficulty timing windows do not scale as intended")
	if LevelData.boss_attack_interval(2, 0) <= LevelData.boss_attack_interval(2, 1) or LevelData.boss_attack_interval(2, 2) >= LevelData.boss_attack_interval(2, 1):
		_fail("Boss attack intervals do not scale with difficulty")
	var easy_unlocks: Array = LevelData.normalize_difficulty_unlocks([1, 2, 99])
	if easy_unlocks != [1, 2, 2]:
		_fail("Difficulty unlock values were not normalized safely")
	var migrated_scores: Array = LevelData.migrate_best_scores([101, 202, 303], [])
	if migrated_scores[1] != 101 or migrated_scores[4] != 202 or migrated_scores[7] != 303:
		_fail("Legacy scores were not migrated to Normal")
	var stored_scores: Array = LevelData.migrate_best_scores([], [1, 2, 3, 4, 5, 6, 7, 8, 9])
	if stored_scores[0] != 1 or stored_scores[8] != 9:
		_fail("Tier-specific scores were not restored")

	var game_scene: PackedScene = load("res://main.tscn") as PackedScene
	var game: Node = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	game._apply_level(LevelData.campaign_level(2))
	game.difficulty_unlocked = [0, 0, 0]
	game.level_index = 0
	game.difficulty_index = 0
	game.score = 111
	game._finish()
	if game.difficulty_unlocked[0] != 1 or game.best_scores[0] != 111:
		_fail("Completing Easy should unlock Normal and record an Easy score")
	game.difficulty_index = 1
	game.score = 222
	game._finish()
	if game.difficulty_unlocked[0] != 2 or game.best_scores[1] != 222:
		_fail("Completing Normal should unlock Hard and record a separate score")
	game._apply_level(LevelData.campaign_level(2))

	# Main floor is grounded and must be vulnerable.
	game.player = Vector2(150.0, 539.0)
	game.dash_left = 0.0
	if game._zombie_player_is_safe():
		_fail("A floor-grounded player was incorrectly marked safe")

	# Raised platforms are also grounded under the selected rule.
	var runway_platform: Dictionary = {}
	for object in game.objects:
		if object["type"] == "platform" and bool(object["properties"].get("boss_runway", false)):
			runway_platform = object
			break
	if runway_platform.is_empty():
		_fail("Level 3 has no boss runway platform")
	var platform_rect: Rect2 = game._object_rect(runway_platform)
	game.player = Vector2(platform_rect.position.x + 8.0, platform_rect.position.y - 46.0)
	game.dash_left = 0.0
	if game._zombie_player_is_safe():
		_fail("A platform-grounded player was incorrectly marked safe")

	# Airborne players are safe, including players who are currently dashing.
	game.player.y -= 30.0
	game.dash_left = 0.2
	if not game._zombie_player_is_safe():
		_fail("An airborne player was incorrectly marked vulnerable")

	game.queue_free()
	print("Campaign playability and Level 3 shockwave checks passed.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
