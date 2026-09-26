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
	if easy_settings["quiz_time"] != 15.0 or normal_settings["quiz_time"] != 12.0 or hard_settings["quiz_time"] != 10.0:
		_fail("Quiz time limits do not scale with difficulty")
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
	var game_canvas: Node2D = game as Node2D
	var shop_button: Rect2 = game._shop_button_rect()
	var shop_button_viewport_point: Vector2 = game_canvas.get_canvas_transform() * (shop_button.position + shop_button.size * 0.5)
	if not game._shop_button_hit(shop_button_viewport_point):
		_fail("Shop button did not hit-test at its drawn position")
	var reveal_button: Rect2 = game._quiz_reveal_rect()
	var reveal_viewport_point: Vector2 = game_canvas.get_canvas_transform() * (reveal_button.position + reveal_button.size * 0.5)
	if not game._quiz_reveal_hit(reveal_viewport_point):
		_fail("Quiz multiplier button did not hit-test at its drawn position")
	game.quiz_number = 12
	var twelve_parts: Dictionary = game._quiz_place_value_parts()
	if twelve_parts["tens"] != 1 or twelve_parts["ones"] != 2:
		_fail("Place-value hint did not split 12 into one ten and two ones")
	game.quiz_number = 7
	var seven_parts: Dictionary = game._quiz_place_value_parts()
	if seven_parts["tens"] != 0 or seven_parts["ones"] != 7:
		_fail("Place-value hint did not split a one-digit number correctly")
	game.quiz_table = 2
	game.quiz_number = 3
	game.quiz_dots_revealed = false
	if game._quiz_dot_count() != 2:
		_fail("Before reveal, the helper should show the times-table number of dots")
	game.quiz_dots_revealed = true
	if game._quiz_dot_count() != 6:
		_fail("Revealing 2 × 3 should show six dots")
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
