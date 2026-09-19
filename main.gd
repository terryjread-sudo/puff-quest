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
const PALETTE := ["block", "spike", "catapult", "timetable", "bounce_pad", "moving_platform", "gravity_portal", "laser_gate", "speed_ring", "star", "checkpoint"]

var level: Dictionary = {}
var objects: Array = []
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
var music_started := false
var gravity_sign := 1.0
var gravity_until := 0.0
var catapult_state: Dictionary = {}
var speed_until := 0.0

func _ready() -> void:
	rng.seed = 20260918
	_apply_level(LevelData.default_level())
	_setup_music()
	queue_redraw()

func _apply_level(data: Dictionary) -> void:
	level = LevelData.validate(data)
	objects = level["objects"]
	triggers = level["triggers"]
	consumed.clear(); triggered.clear(); catapult_state.clear()
	gravity_sign = 1.0; gravity_until = 0.0
	checkpoint_beats = [0.0]
	for object in objects:
		if object["type"] == "checkpoint": checkpoint_beats.append(float(object["beat"]))
	checkpoint_beats.sort()

func _setup_music() -> void:
	music_player = AudioStreamPlayer.new()
	var stream := load("res://assets/circuit-punk-game-menu.mp3") as AudioStreamMP3
	if stream != null:
		stream.loop = true
		music_player.stream = stream
	add_child(music_player)

func _ensure_music() -> void:
	if music_started or music_player.stream == null: return
	music_started = true; music_player.play()

func _music_beat() -> float:
	return 60.0 / float(level["music"]["bpm"])

func _beat_width() -> float:
	return RUN_SPEED * _music_beat()

func _process(delta: float) -> void:
	var dt: float = min(delta, 0.05)
	background_time += dt
	message_time = max(0.0, message_time - dt); flash = max(0.0, flash - dt)
	_update_particles(dt)
	if music_player != null: music_player.pitch_scale = 0.26 if quiz_active else 1.0
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
		velocity.x = RUN_SPEED * _speed_multiplier(); velocity.y += GRAVITY * gravity_sign * delta
		if jump_buffer > 0.0 and (grounded or coyote > 0.0):
			velocity.y = JUMP_VELOCITY * gravity_sign; jump_buffer = 0.0; coyote = 0.0; _combo_event("JUMP")
	player += velocity * delta
	if gravity_sign > 0.0 and player.y + PLAYER_SIZE.y >= FLOOR_Y: player.y = FLOOR_Y - PLAYER_SIZE.y; velocity.y = 0.0
	if gravity_sign < 0.0 and player.y <= 90.0: player.y = 90.0; velocity.y = 0.0
	for platform in objects:
		if platform["type"] != "moving_platform": continue
		var platform_rect := _object_rect(platform)
		if velocity.y >= 0.0 and Rect2(player, PLAYER_SIZE).intersects(platform_rect) and player.y + PLAYER_SIZE.y - platform_rect.position.y < 24.0:
			player.y = platform_rect.position.y - PLAYER_SIZE.y
			velocity.y = 0.0
	if player.y > VIEW.y + 160.0 or player.y < -180.0: _crash("MISSED THE PLATFORM")
	_update_objects(); _check_objects(); _check_triggers()
	for i in range(checkpoint_beats.size()):
		if player.x >= START_X + checkpoint_beats[i] * _beat_width(): checkpoint_index = i
	if player.x >= START_X + float(level["length_beats"]) * _beat_width(): _finish()
	camera_x = clamp(player.x - 250.0, 0.0, START_X + float(level["length_beats"]) * _beat_width() - VIEW.x)

func _quiz_step(delta: float) -> void:
	quiz_time -= delta; player.x += RUN_SPEED * delta * 0.26
	if quiz_time <= 0.0: _answer_quiz(-1)
	camera_x = clamp(player.x - 250.0, 0.0, START_X + float(level["length_beats"]) * _beat_width() - VIEW.x)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and started:
		if build_mode: _exit_builder()
		else: paused = not paused
		if music_player != null: music_player.stream_paused = paused or build_mode
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B and started and not quiz_active: _toggle_builder(); return
		if build_mode: _builder_key(event.keycode); return
	if build_mode:
		if event is InputEventMouseButton and event.pressed: _builder_click(event.position, event.button_index)
		return
	if event.is_action_pressed("jump"):
		if finished: _restart_run()
		elif not started: _start_run()
		elif quiz_active: _answer_quiz(0)
		else: jump_buffer = 0.12
	if event.is_action_pressed("dash"):
		if not started: _start_run()
		elif not quiz_active: _start_dash()
	if event is InputEventKey and event.pressed and not event.echo and quiz_active and event.keycode >= KEY_1 and event.keycode <= KEY_3: _answer_quiz(event.keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		if not started: _start_run()
		elif quiz_active:
			var choice := _quiz_choice_at(event.position)
			if choice >= 0: _answer_quiz(choice)
		elif event.position.y > VIEW.y * 0.68:
			if event.position.x < VIEW.x * 0.55: jump_buffer = 0.12
			else: _start_dash()
	if event is InputEventScreenTouch and event.pressed:
		if not started: _start_run()
		elif quiz_active:
			var touch_choice := _quiz_choice_at(event.position)
			if touch_choice >= 0: _answer_quiz(touch_choice)
		elif event.position.y > VIEW.y * 0.62:
			if event.position.x < VIEW.x * 0.55: jump_buffer = 0.12
			else: _start_dash()

func _start_run() -> void:
	started = true; paused = false; _ensure_music(); message = "FIND THE BEAT"; message_time = 1.5

func _restart_run() -> void:
	_apply_level(level); player = Vector2(START_X, FLOOR_Y - PLAYER_SIZE.y); velocity = Vector2.ZERO; camera_x = 0.0; run_time = 0.0; checkpoint_index = 0; combo = 0; score = 0; quiz_points = 0; finished = false; quiz_active = false; build_mode = false; paused = false; speed_until = 0.0; if music_player != null: music_player.stream_paused = false; _start_run()

func _toggle_builder() -> void:
	build_mode = not build_mode; paused = build_mode
	if music_player != null: music_player.stream_paused = build_mode
	message = "BUILDER ON" if build_mode else "RUN RESUMED"; message_time = 1.0

func _exit_builder() -> void:
	build_mode = false; paused = false
	if music_player != null: music_player.stream_paused = false
	message = "PRESS ENTER TO TEST"; message_time = 1.4

func _builder_key(key: Key) -> void:
	if key == KEY_ESCAPE or key == KEY_B: _exit_builder(); return
	if key == KEY_ENTER: _restart_run(); return
	if key == KEY_E: _export_level(); return
	if key == KEY_I: _import_level(); return
	if key == KEY_R: _apply_level(LevelData.default_level()); message = "DEFAULT LEVEL RESTORED"; message_time = 1.2; return
	if key >= KEY_1 and key <= KEY_9: selected_palette = clamp(key - KEY_1, 0, PALETTE.size() - 1)
	if key == KEY_0: selected_palette = 9

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
	if button == MOUSE_BUTTON_RIGHT: _remove_nearest(beat, lane); return
	var kind: String = PALETTE[selected_palette]
	if kind == "timetable": triggers.append({"id": "quiz-custom-%03d" % triggers.size(), "type": "quiz", "beat": beat, "table": 2, "time_limit": 10.0})
	else: objects.append({"id": "custom-%03d" % objects.size(), "type": kind, "beat": beat, "lane": lane, "properties": _default_properties(kind)})
	_sync_level()

func _default_properties(kind: String) -> Dictionary:
	match kind:
		"catapult": return {"delay_beats": 1.0, "launch_beats": 2.0}
		"bounce_pad": return {"strength": 1.0}
		"moving_platform": return {"travel_beats": 4.0, "distance_lanes": 2.0}
		"gravity_portal": return {"duration_beats": 8.0}
		"laser_gate": return {"period": 4.0, "on_beats": 2.0}
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
	for object in objects:
		var id: String = object["id"]; var kind: String = object["type"]; var x := _object_x(object)
		if consumed.has(id): continue
		if kind == "catapult" and player.x >= x and not catapult_state.has(id): catapult_state[id] = run_time + float(object["properties"].get("delay_beats", 1.0)) * _music_beat()
		if kind == "catapult" and catapult_state.has(id) and run_time >= catapult_state[id]: player.x += RUN_SPEED * _music_beat() * float(object["properties"].get("launch_beats", 2.0)); velocity.y = -180.0; consumed[id] = true; message = "CATAPULT LAUNCH"; message_time = 0.8
		if kind == "gravity_portal" and player.x >= x:
			gravity_sign = -1.0; gravity_until = run_time + float(object["properties"].get("duration_beats", 8.0)) * _music_beat(); consumed[id] = true

func _speed_multiplier() -> float:
	if run_time < speed_until: return 1.25
	return 1.0

func _check_objects() -> void:
	var body := Rect2(player, PLAYER_SIZE)
	for object in objects:
		var id: String = object["id"]; var kind: String = object["type"]
		if consumed.has(id): continue
		var rect := _object_rect(object)
		if not body.intersects(rect): continue
		match kind:
			"spike", "block":
				if dash_left > 0.0: score += 40; consumed[id] = true; _spawn_burst(rect.position + rect.size * 0.5, Color("#ff698f"), 14)
				else: _crash("HIT THE BEAT WALL")
			"laser_gate":
				var period: float = float(object["properties"].get("period", 4.0)); var on_beats: float = float(object["properties"].get("on_beats", 2.0))
				if fmod(run_time, period * _music_beat()) < on_beats * _music_beat() and dash_left <= 0.0: _crash("LASER TIMING MISS")
			"bounce_pad": velocity.y = JUMP_VELOCITY * float(object["properties"].get("strength", 1.0)); consumed[id] = true; _combo_event("BOUNCE")
			"speed_ring": score += 75; consumed[id] = true; speed_until = run_time + float(object["properties"].get("duration_beats", 4.0)) * _music_beat(); _combo_event("SPEED UP"); _spawn_burst(rect.position + rect.size * 0.5, Color("#f5e27e"), 10)
			"star": score += 75; consumed[id] = true; _combo_event("COLLECT"); _spawn_burst(rect.position + rect.size * 0.5, Color("#f5e27e"), 10)
			"checkpoint": checkpoint_index = max(checkpoint_index, checkpoint_beats.find(float(object["beat"])))

func _check_triggers() -> void:
	for trigger in triggers:
		if triggered.has(trigger["id"]): continue
		if player.x >= START_X + float(trigger["beat"]) * _beat_width(): triggered[trigger["id"]] = true; _start_quiz(trigger); return

func _start_quiz(trigger: Dictionary) -> void:
	quiz_active = true; quiz_time = 10.0; quiz_table = int(trigger.get("table", 2)); quiz_number = rng.randi_range(1, 12)
	var correct: int = quiz_number * quiz_table; quiz_choices = [correct, correct + rng.randi_range(1, 3), max(2, correct - rng.randi_range(1, 3))]; quiz_choices.shuffle(); quiz_correct_index = quiz_choices.find(correct); message = "TIME SHIFT"; message_time = 1.0

func _answer_quiz(choice: int) -> void:
	if not quiz_active: return
	quiz_active = false
	if choice == quiz_correct_index: quiz_points += 1; score += 250; _combo_event("SOLVED"); message = "CORRECT +250"
	else: combo = 0; message = "WRONG - COMBO LOST"
	message_time = 1.5; flash = 0.25

func _start_dash() -> void:
	if dash_cooldown > 0.0 or dash_left > 0.0: return
	dash_left = DASH_TIME; dash_cooldown = _music_beat() * 2.0; velocity = Vector2(DASH_SPEED, 0.0); _combo_event("DASH")

func _crash(reason: String) -> void:
	combo = 0; flash = 0.35; message = reason; message_time = 1.2; player = Vector2(START_X + checkpoint_beats[checkpoint_index] * _beat_width(), FLOOR_Y - PLAYER_SIZE.y); velocity = Vector2.ZERO; dash_left = 0.0; consumed.clear(); triggered.clear(); catapult_state.clear()
	for trigger in triggers:
		if float(trigger["beat"]) < checkpoint_beats[checkpoint_index]: triggered[trigger["id"]] = true

func _finish() -> void:
	finished = true; message = "RUN COMPLETE"; message_time = 99.0

func _is_grounded() -> bool:
	if gravity_sign < 0.0: return false
	if player.y + PLAYER_SIZE.y >= FLOOR_Y - 1.0: return true
	for platform in objects:
		if platform["type"] == "moving_platform":
			var rect := _object_rect(platform)
			if abs(player.y + PLAYER_SIZE.y - rect.position.y) < 8.0 and player.x + PLAYER_SIZE.x > rect.position.x and player.x < rect.end.x: return true
	return false
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
		"laser_gate": return Rect2(x - 10, 80, 20, FLOOR_Y - 80)
		"catapult", "bounce_pad": return Rect2(x - 32, FLOOR_Y - 28, 64, 28)
		"moving_platform": return Rect2(x - 45, y - 15, 90, 30)
		"gravity_portal": return Rect2(x - 28, FLOOR_Y - 170, 56, 170)
		"speed_ring", "star": return Rect2(x - 18, y - 18, 36, 36)
		"checkpoint": return Rect2(x - 16, FLOOR_Y - 100, 32, 100)
	return Rect2(x - 20, y - 20, 40, 40)

func _quiz_choice_at(pos: Vector2) -> int:
	for i in range(3):
		if Rect2(140 + i * 350, 360, 300, 190).has_point(pos): return i
	return -1

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i]["p"] += particles[i]["v"] * delta; particles[i]["v"] *= 0.94; particles[i]["life"] -= delta
		if particles[i]["life"] <= 0.0: particles.remove_at(i)
func _spawn_burst(origin: Vector2, color: Color, count: int) -> void:
	for i in count: particles.append({"p": origin, "v": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(40.0, 220.0), "life": rng.randf_range(0.25, 0.7), "color": color})

func _draw() -> void:
	_draw_background(); _draw_world(); _draw_hud()
	if not started: _draw_title()
	if quiz_active: _draw_quiz()
	if build_mode: _draw_builder()
	if finished: _draw_finish()
	if flash > 0.0: draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(1.0, 0.35, 0.5, flash * 0.35))

func _draw_background() -> void:
	var pulse := 0.5 + 0.5 * sin(background_time * TAU / _music_beat())
	var screen_size := get_viewport_rect().size
	var fill_size := Vector2(max(screen_size.x, VIEW.x), max(screen_size.y, VIEW.y))
	draw_rect(Rect2(Vector2.ZERO, fill_size), Color("#17143e"))
	var band_count := int(ceil(fill_size.y / 80.0))
	for band in range(band_count): draw_rect(Rect2(0, band * 80, fill_size.x, 82), Color("#21194e").lerp(Color("#583070"), min(1.0, float(band) / 9.0)))
	for x in range(-100, int(fill_size.x) + 1500, 100):
		var sx := fmod(x - camera_x * 0.15, 1500.0); draw_line(Vector2(sx, 0), Vector2(sx - 260, VIEW.y), Color(0.7, 0.45, 0.95, 0.11), 1.0)
	for y in range(80, int(fill_size.y) + 80, 80): draw_line(Vector2(0, y), Vector2(fill_size.x, y), Color(0.7, 0.45, 0.95, 0.10), 1.0)
	_draw_kawaii_bone_carnival(pulse)

func _draw_kawaii_bone_carnival(pulse: float) -> void:
	# Original pastel spooky-cute background set piece: all shapes are drawn in code.
	var drift := sin(background_time * 0.7)
	var moon := Vector2(1000.0 + drift * 34.0, 178.0 + sin(background_time * 0.45) * 12.0)
	draw_circle(moon, 108.0 + pulse * 7.0, Color(1.0, 0.78, 0.88, 0.16))
	draw_circle(moon, 82.0, Color("#ffd8ed"))
	draw_circle(moon + Vector2(24, -10), 9.0, Color("#eaaed3"))
	draw_circle(moon + Vector2(-30, 28), 6.0, Color("#eaaed3"))
	draw_circle(moon + Vector2(36, 35), 5.0, Color("#eaaed3"))

	# A giant happy bone mascot peeks over the skyline and bobs with the beat.
	var mascot := Vector2(1030.0 + sin(background_time * 0.55) * 28.0, 292.0 + pulse * 9.0)
	var jaw_open := 12.0 + pulse * 20.0
	draw_circle(mascot, 126.0, Color(0.98, 0.92, 0.83, 0.95))
	draw_circle(mascot + Vector2(-43, 18), 35.0, Color("#fff5dd"))
	draw_circle(mascot + Vector2(43, 18), 35.0, Color("#fff5dd"))
	draw_circle(mascot + Vector2(-42, -22), 22.0, Color("#34245e"))
	draw_circle(mascot + Vector2(42, -22), 22.0, Color("#34245e"))
	draw_circle(mascot + Vector2(-42, -22), 8.0 + pulse * 3.0, Color("#7cf5ff"))
	draw_circle(mascot + Vector2(42, -22), 8.0 + pulse * 3.0, Color("#7cf5ff"))
	draw_arc(mascot + Vector2(0, 15), 48.0 + jaw_open, 0.15, PI - 0.15, 20, Color("#34245e"), 8.0)
	for tooth in range(5):
		var tooth_x := mascot.x - 28.0 + tooth * 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(tooth_x, mascot.y + 35.0), Vector2(tooth_x + 8, mascot.y + 35.0), Vector2(tooth_x + 4, mascot.y + 48.0)]), Color("#fff5dd"))
	draw_circle(mascot + Vector2(-74, 36), 8.0, Color("#ff9dbc"))
	draw_circle(mascot + Vector2(74, 36), 8.0, Color("#ff9dbc"))

	# Waving bone arms make the scene feel alive without affecting the level.
	var wave := sin(background_time * 2.0) * 16.0
	_draw_bone_arm(Vector2(850, 420), Vector2(790 + wave, 300), -0.45)
	_draw_bone_arm(Vector2(1190, 430), Vector2(1235 - wave, 300), 0.45)

	# Tiny pastel ghost friends drift in a slow parade.
	for i in range(5):
		var ghost_x := fmod(120.0 + i * 250.0 + background_time * (18.0 + i * 4.0), 1500.0) - 80.0
		var ghost_y := 150.0 + i * 32.0 + sin(background_time * 1.2 + i * 1.7) * 24.0
		_draw_cute_ghost(Vector2(ghost_x, ghost_y), [Color("#b8f4ff"), Color("#e8c8ff"), Color("#ffd0e5")][i % 3], 0.62)
	# A candy-coloured stream of confetti and tiny dancing skeletons gives the
	# background the manic cartoon energy of a parade, while staying friendly.
	for i in range(7):
		var confetti_x := fmod(80.0 + i * 205.0 - camera_x * 0.28, 1500.0) - 110.0
		var confetti_y := 110.0 + fmod(background_time * (24.0 + i * 2.0) + i * 73.0, 310.0)
		var confetti_color: Color = [Color("#7cf5ff"), Color("#ff9dbc"), Color("#f5e27e"), Color("#b06cff")][i % 4]
		draw_line(Vector2(confetti_x, confetti_y), Vector2(confetti_x + 9.0, confetti_y + 12.0), Color(confetti_color, 0.65), 4.0)
	for i in range(4):
		var parade_x := fmod(180.0 + i * 340.0 - camera_x * 0.22, 1500.0) - 80.0
		var parade_y := 425.0 + sin(background_time * 2.0 + i) * 9.0
		_draw_tiny_skeleton(Vector2(parade_x, parade_y), i)

	# Beat sparkles pop around the mascot like a cartoon celebration.
	for i in range(8):
		var angle := background_time * 0.8 + i * TAU / 8.0
		var sparkle := mascot + Vector2(cos(angle), sin(angle)) * (155.0 + pulse * 18.0)
		_draw_sparkle(sparkle, 5.0 + pulse * 4.0, Color("#f5e27e"))

func _draw_bone_arm(shoulder: Vector2, hand: Vector2, tilt: float) -> void:
	draw_line(shoulder, hand, Color("#fff5dd"), 24.0)
	draw_circle(shoulder, 18.0, Color("#fff5dd"))
	draw_circle(hand, 28.0, Color("#fff5dd"))
	draw_circle(hand + Vector2(cos(tilt) * 24.0, sin(tilt) * 24.0), 11.0, Color("#fff5dd"))

func _draw_cute_ghost(pos: Vector2, tint: Color, alpha: float) -> void:
	var body := Color(tint, alpha)
	draw_circle(pos + Vector2(0, -13), 28.0, body)
	draw_rect(Rect2(pos.x - 28, pos.y - 14, 56, 31), body)
	for i in range(3): draw_circle(Vector2(pos.x - 20 + i * 20, pos.y + 18), 10.0, body)
	draw_circle(pos + Vector2(-9, -15), 5.0, Color("#34245e"))
	draw_circle(pos + Vector2(9, -15), 5.0, Color("#34245e"))
	draw_circle(pos + Vector2(0, 0), 4.0, Color("#ff9dbc"))

func _draw_tiny_skeleton(pos: Vector2, variant: int) -> void:
	var tint: Color = [Color("#fff5dd"), Color("#ffd8ed"), Color("#d7f8ff")][variant % 3]
	draw_circle(pos + Vector2(0, -20), 14.0, Color(tint, 0.72))
	draw_circle(pos + Vector2(-5, -22), 3.0, Color("#34245e"))
	draw_circle(pos + Vector2(5, -22), 3.0, Color("#34245e"))
	draw_line(pos + Vector2(0, -6), pos + Vector2(0, 24), Color(tint, 0.72), 6.0)
	draw_line(pos + Vector2(-17, 3), pos + Vector2(17, 3), Color(tint, 0.72), 5.0)
	draw_line(pos + Vector2(0, 23), pos + Vector2(-12, 39), Color(tint, 0.72), 5.0)
	draw_line(pos + Vector2(0, 23), pos + Vector2(12, 39), Color(tint, 0.72), 5.0)

func _draw_sparkle(pos: Vector2, size: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -size), pos + Vector2(size * 0.35, -size * 0.35), pos + Vector2(size, 0), pos + Vector2(size * 0.35, size * 0.35), pos + Vector2(0, size), pos + Vector2(-size * 0.35, size * 0.35), pos + Vector2(-size, 0), pos + Vector2(-size * 0.35, -size * 0.35)]), color)

func _draw_world() -> void:
	var screen_size := get_viewport_rect().size
	var fill_width: float = max(screen_size.x, VIEW.x)
	var fill_height: float = max(screen_size.y, VIEW.y)
	draw_rect(Rect2(0, FLOOR_Y, fill_width, fill_height - FLOOR_Y), Color("#151b3d"))
	for x in range(-100, int(fill_width) + 1600, 80):
		var sx := fmod(x - camera_x, 1600.0); draw_line(Vector2(sx, FLOOR_Y), Vector2(sx - 70, fill_height), Color("#28346a"), 2.0)
	for object in objects:
		if not consumed.has(object["id"]): _draw_object(object)
	for particle in particles: draw_circle(particle["p"] - Vector2(camera_x, 0), 3.0 + particle["life"] * 4.0, Color(particle["color"], particle["life"]))
	var center := player - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5; draw_set_transform(center, run_time * 2.0 if dash_left > 0.0 else 0.0, Vector2.ONE); draw_rect(Rect2(-23, -23, 46, 46), Color("#75f1ff")); draw_rect(Rect2(-16, -16, 32, 32), Color("#182450")); draw_rect(Rect2(-8, -8, 16, 16), Color("#f5e27e")); draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_object(object: Dictionary) -> void:
	var kind: String = object["type"]; var rect := _object_rect(object); rect.position.x -= camera_x; var center := rect.get_center()
	match kind:
		"spike":
			draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x, FLOOR_Y), Vector2(center.x, rect.position.y), Vector2(rect.end.x, FLOOR_Y)]), Color("#ff638c"))
			draw_line(Vector2(center.x - 7, rect.position.y + 18), Vector2(center.x + 7, rect.position.y + 30), Color("#fff0f7"), 4.0)
			draw_string(ThemeDB.fallback_font, Vector2(center.x - 28, rect.position.y - 10), "DANGER", HORIZONTAL_ALIGNMENT_CENTER, 56, 10, Color("#ffb6c9"))
		"block":
			draw_rect(rect, Color("#b06cff")); draw_rect(rect.grow(-7.0), Color("#422a81"), false, 4.0)
			draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.58), "WALL", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color("#f4d9ff"))
		"laser_gate":
			var laser_period: float = float(object["properties"].get("period", 4.0)); var laser_on: float = float(object["properties"].get("on_beats", 2.0)); var active := fmod(run_time, laser_period * _music_beat()) < laser_on * _music_beat()
			draw_circle(Vector2(center.x, rect.position.y), 18.0, Color("#ff8caa") if active else Color("#7cf5ff")); draw_circle(Vector2(center.x, rect.end.y), 18.0, Color("#ff8caa") if active else Color("#7cf5ff"))
			draw_line(Vector2(center.x, rect.position.y), Vector2(center.x, rect.end.y), Color("#ff638c") if active else Color("#7cf5ff"), 8.0)
			draw_string(ThemeDB.fallback_font, Vector2(center.x - 35, rect.position.y - 10), "ON" if active else "OFF", HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color("#ffb6c9") if active else Color("#a9f8ff"))
		"catapult":
			draw_rect(rect, Color("#f2d35e")); draw_line(rect.position + Vector2(10, 10), rect.end - Vector2(10, 10), Color("#0b102b"), 4.0); draw_circle(Vector2(center.x, rect.position.y + 4), 10.0, Color("#ff8caa")); draw_string(ThemeDB.fallback_font, Vector2(rect.position.x - 15, rect.position.y - 12), "FLING", HORIZONTAL_ALIGNMENT_CENTER, 94, 11, Color("#fff0b3"))
		"bounce_pad":
			draw_rect(rect, Color("#7cf5ff")); draw_line(Vector2(rect.position.x + 8, rect.end.y - 6), Vector2(center.x, rect.position.y + 5), Color("#0b102b"), 4.0); draw_line(Vector2(rect.end.x - 8, rect.end.y - 6), Vector2(center.x, rect.position.y + 5), Color("#0b102b"), 4.0); draw_string(ThemeDB.fallback_font, Vector2(rect.position.x - 10, rect.position.y - 12), "BOUNCE", HORIZONTAL_ALIGNMENT_CENTER, 84, 11, Color("#cfffff"))
		"moving_platform":
			draw_rect(rect, Color("#8fa8df")); draw_line(Vector2(rect.position.x - 18, center.y), Vector2(rect.position.x - 3, center.y), Color("#f5e27e"), 3.0); draw_line(Vector2(rect.end.x + 3, center.y), Vector2(rect.end.x + 18, center.y), Color("#f5e27e"), 3.0); draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y - 10), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, Color("#eef3ff"))
		"gravity_portal":
			draw_circle(center, 35.0 + sin(background_time * 4.0) * 3.0, Color(0.65, 0.35, 1.0, 0.18)); draw_arc(center, 35.0, 0.0, TAU, 24, Color("#ff9ab4"), 7.0); draw_string(ThemeDB.fallback_font, Vector2(center.x - 45, center.y + 5), "FLIP", HORIZONTAL_ALIGNMENT_CENTER, 90, 14, Color("#ffe0ec"))
		"speed_ring":
			draw_arc(center, 18.0, 0.0, TAU, 20, Color("#f5e27e"), 6.0); draw_arc(center, 29.0, 0.0, TAU, 20, Color("#ffca67"), 3.0); draw_string(ThemeDB.fallback_font, Vector2(center.x - 35, center.y + 48), "SPEED", HORIZONTAL_ALIGNMENT_CENTER, 70, 11, Color("#fff0b3"))
		"star":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -18), center + Vector2(9, 0), center + Vector2(0, 18), center + Vector2(-9, 0)]), Color("#f5e27e")); draw_circle(center, 5.0, Color("#fff8cf"))
		"checkpoint":
			draw_line(Vector2(center.x, rect.end.y), Vector2(center.x, rect.position.y), Color("#7cf5ff"), 5.0); draw_colored_polygon(PackedVector2Array([Vector2(center.x + 2, rect.position.y + 4), Vector2(center.x + 30, rect.position.y + 14), Vector2(center.x + 2, rect.position.y + 25)]), Color("#ff9dbc")); draw_string(ThemeDB.fallback_font, Vector2(center.x - 42, rect.position.y - 10), "SAVE", HORIZONTAL_ALIGNMENT_CENTER, 84, 11, Color("#cfffff"))

func _draw_hud() -> void:
	draw_rect(Rect2(24, 20, 420, 80), Color(0.04, 0.06, 0.16, 0.84)); draw_string(ThemeDB.fallback_font, Vector2(44, 52), "NEON TWICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(44, 80), "SCORE %06d    COMBO x%d" % [score, combo], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 300, 46), "%d BPM  •  %s" % [int(level["music"]["bpm"]), "BUILDER" if build_mode else ("SLOWED" if quiz_active else "ON BEAT")], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#cbbaff")); draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 300, 76), "DISTANCE %04d m" % int(player.x / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#8fa8df"))
	if message_time > 0.0: draw_string(ThemeDB.fallback_font, Vector2(VIEW.x / 2 - 200, 145), message, HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color("#ffffff"))
	if started and not quiz_active and not build_mode and not finished: draw_string(ThemeDB.fallback_font, Vector2(34, VIEW.y - 30), "SPACE / TAP JUMP     X / TAP DASH     B BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 1.0, 0.7))

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.78)); draw_string(ThemeDB.fallback_font, Vector2(0, 245), "NEON TWICE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 64, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(0, 300), "JUMP. DASH. BUILD. SOLVE THE BEAT.", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#f5e27e")); draw_string(ThemeDB.fallback_font, Vector2(0, 370), "PRESS SPACE / A BUTTON / TAP TO START", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, Color("#ffffff")); draw_string(ThemeDB.fallback_font, Vector2(0, 430), "B opens the beat builder • E exports • I imports", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 16, Color("#a9b8ef"))

func _draw_quiz() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.03, 0.02, 0.12, 0.72)); draw_rect(Rect2(90, 24, 1100, 270), Color("#11183e")); draw_rect(Rect2(90, 24, 1100, 270), Color("#7cf5ff"), false, 4.0); draw_string(ThemeDB.fallback_font, Vector2(0, 82), "TIMETABLE QUIZ", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(0, 190), "%d × %d = ?" % [quiz_table, quiz_number], HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 64, Color("#ffffff")); draw_string(ThemeDB.fallback_font, Vector2(0, 246), "Solve the beat before the timer runs out", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 17, Color("#a9b8ef"))
	for i in range(3):
		var rect := Rect2(140.0 + i * 350.0, 360.0, 300.0, 190.0); draw_rect(rect, Color("#26336e")); draw_rect(rect, Color("#b06cff"), false, 5.0); draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 125), "%d" % quiz_choices[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 58, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 620), "TIME LEFT %.1f" % max(0.0, quiz_time), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#ff9ab4"))

func _draw_builder() -> void:
	draw_rect(Rect2(0, 0, 300, VIEW.y), Color("#0c1230")); draw_rect(Rect2(0, 0, 300, 112), Color("#182450")); draw_string(ThemeDB.fallback_font, Vector2(24, 38), "BEAT BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(24, 72), "Click place • right-click delete", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a9b8ef")); draw_string(ThemeDB.fallback_font, Vector2(24, 98), "E export • I import • Enter test", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a9b8ef"))
	for i in range(PALETTE.size()):
		var y := 130.0 + i * 42.0; var selected := i == selected_palette; draw_rect(Rect2(16, y - 28, 268, 36), Color("#26336e") if selected else Color("#11183e")); draw_string(ThemeDB.fallback_font, Vector2(30, y - 4), "%d  %s" % [(i + 1) % 10, PALETTE[i].replace("_", " ").to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f5e27e") if selected else Color("#d6defc"))
	draw_string(ThemeDB.fallback_font, Vector2(330, 92), "Beat grid: click to place • Enter tests from start", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffffff"))

func _draw_finish() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.84)); draw_string(ThemeDB.fallback_font, Vector2(0, 245), "RUN COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 54, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(0, 320), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 28, Color("#f5e27e")); draw_string(ThemeDB.fallback_font, Vector2(0, 365), "BEST COMBO x%d    QUIZZES %d" % [best_combo, quiz_points], HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, Color("#ffffff")); draw_string(ThemeDB.fallback_font, Vector2(0, 450), "PRESS SPACE TO RUN AGAIN", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#a9b8ef"))
