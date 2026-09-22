extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	for level_index in range(LevelData.LEVEL_COUNT):
		var report: Dictionary = LevelData.playability_report(level_index)
		if not bool(report["pass"]):
			_fail("Level %d playability report failed: %s" % [level_index + 1, JSON.stringify(report)])
	var level_3_report: Dictionary = LevelData.playability_report(2)
	if level_3_report["boss_attack_beats"].size() != 5:
		_fail("Level 3 should expose five zombie attack windows")
	for runway in level_3_report["runways"]:
		if not bool(runway["pass"]):
			_fail("Level 3 runway is not playable: %s" % JSON.stringify(runway))

	var game_scene: PackedScene = load("res://main.tscn") as PackedScene
	var game: Node = game_scene.instantiate()
	root.add_child(game)
	await process_frame
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
