extends Node2D

const VIEW := Vector2(1280.0, 720.0)
const FLOOR_Y := 585.0
const PLAYER_SIZE := Vector2(46.0, 46.0)
const START_X := 150.0
const LANE_HEIGHT := 105.0
const RUN_SPEED := 360.0
const GRAVITY := 1900.0
const JUMP_VELOCITY := -720.0
const DASH_SPEED := 920.0
const DASH_TIME := 0.20
const PALETTE := ["block", "spike", "catapult", "timetable", "bounce_pad", "moving_platform", "gravity_portal", "speed_ring", "star", "checkpoint"]
const LEVEL_COUNT := 3
const BEAT_FLASH_STRENGTH := 0.055

var level: Dictionary = {}
var campaign_catalog: Array = []
var objects: Array = []
var runtime_objects: Array = []
var triggers: Array = []
var consumed: Dictionary = {}
var triggered: Dictionary = {}
var player := Vector2(START_X, FLOOR_Y - PLAYER_SIZE.y)
var velocity := Vector2.ZERO
var camera_x := 0.0
var started := false
var finished := false
var paused := false
var build_mode := false
var level_index := 0
var selected_level_index := 0
var unlocked_level := 0
var best_scores: Array = [0, 0, 0]
var dash_left := 0.0
var dash_cooldown := 0.0
var jump_buffer := 0.0
var coyote := 0.0
var run_time := 0.0
var background_time := 0.0
var quiz_active := false
var quiz_time := 0.0
var quiz_number := 0
var quiz_table := 2
var quiz_choices: Array[int] = []
var quiz_correct_index := 0
var quiz_points := 0
var quiz_streak := 0
var quiz_snapshot: Dictionary = {}
var quiz_input_lock := 0.0
var quiz_feedback_time := 0.0
var quiz_feedback_text := ""
var quiz_feedback_answer := 0
var quiz_feedback_reason := "WRONG TIMES TABLE"
var shield_hits := 3
var invulnerability := 0.0
var combo := 0
var best_combo := 0
var score := 0
var checkpoint_beats: Array = [0.0]
var checkpoint_index := 0
var particles: Array = []
var flash := 0.0
var message := ""
var message_time := 0.0
var selected_palette := 0
var rng := RandomNumberGenerator.new()
var music_player: AudioStreamPlayer
var skeleton_sprite: Texture2D
var music_started := false
var gravity_sign := 1.0
var gravity_until := 0.0
var catapult_state: Dictionary = {}
var catapult_boost_left := 0.0
var speed_until := 0.0
var crash_timer := 0.0
var checkpoint_flash := 0.0
var crash_reason := ""
var chase_started := false
var chase_flash := 0.0
var undo_stack: Array = []
var redo_stack: Array = []
var clipboard_object: Dictionary = {}
var selected_object_index := -1
var drag_object_index := -1
var pan_dragging := false
var pan_last_x := 0.0
var pan_moved := false
var pending_place_pos := Vector2.ZERO

func _ready() -> void:
	rng.seed = 20260918
	campaign_catalog = LevelData.level_catalog()
	_load_progress()
	_apply_level(LevelData.campaign_level(0))
	_setup_music()
	skeleton_sprite = load("res://assets/skeleton-run-spritesheet.png") as Texture2D
	queue_redraw()

func _apply_level(data: Dictionary) -> void:
	level = LevelData.validate(data)
	level_index = int(level.get("level_index", 0))
	objects = level["objects"]
	triggers = level["triggers"]
	runtime_objects.clear()
	consumed.clear(); triggered.clear(); catapult_state.clear()
	gravity_sign = 1.0; gravity_until = 0.0
	chase_started = false; chase_flash = 0.0
	checkpoint_beats = [0.0]
	for object in objects:
		if object["type"] == "checkpoint": checkpoint_beats.append(float(object["beat"]))
	checkpoint_beats.sort()
	if music_player != null: _load_level_music()

func _setup_music() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	_load_level_music()

func _load_level_music() -> void:
	var stream: AudioStream = load("res://assets/" + str(level["music"]["track"])) as AudioStream
	if stream == null: return
	if stream is AudioStreamMP3: (stream as AudioStreamMP3).loop = true
	if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
	music_player.stream = stream
	music_started = false
	music_player.stream_paused = false

func _ensure_music() -> void:
	if music_player == null or music_player.stream == null: return
	if not music_player.playing: music_player.play()
	music_player.stream_paused = false
	music_started = true

func _resume_music() -> void:
	if music_player == null or music_player.stream == null: return
	music_player.stream_paused = false
	if not music_player.playing: music_player.play()
	music_started = true

func _music_beat() -> float:
	return 60.0 / float(level["music"]["bpm"])

func _beat_width() -> float:
	return RUN_SPEED * _music_beat()

func _beat_distance() -> float:
	var beat: float = _music_beat()
	var clock: float = fmod(max(0.0, run_time + float(level["music"].get("beat_offset_seconds", 0.0))), beat)
	return min(clock, beat - clock)

func _beat_pulse() -> float:
	var beat: float = _music_beat()
	var clock: float = run_time if started else background_time
	var phase: float = fmod(max(0.0, clock + float(level["music"].get("beat_offset_seconds", 0.0))), beat) / beat
	return pow(max(0.0, cos(phase * TAU)), 12.0)

func _pace_multiplier() -> float:
	return 1.12 if _chase_active() else 1.0

func _process(delta: float) -> void:
	var dt: float = min(delta, 0.05)
	background_time += dt
	message_time = max(0.0, message_time - dt); flash = max(0.0, flash - dt)
	quiz_input_lock = max(0.0, quiz_input_lock - dt)
	invulnerability = max(0.0, invulnerability - dt)
	checkpoint_flash = max(0.0, checkpoint_flash - dt)
	chase_flash = max(0.0, chase_flash - dt)
	_update_particles(dt)
	if music_player != null: music_player.pitch_scale = 0.26 if quiz_active else _pace_multiplier()
	if quiz_feedback_time > 0.0:
		quiz_feedback_time -= dt
		if quiz_feedback_time <= 0.0: _resolve_quiz_feedback()
		queue_redraw(); return
	if crash_timer > 0.0:
		crash_timer -= dt
		if crash_timer <= 0.0: _respawn_at_checkpoint()
		queue_redraw(); return
	if not started or finished or paused or build_mode:
		queue_redraw(); return
	if quiz_active: _quiz_step(dt)
	else: _run_step(dt)
	queue_redraw()

func _run_step(delta: float) -> void:
	run_time += delta
	var grounded := _is_grounded()
	if grounded: coyote = 0.10
	else: coyote = max(0.0, coyote - delta)
	jump_buffer = max(0.0, jump_buffer - delta); dash_cooldown = max(0.0, dash_cooldown - delta)
	if gravity_until > 0.0 and run_time >= gravity_until: gravity_sign = 1.0; gravity_until = 0.0
	if dash_left > 0.0:
		dash_left -= delta; velocity = Vector2(DASH_SPEED, 0.0)
	else:
		catapult_boost_left = max(0.0, catapult_boost_left - delta)
		velocity.x = DASH_SPEED if catapult_boost_left > 0.0 else RUN_SPEED * _speed_multiplier() * _pace_multiplier(); velocity.y += GRAVITY * gravity_sign * delta
		if jump_buffer > 0.0 and (grounded or coyote > 0.0):
			velocity.y = JUMP_VELOCITY * gravity_sign; jump_buffer = 0.0; coyote = 0.0; _jump_beat_event()
	player += velocity * delta
	if gravity_sign > 0.0 and player.y + PLAYER_SIZE.y >= FLOOR_Y: player.y = FLOOR_Y - PLAYER_SIZE.y; velocity.y = 0.0
	if gravity_sign < 0.0 and player.y <= 90.0: player.y = 90.0; velocity.y = 0.0
	for platform in objects:
		if platform["type"] != "moving_platform": continue
		var platform_rect := _object_rect(platform)
		if velocity.y >= 0.0 and Rect2(player, PLAYER_SIZE).intersects(platform_rect) and player.y + PLAYER_SIZE.y - platform_rect.position.y < 24.0:
			player.y = platform_rect.position.y - PLAYER_SIZE.y
			velocity.y = 0.0
	if player.y > VIEW.y + 160.0 or player.y < -180.0:
		_crash("MISSED THE PLATFORM")
		return
	if _chase_active() and not chase_started: _start_chase()
	_update_objects(); _check_objects(); _check_triggers()
	if crash_timer > 0.0: return
	for i in range(checkpoint_beats.size()):
		if player.x >= START_X + checkpoint_beats[i] * _beat_width(): checkpoint_index = i
	if player.x >= START_X + float(level["length_beats"]) * _beat_width(): _finish()
	camera_x = clamp(player.x - 250.0, 0.0, START_X + float(level["length_beats"]) * _beat_width() - VIEW.x)

func _quiz_step(delta: float) -> void:
	quiz_time -= delta
	if quiz_time <= 0.0: _answer_quiz(-1)

func _input(event: InputEvent) -> void:
	if quiz_feedback_time > 0.0: return
	if quiz_active:
		if quiz_input_lock > 0.0: return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_answer_quiz(event.keycode - KEY_1)
		elif event is InputEventMouseButton and event.pressed:
			var choice: int = _quiz_choice_at(event.position)
			if choice >= 0: _answer_quiz(choice)
		elif event is InputEventScreenTouch and event.pressed:
			var touch_choice: int = _quiz_choice_at(event.position)
			if touch_choice >= 0: _answer_quiz(touch_choice)
		return
	if event.is_action_pressed("ui_cancel") and started:
		if finished: _return_to_menu()
		elif build_mode: _exit_builder()
		else: paused = not paused
		if paused or build_mode:
			if music_player != null: music_player.stream_paused = true
		else: _resume_music()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not started and (event.keycode == KEY_LEFT or event.keycode == KEY_UP):
			selected_level_index = max(0, selected_level_index - 1); return
		if not started and (event.keycode == KEY_RIGHT or event.keycode == KEY_DOWN):
			selected_level_index = min(unlocked_level, selected_level_index + 1); return
		if event.keycode == KEY_ENTER and not started: _start_run(); return
		if event.keycode == KEY_B and started and not quiz_active: _toggle_builder(); return
		if build_mode:
			if event.ctrl_pressed and event.keycode == KEY_Z: _undo_edit(); return
			if event.ctrl_pressed and event.keycode == KEY_Y: _redo_edit(); return
			if event.ctrl_pressed and event.keycode == KEY_C: _copy_selected(); return
			if event.ctrl_pressed and event.keycode == KEY_V: _paste_selected(); return
			_builder_key(event.keycode); return
	if build_mode:
		if event is InputEventMouseMotion:
			if drag_object_index >= 0: _builder_drag(event.position)
			elif pan_dragging: _builder_pan(event.position.x)
		if event is InputEventMouseButton and event.pressed: _builder_click(event.position, event.button_index)
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _builder_release()
		if event is InputEventScreenDrag and pan_dragging: _builder_pan(event.position.x)
		if event is InputEventScreenTouch and event.pressed: _builder_click(event.position, MOUSE_BUTTON_LEFT)
		if event is InputEventScreenTouch and not event.pressed: _builder_release()
		return
	if event.is_action_pressed("jump"):
		if crash_timer > 0.0:
			crash_timer = 0.0; _respawn_at_checkpoint(); return
		if finished: _restart_run()
		elif not started: _start_run()
		elif quiz_active: return
		else: jump_buffer = 0.12
	if event.is_action_pressed("dash"):
		if not started: _start_run()
		elif not quiz_active: _start_dash()
	if event is InputEventMouseButton and event.pressed:
		if not started:
			var level_choice: int = _level_choice_at(event.position)
			if level_choice >= 0: _choose_level(level_choice)
			else: _start_run()
		elif event.position.y > VIEW.y * 0.68:
			if event.position.x < VIEW.x * 0.55: jump_buffer = 0.12
			else: _start_dash()
	if event is InputEventScreenTouch and event.pressed:
		if not started:
			var level_touch_choice: int = _level_choice_at(event.position)
			if level_touch_choice >= 0: _choose_level(level_touch_choice)
			else: _start_run()
		elif event.position.y > VIEW.y * 0.62:
			if event.position.x < VIEW.x * 0.55: jump_buffer = 0.12
			else: _start_dash()

func _start_run() -> void:
	if not started:
		if selected_level_index != level_index:
			_apply_level(LevelData.campaign_level(selected_level_index)); player = Vector2(START_X, FLOOR_Y - PLAYER_SIZE.y); velocity = Vector2.ZERO; camera_x = 0.0; run_time = 0.0; checkpoint_index = 0
		shield_hits = 3; invulnerability = 0.0; score = 0; combo = 0; quiz_points = 0; quiz_streak = 0
	started = true; paused = false; _ensure_music(); message = "%s • FIND THE BEAT" % str(level["display_name"]); message_time = 1.5

func _level_choice_rect(index: int) -> Rect2:
	return Rect2(70.0 + index * 395.0, 150.0, 360.0, 360.0)

func _level_choice_at(pos: Vector2) -> int:
	for i in range(LEVEL_COUNT):
		if _level_choice_rect(i).has_point(pos): return i
	return -1

func _choose_level(index: int) -> void:
	if index < 0 or index >= LEVEL_COUNT: return
	if index > unlocked_level:
		message = "LOCKED • COMPLETE LEVEL %02d FIRST" % unlocked_level
		message_time = 1.4
		return
	selected_level_index = index
	_apply_level(LevelData.campaign_level(index))
	started = false; finished = false; paused = false; score = 0; combo = 0; quiz_points = 0; quiz_streak = 0; camera_x = 0.0; run_time = 0.0
	_start_run()

func _return_to_menu() -> void:
	started = false; finished = false; paused = false; build_mode = false; quiz_active = false; quiz_feedback_time = 0.0; crash_timer = 0.0; camera_x = 0.0; run_time = 0.0
	_apply_level(LevelData.campaign_level(selected_level_index))
	message = "SELECT A LEVEL"; message_time = 1.0

func _load_progress() -> void:
	unlocked_level = 0; best_scores = [0, 0, 0]
	if not OS.has_feature("web"): return
	var raw: Variant = JavaScriptBridge.eval("localStorage.getItem('neon_twice_progress') || ''")
	if not raw is String or str(raw).is_empty(): return
	var parsed: Variant = JSON.parse_string(str(raw))
	if not parsed is Dictionary: return
	unlocked_level = clampi(int(parsed.get("unlocked_level", 0)), 0, LEVEL_COUNT - 1)
	var saved_scores: Variant = parsed.get("best_scores", [])
	if saved_scores is Array:
		for i in range(mini(LEVEL_COUNT, saved_scores.size())): best_scores[i] = int(saved_scores[i])

func _save_progress() -> void:
	if not OS.has_feature("web"): return
	var payload: String = JSON.stringify({"unlocked_level": unlocked_level, "best_scores": best_scores})
	JavaScriptBridge.eval("localStorage.setItem('neon_twice_progress', %s)" % JSON.stringify(payload))

func _restart_run() -> void:
	_apply_level(level); player = Vector2(START_X, FLOOR_Y - PLAYER_SIZE.y); velocity = Vector2.ZERO; camera_x = 0.0; run_time = 0.0; checkpoint_index = 0; combo = 0; score = 0; quiz_points = 0; quiz_streak = 0; shield_hits = 3; invulnerability = 0.0; crash_timer = 0.0; checkpoint_flash = 0.0; finished = false; quiz_active = false; quiz_feedback_time = 0.0; quiz_snapshot.clear(); build_mode = false; paused = false; speed_until = 0.0; catapult_boost_left = 0.0; runtime_objects.clear(); _resume_music(); _start_run()

func _toggle_builder() -> void:
	build_mode = not build_mode; paused = build_mode
	if build_mode: _reset_edit_history()
	if music_player != null: music_player.stream_paused = build_mode
	message = "BUILDER ON" if build_mode else "RUN RESUMED"; message_time = 1.0

func _exit_builder() -> void:
	build_mode = false; paused = false
	_resume_music()
	message = "PRESS ENTER TO TEST"; message_time = 1.4

func _builder_key(key: Key) -> void:
	if key == KEY_ESCAPE or key == KEY_B: _exit_builder(); return
	if key == KEY_ENTER: _restart_run(); return
	if key == KEY_E: _export_level(); return
	if key == KEY_I: _import_level(); return
	if key == KEY_R: _apply_level(LevelData.campaign_level(level_index)); message = "DEFAULT LEVEL RESTORED"; message_time = 1.2; return
	if key >= KEY_1 and key <= KEY_9: selected_palette = clamp(key - KEY_1, 0, PALETTE.size() - 1)
	if key == KEY_0: selected_palette = 9

func _reset_edit_history() -> void:
	undo_stack = [level.duplicate(true)]
	redo_stack.clear()
	selected_object_index = -1
	drag_object_index = -1

func _record_edit() -> void:
	if undo_stack.is_empty() or undo_stack.back() != level:
		undo_stack.append(level.duplicate(true))
		if undo_stack.size() > 80: undo_stack.pop_front()
	redo_stack.clear()

func _restore_edit(snapshot: Dictionary) -> void:
	level = snapshot.duplicate(true)
	objects = level["objects"]
	triggers = level["triggers"]
	_apply_level(level)

func _undo_edit() -> void:
	if undo_stack.size() <= 1: return
	redo_stack.append(undo_stack.pop_back())
	_restore_edit(undo_stack.back())
	message = "UNDO"; message_time = 0.8

func _redo_edit() -> void:
	if redo_stack.is_empty(): return
	var snapshot: Dictionary = redo_stack.pop_back()
	undo_stack.append(snapshot)
	_restore_edit(snapshot)
	message = "REDO"; message_time = 0.8

func _object_index_at(pos: Vector2) -> int:
	var world_pos := Vector2(pos.x + camera_x, pos.y)
	for i in range(objects.size() - 1, -1, -1):
		if _object_rect(objects[i]).grow(12.0).has_point(world_pos): return i
	return -1

func _copy_selected() -> void:
	if selected_object_index < 0 or selected_object_index >= objects.size(): return
	clipboard_object = objects[selected_object_index].duplicate(true)
	message = "OBJECT COPIED"; message_time = 0.9

func _paste_selected() -> void:
	if clipboard_object.is_empty(): return
	var pasted: Dictionary = clipboard_object.duplicate(true)
	pasted["id"] = "custom-%03d" % objects.size()
	pasted["beat"] = float(pasted["beat"]) + 1.0
	objects.append(pasted)
	selected_object_index = objects.size() - 1
	_sync_level(); _record_edit(); message = "OBJECT PASTED"; message_time = 0.9

func _builder_drag(pos: Vector2) -> void:
	if drag_object_index < 0 or drag_object_index >= objects.size(): return
	var beat: float = max(0.0, round((camera_x + pos.x - START_X) / _beat_width() * 4.0) / 4.0)
	var lane: float = clamp(round((FLOOR_Y - pos.y) / LANE_HEIGHT * 2.0) / 2.0, -1.0, 3.0)
	objects[drag_object_index]["beat"] = beat
	objects[drag_object_index]["lane"] = lane
	_sync_level()

func _builder_pan(pos_x: float) -> void:
	var delta_x: float = pos_x - pan_last_x
	if abs(delta_x) > 0.5: pan_moved = true
	var max_camera: float = max(0.0, START_X + float(level["length_beats"]) * _beat_width() - VIEW.x)
	camera_x = clamp(camera_x - delta_x, 0.0, max_camera)
	pan_last_x = pos_x

func _builder_release() -> void:
	if drag_object_index >= 0:
		_record_edit()
		message = "OBJECT MOVED"; message_time = 0.9
	drag_object_index = -1
	if pan_dragging and not pan_moved: _place_builder_object(pending_place_pos)
	pan_dragging = false
	pan_moved = false

func _place_builder_object(pos: Vector2) -> void:
	var beat: float = max(0.0, round((camera_x + pos.x - START_X) / _beat_width() * 4.0) / 4.0)
	var lane: float = clamp(round((FLOOR_Y - pos.y) / LANE_HEIGHT * 2.0) / 2.0, -1.0, 3.0)
	var kind: String = PALETTE[selected_palette]
	if kind == "timetable": triggers.append({"id": "quiz-custom-%03d" % triggers.size(), "type": "quiz", "beat": beat, "table": 2, "time_limit": 10.0})
	else: objects.append({"id": "custom-%03d" % objects.size(), "type": kind, "beat": beat, "lane": lane, "properties": _default_properties(kind)})
	_sync_level(); _record_edit()

func _builder_click(pos: Vector2, button: MouseButton) -> void:
	if pos.x < 300.0 and pos.y > 130.0 and pos.y < 620.0:
		var index := int((pos.y - 130.0) / 42.0)
		if index >= 0 and index < PALETTE.size(): selected_palette = index
		return
	if pos.y < 115.0:
		if pos.x < 160.0: _export_level()
		elif pos.x < 300.0: _import_level()
		return
	var beat: float = max(0.0, round((camera_x + pos.x - START_X) / _beat_width() * 4.0) / 4.0)
	var lane: float = clamp(round((FLOOR_Y - pos.y) / LANE_HEIGHT * 2.0) / 2.0, -1.0, 3.0)
	if button == MOUSE_BUTTON_RIGHT: _remove_nearest(beat, lane); _record_edit(); return
	if button == MOUSE_BUTTON_MIDDLE:
		selected_object_index = _object_index_at(pos); _copy_selected(); return
	if button == MOUSE_BUTTON_LEFT:
		selected_object_index = _object_index_at(pos)
		if selected_object_index >= 0:
			drag_object_index = selected_object_index
			return
		pan_dragging = true; pan_last_x = pos.x; pan_moved = false; pending_place_pos = pos

func _default_properties(kind: String) -> Dictionary:
	match kind:
		"catapult": return {"delay_beats": 1.0, "launch_beats": 2.0}
		"bounce_pad": return {"strength": 1.0}
		"moving_platform": return {"travel_beats": 4.0, "distance_lanes": 2.0}
		"gravity_portal": return {"duration_beats": 8.0}
		"speed_ring": return {"multiplier": 1.25, "duration_beats": 4.0}
	return {}

func _remove_nearest(beat: float, lane: float) -> void:
	var best := -1; var nearest := 0.35
	for i in range(objects.size()):
		var object = objects[i]; var distance: float = abs(float(object["beat"]) - beat) + abs(float(object["lane"]) - lane) * 0.25
		if distance < nearest: best = i; nearest = distance
	if best >= 0: objects.remove_at(best)
	for i in range(triggers.size() - 1, -1, -1):
		if abs(float(triggers[i]["beat"]) - beat) < 0.35: triggers.remove_at(i)
	_sync_level()

func _sync_level() -> void:
	level["objects"] = objects; level["triggers"] = triggers; level = LevelData.validate(level); objects = level["objects"]; triggers = level["triggers"]

func _export_level() -> void:
	var json := JSON.stringify(level, "  ")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("const b=new Blob([%s],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='neon-twice-level.json';a.click();" % JSON.stringify(json))
	else:
		DisplayServer.clipboard_set(json)
	message = "LEVEL EXPORTED TO CLIPBOARD"; message_time = 1.5

func _import_level() -> void:
	var parsed = JSON.parse_string(DisplayServer.clipboard_get())
	if parsed is Dictionary: _apply_level(parsed); message = "LEVEL IMPORTED"
	else: message = "IMPORT FAILED: COPY LEVEL JSON FIRST"
	message_time = 1.8

func _update_objects() -> void:
	for object in objects + runtime_objects:
		var id: String = object["id"]; var kind: String = object["type"]; var x := _object_x(object)
		if consumed.has(id): continue
		if kind == "catapult" and player.x >= x and not catapult_state.has(id): catapult_state[id] = run_time + float(object["properties"].get("delay_beats", 1.0)) * _music_beat()
		if kind == "catapult" and catapult_state.has(id) and run_time >= catapult_state[id]: catapult_boost_left = float(object["properties"].get("launch_beats", 2.0)) * _music_beat(); velocity.y = -180.0; consumed[id] = true; message = "CATAPULT LAUNCH"; message_time = 0.8
		if kind == "gravity_portal" and player.x >= x:
			gravity_sign = -1.0; gravity_until = run_time + float(object["properties"].get("duration_beats", 8.0)) * _music_beat(); consumed[id] = true

func _speed_multiplier() -> float:
	if run_time < speed_until: return 1.25
	return 1.0

func _chase_active() -> bool:
	var chase_beat: float = float(level.get("chase_beat", -1.0))
	return started and chase_beat >= 0.0 and player.x >= START_X + chase_beat * _beat_width()

func _start_chase() -> void:
	chase_started = true; chase_flash = 1.2; message = "THE CARNIVAL IS CHASING YOU"; message_time = 1.5
	var chase_beat: float = float(level.get("chase_beat", 92.0))
	for i in range(14):
		var kind: String = "spike" if i % 3 != 1 else "block"
		var beat: float = chase_beat + 5.0 + float(i) * 3.5 + rng.randf_range(-0.22, 0.22)
		var lane: float = 0.0 if i % 4 != 2 else 0.75
		var properties: Dictionary = {"height": 1.0 + float(i % 2) * 0.25} if kind == "block" else {}
		runtime_objects.append({"id": "chase-%02d" % i, "type": kind, "beat": beat, "lane": lane, "properties": properties})

func _check_objects() -> void:
	var body := Rect2(player, PLAYER_SIZE)
	for object in objects + runtime_objects:
		var id: String = object["id"]; var kind: String = object["type"]
		if consumed.has(id): continue
		if invulnerability > 0.0 and (kind == "spike" or kind == "block"): continue
		var rect := _object_rect(object)
		if not body.intersects(rect): continue
		match kind:
			"spike", "block":
				if dash_left > 0.0: score += 40; consumed[id] = true; _spawn_burst(rect.position + rect.size * 0.5, Color("#ff698f"), 14)
				else: _take_hit("HIT THE BEAT WALL")
			"bounce_pad": velocity.y = JUMP_VELOCITY * float(object["properties"].get("strength", 1.0)); consumed[id] = true; _combo_event("BOUNCE")
			"speed_ring": score += 75; consumed[id] = true; speed_until = run_time + float(object["properties"].get("duration_beats", 4.0)) * _music_beat(); _combo_event("SPEED UP"); _spawn_burst(rect.position + rect.size * 0.5, Color("#f5e27e"), 10)
			"star": score += 75; consumed[id] = true; _combo_event("COLLECT"); _spawn_burst(rect.position + rect.size * 0.5, Color("#f5e27e"), 10)
			"checkpoint": checkpoint_index = max(checkpoint_index, checkpoint_beats.find(float(object["beat"])))

func _check_triggers() -> void:
	for trigger in triggers:
		if triggered.has(trigger["id"]): continue
		if player.x >= START_X + float(trigger["beat"]) * _beat_width(): triggered[trigger["id"]] = true; _start_quiz(trigger); return

func _start_quiz(trigger: Dictionary) -> void:
	quiz_snapshot = {"player": player, "velocity": velocity, "camera_x": camera_x, "run_time": run_time, "gravity_sign": gravity_sign, "gravity_until": gravity_until, "speed_until": speed_until, "catapult_boost_left": catapult_boost_left, "music_position": music_player.get_playback_position() if music_player != null else 0.0}
	quiz_active = true; quiz_input_lock = 0.18; quiz_feedback_time = 0.0; quiz_time = 10.0; quiz_table = int(trigger.get("table", 2)); quiz_number = rng.randi_range(1, 12)
	var correct: int = quiz_number * quiz_table; quiz_choices = [correct, correct + rng.randi_range(1, 3), max(2, correct - rng.randi_range(1, 3))]; quiz_choices.shuffle(); quiz_correct_index = quiz_choices.find(correct); message = "TIME SHIFT"; message_time = 1.0

func _answer_quiz(choice: int) -> void:
	if not quiz_active: return
	quiz_active = false
	var correct_answer: int = quiz_number * quiz_table
	if choice == quiz_correct_index:
		_restore_quiz_snapshot()
		quiz_points += 1; quiz_streak += 1
		var reward: int = 250 + max(0, quiz_streak - 1) * 100
		score += reward; invulnerability = max(invulnerability, 2.0); _combo_event("SOLVED"); message = "CORRECT +%d • SHIELD 2 SEC" % reward
	else:
		_restore_quiz_snapshot()
		quiz_feedback_answer = correct_answer; quiz_feedback_reason = "TIME UP" if choice < 0 else "WRONG TIMES TABLE"; quiz_feedback_text = "%d × %d = %d • CORRECT ANSWER: %d" % [quiz_table, quiz_number, correct_answer, correct_answer]; quiz_feedback_time = 2.0; combo = 0; quiz_streak = 0; flash = 0.25
		if music_player != null: music_player.stream_paused = true
	message_time = 1.5

func _restore_quiz_snapshot() -> void:
	if quiz_snapshot.is_empty(): return
	player = quiz_snapshot["player"]; velocity = quiz_snapshot["velocity"]; camera_x = float(quiz_snapshot["camera_x"]); run_time = float(quiz_snapshot["run_time"]); gravity_sign = float(quiz_snapshot["gravity_sign"]); gravity_until = float(quiz_snapshot["gravity_until"]); speed_until = float(quiz_snapshot["speed_until"]); catapult_boost_left = float(quiz_snapshot["catapult_boost_left"])
	if music_player != null:
		music_player.seek(float(quiz_snapshot["music_position"]))
	_resume_music()
	quiz_snapshot.clear()

func _resolve_quiz_feedback() -> void:
	quiz_feedback_time = 0.0
	_resume_music()
	_take_hit(quiz_feedback_reason)
	message = quiz_feedback_reason; message_time = 1.0

func _start_dash() -> void:
	if dash_cooldown > 0.0 or dash_left > 0.0: return
	dash_left = DASH_TIME; dash_cooldown = _music_beat() * 2.0; velocity = Vector2(DASH_SPEED, 0.0); _combo_event("DASH")

func _take_hit(reason: String) -> void:
	if invulnerability > 0.0: return
	if shield_hits > 0:
		shield_hits -= 1; invulnerability = 0.8; velocity.y = -260.0; flash = 0.22; message = "%s • SHIELD %d/3" % [reason, shield_hits]; message_time = 1.2
	else: _crash(reason)

func _crash(reason: String) -> void:
	combo = 0; quiz_streak = 0; flash = 0.35; crash_reason = reason; crash_timer = 0.42; message = "CRASH!"; message_time = 0.42; _spawn_burst(player + PLAYER_SIZE * 0.5, Color("#ff698f"), 24)

func _respawn_at_checkpoint() -> void:
	player = Vector2(START_X + checkpoint_beats[checkpoint_index] * _beat_width(), FLOOR_Y - PLAYER_SIZE.y)
	velocity = Vector2.ZERO; dash_left = 0.0; dash_cooldown = 0.0; gravity_sign = 1.0; gravity_until = 0.0; speed_until = 0.0; catapult_boost_left = 0.0; quiz_active = false; quiz_feedback_time = 0.0; consumed.clear(); triggered.clear(); catapult_state.clear(); runtime_objects.clear(); invulnerability = 0.55; checkpoint_flash = 1.5
	for trigger in triggers:
		if float(trigger["beat"]) < checkpoint_beats[checkpoint_index]: triggered[trigger["id"]] = true
	if _chase_active(): _start_chase()
	message = "CHECKPOINT %02d • GO!" % checkpoint_index; message_time = 1.0
	for trigger in triggers:
		if float(trigger["beat"]) < checkpoint_beats[checkpoint_index]: triggered[trigger["id"]] = true

func _finish() -> void:
	finished = true
	best_scores[level_index] = max(int(best_scores[level_index]), score)
	if level_index == unlocked_level and unlocked_level < LEVEL_COUNT - 1: unlocked_level += 1
	_save_progress()
	message = "LEVEL COMPLETE"; message_time = 99.0

func _is_grounded() -> bool:
	if gravity_sign < 0.0: return false
	if player.y + PLAYER_SIZE.y >= FLOOR_Y - 1.0: return true
	for platform in objects:
		if platform["type"] == "moving_platform":
			var rect := _object_rect(platform)
			if abs(player.y + PLAYER_SIZE.y - rect.position.y) < 8.0 and player.x + PLAYER_SIZE.x > rect.position.x and player.x < rect.end.x: return true
	return false

func _jump_beat_event() -> void:
	var beat: float = _music_beat()
	var error: float = _beat_distance()
	if error <= beat * 0.10:
		_combo_event("PERFECT JUMP")
		score += 150
		message = "PERFECT JUMP +150"
	elif error <= beat * 0.24:
		_combo_event("GOOD JUMP")
		score += 60
		message = "GOOD JUMP +60"
	else:
		_combo_event("JUMP")

func _combo_event(label: String) -> void:
	combo += 1; best_combo = max(best_combo, combo); score += 20 + combo * 2; message = "GOOD " + label; message_time = 0.55
func _object_x(object: Dictionary) -> float: return START_X + float(object["beat"]) * _beat_width()
func _object_y(object: Dictionary) -> float:
	var base := FLOOR_Y - float(object["lane"]) * LANE_HEIGHT
	if object["type"] == "moving_platform":
		var travel: float = max(1.0, float(object["properties"].get("travel_beats", 4.0))) * _music_beat()
		var phase := fmod(run_time, travel) / travel
		var pingpong := sin(phase * TAU) * 0.5 + 0.5
		return base - pingpong * float(object["properties"].get("distance_lanes", 2.0)) * LANE_HEIGHT
	return base

func _object_rect(object: Dictionary) -> Rect2:
	var kind: String = object["type"]; var x := _object_x(object); var y := _object_y(object)
	match kind:
		"spike": return Rect2(x - 20, FLOOR_Y - 54, 40, 54)
		"block": return Rect2(x - 22, FLOOR_Y - 82 * float(object["properties"].get("height", 1.0)), 44, 82 * float(object["properties"].get("height", 1.0)))
		"catapult", "bounce_pad": return Rect2(x - 32, FLOOR_Y - 28, 64, 28)
		"moving_platform": return Rect2(x - 45, y - 15, 90, 30)
		"gravity_portal": return Rect2(x - 28, FLOOR_Y - 170, 56, 170)
		"speed_ring", "star": return Rect2(x - 18, y - 18, 36, 36)
		"checkpoint": return Rect2(x - 16, FLOOR_Y - 100, 32, 100)
	return Rect2(x - 20, y - 20, 40, 40)

func _quiz_choice_at(pos: Vector2) -> int:
	for i in range(3):
		if _quiz_choice_rect(i).has_point(pos): return i
	return -1

func _quiz_choice_rect(index: int) -> Rect2:
	return Rect2(140.0 + index * 350.0, 310.0, 300.0, 150.0)

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i]["p"] += particles[i]["v"] * delta; particles[i]["v"] *= 0.94; particles[i]["life"] -= delta
		if particles[i]["life"] <= 0.0: particles.remove_at(i)
func _spawn_burst(origin: Vector2, color: Color, count: int) -> void:
	for i in count: particles.append({"p": origin, "v": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(40.0, 220.0), "life": rng.randf_range(0.25, 0.7), "color": color})

func _draw() -> void:
	_draw_background(); _draw_world(); _draw_hud()
	if not started: _draw_title()
	if quiz_active or quiz_feedback_time > 0.0: _draw_quiz()
	if build_mode: _draw_builder()
	if finished: _draw_finish()
	if flash > 0.0: draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(1.0, 0.35, 0.5, flash * 0.35))

func _draw_background() -> void:
	var pulse: float = 0.5 + 0.5 * sin(background_time * TAU / _music_beat())
	var screen_size := get_viewport_rect().size
	var fill_size := Vector2(max(screen_size.x, VIEW.x), max(screen_size.y, VIEW.y))
	var theme: String = str(level.get("theme", "skeleton"))
	var base_color: Color = Color("#17143e")
	if theme == "metro": base_color = Color("#101b38")
	if theme == "boss": base_color = Color("#24133f")
	draw_rect(Rect2(Vector2.ZERO, fill_size), base_color)
	var band_count := int(ceil(fill_size.y / 80.0))
	var band_start: Color = Color("#21194e") if theme == "skeleton" else (Color("#14264b") if theme == "metro" else Color("#32164f"))
	var band_end: Color = Color("#583070") if theme == "skeleton" else (Color("#254d78") if theme == "metro" else Color("#8d295e"))
	for band in range(band_count): draw_rect(Rect2(0, band * 80, fill_size.x, 82), band_start.lerp(band_end, min(1.0, float(band) / 9.0)))
	for x in range(-100, int(fill_size.x) + 1500, 100):
		var sx := fmod(x - camera_x * 0.15, 1500.0); draw_line(Vector2(sx, 0), Vector2(sx - 260, VIEW.y), Color(0.7, 0.45, 0.95, 0.11), 1.0)
	for y in range(80, int(fill_size.y) + 80, 80): draw_line(Vector2(0, y), Vector2(fill_size.x, y), Color(0.7, 0.45, 0.95, 0.10), 1.0)
	_draw_beat_layers(fill_size, pulse)
	_draw_background_details(fill_size, pulse)
	match theme:
		"metro": _draw_metro_background(pulse, fill_size)
		"boss": _draw_boss_background(pulse, fill_size)
		_: _draw_kawaii_bone_carnival(pulse)
	if theme == "skeleton": _draw_chaser()
	draw_rect(Rect2(Vector2.ZERO, fill_size), Color(0.92, 0.96, 1.0, BEAT_FLASH_STRENGTH * _beat_pulse()))

func _draw_beat_layers(fill_size: Vector2, pulse: float) -> void:
	# Parallax ribbons and halo rings swell on every beat behind the characters.
	var beat_bloom := pow(max(0.0, sin(background_time * TAU / _music_beat())), 12.0)
	for layer in range(4):
		var y := 135.0 + layer * 92.0 + sin(background_time * (0.7 + layer * 0.2)) * 10.0
		var drift := fmod(background_time * (24.0 + layer * 12.0) - camera_x * (0.08 + layer * 0.03), 1540.0)
		draw_line(Vector2(-180.0 + drift, y), Vector2(240.0 + drift, y - 22.0), Color(0.45, 0.88, 1.0, 0.07 + pulse * 0.05), 10.0 + beat_bloom * 8.0)
	for i in range(5):
		var halo_x := fmod(140.0 + i * 290.0 - camera_x * 0.14, 1540.0) - 120.0
		var halo_y := 220.0 + (i % 3) * 105.0
		draw_arc(Vector2(halo_x, halo_y), 30.0 + beat_bloom * 18.0, 0.0, TAU, 24, Color(0.95, 0.55, 0.88, 0.08 + pulse * 0.05), 4.0)

func _draw_background_details(fill_size: Vector2, pulse: float) -> void:
	# Small decorative scenery fills the negative space without obscuring hazards.
	for i in range(12):
		var star_x := fmod(55.0 + i * 137.0 - camera_x * 0.06, fill_size.x + 180.0) - 90.0
		var star_y := 105.0 + fmod(i * 61.0 + background_time * (8.0 + i % 3), max(120.0, fill_size.y - 250.0))
		var star_size := 2.0 + float(i % 3) + pulse * 2.0
		_draw_sparkle(Vector2(star_x, star_y), star_size, Color(1.0, 0.86, 0.55, 0.42))
	for i in range(7):
		var tower_x := fmod(i * 210.0 - camera_x * 0.11, 1600.0) - 80.0
		var tower_h := 38.0 + float((i * 17) % 45)
		draw_rect(Rect2(tower_x, FLOOR_Y - tower_h, 92.0, tower_h), Color(0.12, 0.10, 0.30, 0.48))
		for window in range(3):
			var window_color := Color("#7cf5ff") if (window + i) % 2 == 0 else Color("#ff9dbc")
			draw_rect(Rect2(tower_x + 16.0 + window * 23.0, FLOOR_Y - tower_h + 15.0, 9.0, 12.0), Color(window_color, 0.34 + pulse * 0.18))
	for i in range(5):
		var candy_x := fmod(210.0 + i * 285.0 + sin(background_time * 0.5 + i) * 24.0 - camera_x * 0.18, 1500.0) - 100.0
		var candy_y := 470.0 + sin(background_time * 1.4 + i * 1.5) * 12.0
		draw_circle(Vector2(candy_x, candy_y), 15.0 + pulse * 3.0, Color(0.98, 0.70, 0.86, 0.17))
		draw_line(Vector2(candy_x - 11.0, candy_y), Vector2(candy_x + 11.0, candy_y), Color(0.70, 0.92, 1.0, 0.22), 4.0)

func _draw_metro_background(pulse: float, fill_size: Vector2) -> void:
	var train_y: float = 250.0 + sin(background_time * 0.9) * 8.0
	var train_x: float = fmod(980.0 - background_time * 80.0 - camera_x * 0.18, 1500.0) - 220.0
	draw_rect(Rect2(train_x, train_y, 430.0, 120.0), Color(0.12, 0.28, 0.48, 0.9))
	draw_rect(Rect2(train_x + 18.0, train_y + 18.0, 394.0, 42.0), Color("#7cf5ff"))
	for i in range(5):
		var window_rect: Rect2 = Rect2(train_x + 28.0 + i * 76.0, train_y + 26.0, 54.0, 26.0)
		draw_rect(window_rect, Color("#17244c"))
		draw_circle(window_rect.position + Vector2(18.0, 13.0), 5.0 + pulse * 2.0, Color("#ffd8ed"))
	draw_line(Vector2(train_x + 25.0, train_y + 92.0), Vector2(train_x + 405.0, train_y + 92.0), Color("#ff9dbc"), 7.0)
	for i in range(8):
		var light_x: float = fmod(i * 190.0 - camera_x * 0.35 + background_time * 160.0, 1500.0) - 80.0
		draw_line(Vector2(light_x, 120.0 + (i % 3) * 58.0), Vector2(light_x + 45.0, 120.0 + (i % 3) * 58.0), Color(0.49, 0.96, 1.0, 0.26 + pulse * 0.18), 5.0)
	for i in range(6):
		var rail_x: float = fmod(i * 260.0 - camera_x * 0.22, 1600.0) - 120.0
		draw_line(Vector2(rail_x, FLOOR_Y - 125.0), Vector2(rail_x + 130.0, FLOOR_Y - 125.0), Color("#4371a4"), 3.0)
		draw_line(Vector2(rail_x + 20.0, FLOOR_Y - 118.0), Vector2(rail_x + 150.0, FLOOR_Y - 118.0), Color("#ff9dbc"), 2.0)

func _draw_boss_background(pulse: float, fill_size: Vector2) -> void:
	var core: Vector2 = Vector2(fill_size.x * 0.78, 230.0 + sin(background_time * 0.8) * 12.0)
	for ring in range(4):
		draw_arc(core, 95.0 + ring * 38.0 + pulse * 12.0, background_time * (0.35 + ring * 0.08), background_time * (0.35 + ring * 0.08) + PI * 1.55, 32, Color(1.0, 0.55, 0.78, 0.16), 7.0)
	draw_circle(core, 82.0 + pulse * 8.0, Color(0.95, 0.36, 0.72, 0.18))
	draw_circle(core, 56.0, Color("#ff9dbc"))
	draw_circle(core + Vector2(-20.0, -8.0), 10.0, Color("#34245e"))
	draw_circle(core + Vector2(20.0, -8.0), 10.0, Color("#34245e"))
	draw_arc(core + Vector2(0.0, 8.0), 25.0 + pulse * 4.0, 0.2, PI - 0.2, 20, Color("#34245e"), 5.0)
	for i in range(12):
		var shard_x: float = fmod(i * 137.0 - camera_x * 0.12, fill_size.x + 220.0) - 100.0
		var shard_y: float = 110.0 + fmod(background_time * (14.0 + i % 4) + i * 51.0, 360.0)
		_draw_sparkle(Vector2(shard_x, shard_y), 4.0 + pulse * 3.0, Color("#f5e27e"))

func _draw_chaser() -> void:
	var chase_mode: bool = _chase_active()
	var chaser_offset: float = 250.0 if chase_mode else 350.0
	var chaser_x: float = clampf(player.x - camera_x - chaser_offset, 150.0, 470.0)
	var leader_origin: Vector2 = Vector2(chaser_x, 580.0)
	_draw_marching_skeleton(leader_origin, 0.70, Color("#fff5dd"), 0.0, true)
	for object in runtime_objects:
		var target_x: float = _object_x(object) - camera_x
		if target_x > chaser_x and target_x < VIEW.x + 120.0:
			draw_line(Vector2(chaser_x + 128.0, 270.0), Vector2(target_x, FLOOR_Y - 36.0), Color(1.0, 0.45, 0.62, 0.28), 3.0)

func _draw_marching_skeleton(origin: Vector2, scale: float, tint: Color, phase_offset: float, leader: bool) -> void:
	if skeleton_sprite == null: return
	var sprite_frame_count: float = 12.0
	var sprite_frame_position: float = fmod(background_time / _music_beat() * 6.0 + phase_offset, sprite_frame_count)
	var sprite_frame_index: int = int(floor(sprite_frame_position))
	var sprite_cell_size: Vector2 = Vector2(450.0, 594.0)
	var sprite_column: int = sprite_frame_index % 4
	var sprite_row: int = int(sprite_frame_index / 4)
	var sprite_source_rect: Rect2 = Rect2(Vector2(sprite_column * 450.0, sprite_row * 594.0), sprite_cell_size)
	var sprite_destination_size: Vector2 = sprite_cell_size * scale
	var sprite_destination: Rect2 = Rect2(origin - Vector2(sprite_destination_size.x * 0.5, sprite_destination_size.y), sprite_destination_size)
	var sprite_opacity: float = (0.98 if leader else 0.84) * tint.a
	draw_texture_rect_region(skeleton_sprite, sprite_destination, sprite_source_rect, Color(1.0, 1.0, 1.0, sprite_opacity))
	return

func _draw_kawaii_bone_carnival(pulse: float) -> void:
	# Original pastel spooky-cute background set piece: all shapes are drawn in code.
	var drift := sin(background_time * 0.7)
	var moon := Vector2(1000.0 + drift * 34.0, 178.0 + sin(background_time * 0.45) * 12.0)
	draw_circle(moon, 108.0 + pulse * 7.0, Color(1.0, 0.78, 0.88, 0.16))
	draw_circle(moon, 82.0, Color("#ffd8ed"))
	draw_circle(moon + Vector2(24, -10), 9.0, Color("#eaaed3"))
	draw_circle(moon + Vector2(-30, 28), 6.0, Color("#eaaed3"))
	draw_circle(moon + Vector2(36, 35), 5.0, Color("#eaaed3"))

	# Tiny pastel ghost friends drift in a slow parade.
	for i in range(5):
		var ghost_x := fmod(120.0 + i * 250.0 + background_time * (18.0 + i * 4.0), 1500.0) - 80.0
		var ghost_y := 150.0 + i * 32.0 + sin(background_time * 1.2 + i * 1.7) * 24.0
		_draw_cute_ghost(Vector2(ghost_x, ghost_y), [Color("#b8f4ff"), Color("#e8c8ff"), Color("#ffd0e5")][i % 3], 0.62)
	# A candy-coloured stream of confetti keeps the background lively without
	# competing with the single detailed skeleton leader.
	for i in range(7):
		var confetti_x := fmod(80.0 + i * 205.0 - camera_x * 0.28, 1500.0) - 110.0
		var confetti_y := 110.0 + fmod(background_time * (24.0 + i * 2.0) + i * 73.0, 310.0)
		var confetti_color: Color = [Color("#7cf5ff"), Color("#ff9dbc"), Color("#f5e27e"), Color("#b06cff")][i % 4]
		draw_line(Vector2(confetti_x, confetti_y), Vector2(confetti_x + 9.0, confetti_y + 12.0), Color(confetti_color, 0.65), 4.0)
	# Beat sparkles pop across the parade like a cartoon celebration.
	for i in range(8):
		var angle: float = background_time * 0.8 + i * TAU / 8.0
		var sparkle: Vector2 = Vector2(1030.0, 292.0) + Vector2(cos(angle), sin(angle)) * (155.0 + pulse * 18.0)
		_draw_sparkle(sparkle, 5.0 + pulse * 4.0, Color("#f5e27e"))

func _draw_cute_ghost(pos: Vector2, tint: Color, alpha: float) -> void:
	var body := Color(tint, alpha)
	draw_circle(pos + Vector2(0, -13), 28.0, body)
	draw_rect(Rect2(pos.x - 28, pos.y - 14, 56, 31), body)
	for i in range(3): draw_circle(Vector2(pos.x - 20 + i * 20, pos.y + 18), 10.0, body)
	draw_circle(pos + Vector2(-9, -15), 5.0, Color("#34245e"))
	draw_circle(pos + Vector2(9, -15), 5.0, Color("#34245e"))
	draw_circle(pos + Vector2(0, 0), 4.0, Color("#ff9dbc"))

func _draw_sparkle(pos: Vector2, size: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -size), pos + Vector2(size * 0.35, -size * 0.35), pos + Vector2(size, 0), pos + Vector2(size * 0.35, size * 0.35), pos + Vector2(0, size), pos + Vector2(-size * 0.35, size * 0.35), pos + Vector2(-size, 0), pos + Vector2(-size * 0.35, -size * 0.35)]), color)

func _draw_world() -> void:
	var screen_size := get_viewport_rect().size
	var fill_width: float = max(screen_size.x, VIEW.x)
	var fill_height: float = max(screen_size.y, VIEW.y)
	draw_rect(Rect2(0, FLOOR_Y, fill_width, fill_height - FLOOR_Y), Color("#151b3d"))
	for x in range(-100, int(fill_width) + 1600, 80):
		var sx := fmod(x - camera_x, 1600.0); draw_line(Vector2(sx, FLOOR_Y), Vector2(sx - 70, fill_height), Color("#28346a"), 2.0)
	_draw_checkpoint_marker()
	if started and not build_mode and not quiz_active and not finished and not _is_grounded(): _draw_landing_trace()
	for object in objects + runtime_objects:
		if not consumed.has(object["id"]): _draw_object(object)
	for particle in particles: draw_circle(particle["p"] - Vector2(camera_x, 0), 3.0 + particle["life"] * 4.0, Color(particle["color"], particle["life"]))
	var center := player - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5; draw_set_transform(center, run_time * 2.0 if dash_left > 0.0 else 0.0, Vector2.ONE); draw_rect(Rect2(-23, -23, 46, 46), Color("#75f1ff")); draw_rect(Rect2(-16, -16, 32, 32), Color("#182450")); draw_rect(Rect2(-8, -8, 16, 16), Color("#f5e27e")); draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shield_hits > 0 or invulnerability > 0.0: draw_arc(center, 38.0 + sin(background_time * 8.0) * 3.0, 0.0, TAU, 32, Color("#a8ffd0") if shield_hits > 0 else Color("#ffffff"), 4.0)
	if crash_timer > 0.0:
		draw_circle(player - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5, 42.0 + sin(background_time * 24.0) * 5.0, Color(1.0, 0.25, 0.45, 0.12))

func _draw_landing_trace() -> void:
	var step := 0.045
	var simulated_position := player
	var simulated_velocity := velocity
	var previous_screen := simulated_position - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5
	var landing := Vector2.ZERO
	var found_landing := false
	for i in range(32):
		simulated_velocity.y += GRAVITY * gravity_sign * step
		simulated_position += simulated_velocity * step
		var current_screen := simulated_position - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5
		draw_line(previous_screen, current_screen, Color(0.66, 1.0, 0.83, 0.34), 3.0)
		if i % 3 == 0: draw_circle(current_screen, 4.0 + float(i % 2), Color(0.66, 1.0, 0.83, 0.75))
		previous_screen = current_screen
		if gravity_sign > 0.0 and simulated_position.y + PLAYER_SIZE.y >= FLOOR_Y:
			landing = Vector2(simulated_position.x, FLOOR_Y - PLAYER_SIZE.y); found_landing = true; break
		if gravity_sign < 0.0 and simulated_position.y <= 90.0:
			landing = Vector2(simulated_position.x, 90.0); found_landing = true; break
	if not found_landing: return
	var landing_screen := landing - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5
	draw_line(landing_screen + Vector2(-22, 0), landing_screen + Vector2(22, 0), Color("#a8ffd0"), 4.0)
	draw_line(landing_screen + Vector2(0, -22), landing_screen + Vector2(0, 22), Color(0.66, 1.0, 0.83, 0.72), 3.0)
	draw_arc(landing_screen, 18.0 + sin(background_time * 8.0) * 3.0, 0.0, TAU, 20, Color("#a8ffd0"), 3.0)

func _draw_checkpoint_marker() -> void:
	var marker_x: float = START_X + float(checkpoint_beats[checkpoint_index]) * _beat_width() - camera_x
	var glow: float = 0.16 + min(0.46, checkpoint_flash * 0.35)
	draw_line(Vector2(marker_x, FLOOR_Y - 116), Vector2(marker_x, FLOOR_Y + 4), Color(0.66, 1.0, 0.83, glow), 5.0)
	draw_circle(Vector2(marker_x, FLOOR_Y - 116), 15.0 + checkpoint_flash * 5.0, Color(0.66, 1.0, 0.83, glow * 0.55))
	draw_arc(Vector2(marker_x, FLOOR_Y - 116), 24.0 + checkpoint_flash * 7.0, 0.0, TAU, 24, Color(0.66, 1.0, 0.83, glow), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(marker_x - 55, FLOOR_Y - 134), "CHECKPOINT %02d" % checkpoint_index, HORIZONTAL_ALIGNMENT_CENTER, 110, 13, Color(0.75, 1.0, 0.86, glow + 0.15))

func _draw_object(object: Dictionary) -> void:
	var kind: String = object["type"]; var rect := _object_rect(object); rect.position.x -= camera_x; var center := rect.get_center()
	match kind:
		"spike":
			draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x, FLOOR_Y), Vector2(center.x, rect.position.y), Vector2(rect.end.x, FLOOR_Y)]), Color("#ed496f"))
			draw_line(Vector2(center.x - 7, rect.position.y + 18), Vector2(center.x + 7, rect.position.y + 30), Color("#ffd6e2"), 4.0)
		"block":
			draw_rect(rect, Color("#ed496f")); draw_rect(rect.grow(-7.0), Color("#8d2348"), false, 4.0); draw_circle(rect.get_center(), 8.0, Color("#ffb6c9"))
		"catapult":
			draw_rect(rect, Color("#55d68a")); draw_line(rect.position + Vector2(10, 10), rect.end - Vector2(10, 10), Color("#124d46"), 4.0); draw_circle(Vector2(center.x, rect.position.y + 4), 10.0, Color("#a8ffd0"))
		"bounce_pad":
			draw_rect(rect, Color("#55d68a")); draw_line(Vector2(rect.position.x + 8, rect.end.y - 6), Vector2(center.x, rect.position.y + 5), Color("#124d46"), 4.0); draw_line(Vector2(rect.end.x - 8, rect.end.y - 6), Vector2(center.x, rect.position.y + 5), Color("#124d46"), 4.0)
		"moving_platform":
			draw_rect(rect, Color("#55d68a")); draw_line(Vector2(rect.position.x - 18, center.y), Vector2(rect.position.x - 3, center.y), Color("#a8ffd0"), 3.0); draw_line(Vector2(rect.end.x + 3, center.y), Vector2(rect.end.x + 18, center.y), Color("#a8ffd0"), 3.0)
		"gravity_portal":
			draw_circle(center, 35.0 + sin(background_time * 4.0) * 3.0, Color(0.25, 0.95, 0.58, 0.18)); draw_arc(center, 35.0, 0.0, TAU, 24, Color("#55d68a"), 7.0); draw_arc(center, 20.0, 0.0, TAU, 16, Color("#a8ffd0"), 3.0)
		"speed_ring":
			draw_arc(center, 18.0, 0.0, TAU, 20, Color("#55d68a"), 6.0); draw_arc(center, 29.0, 0.0, TAU, 20, Color("#a8ffd0"), 3.0)
		"star":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -18), center + Vector2(9, 0), center + Vector2(0, 18), center + Vector2(-9, 0)]), Color("#f5e27e")); draw_circle(center, 5.0, Color("#fff8cf"))
		"checkpoint":
			draw_line(Vector2(center.x, rect.end.y), Vector2(center.x, rect.position.y), Color("#55d68a"), 5.0); draw_colored_polygon(PackedVector2Array([Vector2(center.x + 2, rect.position.y + 4), Vector2(center.x + 30, rect.position.y + 14), Vector2(center.x + 2, rect.position.y + 25)]), Color("#a8ffd0"))

func _draw_hud() -> void:
	draw_rect(Rect2(24, 20, 610, 80), Color(0.04, 0.06, 0.16, 0.84)); draw_string(ThemeDB.fallback_font, Vector2(44, 52), "%02d  %s" % [level_index + 1, str(level["display_name"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(44, 80), "SCORE %06d    COMBO x%d    SHIELD %d/3" % [score, combo, shield_hits], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 300, 46), "%d BPM  •  %s" % [int(level["music"]["bpm"]), "BUILDER" if build_mode else ("SLOWED" if quiz_active else ("CHASE" if _chase_active() else "ON BEAT"))], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#cbbaff")); draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 300, 76), "DISTANCE %04d m" % int(player.x / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#8fa8df"))
	if quiz_streak > 0: draw_string(ThemeDB.fallback_font, Vector2(470, 52), "QUIZ STREAK x%d" % quiz_streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a8ffd0"))
	if message_time > 0.0: draw_string(ThemeDB.fallback_font, Vector2(VIEW.x / 2 - 200, 145), message, HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color("#ffffff"))
	if crash_timer > 0.0: draw_string(ThemeDB.fallback_font, Vector2(0, 188), "%s  •  TAP / SPACE TO RETRY NOW" % crash_reason, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#ffb6c9"))
	if started and not quiz_active and not build_mode and not finished: draw_string(ThemeDB.fallback_font, Vector2(34, VIEW.y - 30), "SPACE / TAP JUMP     X / TAP DASH     B BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 1.0, 0.7))

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.78)); draw_string(ThemeDB.fallback_font, Vector2(0, 68), "NEON TWICE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 54, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(0, 108), "CHOOSE YOUR BEAT", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, Color("#f5e27e"))
	for i in range(LEVEL_COUNT):
		var card: Rect2 = _level_choice_rect(i)
		var locked: bool = i > unlocked_level
		var selected: bool = i == selected_level_index
		var card_color: Color = Color("#11183e") if locked else (Color("#26336e") if selected else Color("#182450"))
		draw_rect(card, card_color); draw_rect(card, Color("#70789f") if locked else (Color("#a8ffd0") if selected else Color("#7cf5ff")), false, 4.0)
		var meta: Dictionary = campaign_catalog[i]
		draw_string(ThemeDB.fallback_font, card.position + Vector2(22, 42), "LEVEL %02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#a9b8ef"))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(22, 82), str(meta["name"]), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 44, 25, Color("#ffffff") if not locked else Color("#7f86a9"))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(22, 120), str(meta["subtitle"]), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 44, 16, Color("#cbbaff") if not locked else Color("#626987"))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(22, 182), "%d BPM" % int(meta["bpm"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#7cf5ff") if not locked else Color("#626987"))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(22, 218), str(meta["track"]).get_file(), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 44, 14, Color("#a9b8ef") if not locked else Color("#626987"))
		var best: int = int(best_scores[i])
		draw_string(ThemeDB.fallback_font, card.position + Vector2(22, 270), "BEST %06d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f5e27e") if not locked else Color("#626987"))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(22, 320), "LOCKED" if locked else ("SELECTED • PRESS SPACE" if selected else "UNLOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ff9dbc") if locked else Color("#a8ffd0"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 555), "CLICK / TAP A LEVEL TO PLAY  •  ARROWS SELECT  •  SPACE STARTS", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#ffffff")); draw_string(ThemeDB.fallback_font, Vector2(0, 598), "JUMP ON THE BEAT FOR PERFECT BONUS SCORE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 16, Color("#a9b8ef"))

func _draw_quiz() -> void:
	var feedback: bool = quiz_feedback_time > 0.0
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.03, 0.02, 0.12, 0.78)); draw_rect(Rect2(90, 24, 1100, 270), Color("#11183e")); draw_rect(Rect2(90, 24, 1100, 270), Color("#ff9dbc") if feedback else Color("#7cf5ff"), false, 4.0); draw_string(ThemeDB.fallback_font, Vector2(0, 82), "ANSWER REVIEW" if feedback else "TIMETABLE QUIZ", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#ff9dbc") if feedback else Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(0, 190), "%d × %d = ?" % [quiz_table, quiz_number], HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 64, Color("#ffffff"))
	if feedback:
		draw_string(ThemeDB.fallback_font, Vector2(0, 250), quiz_feedback_text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 21, Color("#f5e27e")); draw_string(ThemeDB.fallback_font, Vector2(0, 420), "CHECKPOINT RESTART IN %.1f" % max(0.0, quiz_feedback_time), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 25, Color("#ff9ab4")); draw_string(ThemeDB.fallback_font, Vector2(0, 485), "Read the correction, then try the beat again", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#a9b8ef"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(0, 246), "Only the answer buttons are active", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 17, Color("#a9b8ef"))
		for i in range(3):
			var rect: Rect2 = _quiz_choice_rect(i); draw_rect(rect, Color("#26336e")); draw_rect(rect, Color("#b06cff"), false, 5.0); draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 108), "%d" % quiz_choices[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 58, Color("#f5e27e"))
		draw_string(ThemeDB.fallback_font, Vector2(0, 620), "TIME LEFT %.1f" % max(0.0, quiz_time), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#ff9ab4"))

func _draw_builder() -> void:
	draw_rect(Rect2(0, 0, 300, VIEW.y), Color("#0c1230")); draw_rect(Rect2(0, 0, 300, 112), Color("#182450")); draw_string(ThemeDB.fallback_font, Vector2(24, 38), "BEAT BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(24, 72), "Click add • drag empty space to pan", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a9b8ef")); draw_string(ThemeDB.fallback_font, Vector2(24, 98), "E/I • Ctrl-Z/Y • Ctrl-C/V", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a9b8ef"))
	for i in range(PALETTE.size()):
		var y := 130.0 + i * 42.0; var selected := i == selected_palette; draw_rect(Rect2(16, y - 28, 268, 36), Color("#26336e") if selected else Color("#11183e")); draw_string(ThemeDB.fallback_font, Vector2(30, y - 4), "%d  %s" % [(i + 1) % 10, PALETTE[i].replace("_", " ").to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f5e27e") if selected else Color("#d6defc"))
	draw_string(ThemeDB.fallback_font, Vector2(330, 92), "Beat grid: click to place • Enter tests from start", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffffff"))

func _draw_finish() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.84)); draw_string(ThemeDB.fallback_font, Vector2(0, 220), "LEVEL COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 54, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(0, 295), "%s" % str(level["display_name"]), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 24, Color("#a8ffd0")); draw_string(ThemeDB.fallback_font, Vector2(0, 350), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 28, Color("#f5e27e")); draw_string(ThemeDB.fallback_font, Vector2(0, 395), "BEST COMBO x%d    QUIZZES %d" % [best_combo, quiz_points], HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, Color("#ffffff")); draw_string(ThemeDB.fallback_font, Vector2(0, 470), "PRESS SPACE TO PLAY AGAIN  •  ESC TO LEVELS", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#a9b8ef"))
