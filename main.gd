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
const PALETTE := ["block", "spike", "saw", "catapult", "timetable", "bounce_pad", "platform", "moving_platform", "gravity_portal", "speed_ring", "star", "checkpoint"]
const LEVEL_COUNT := 3
const BEAT_FLASH_STRENGTH := 0.055
const INTRO_CLEAR_SECONDS := 6.0
const SLAM_INTERVAL_BEATS := 8.0
const AUDIO_RESYNC_SECONDS := 0.28
const SHOP_BUTTON_SIZE := Vector2(190.0, 54.0)
const SKINS := [
	{"id": "classic", "name": "CLASSIC CYAN", "cost": 0, "body": "#75f1ff", "core": "#f5e27e", "trail": "#7cf5ff", "shield": "#a8ffd0", "style": "spark", "animated": false},
	{"id": "bubblegum", "name": "BUBBLEGUM PINK", "cost": 25, "body": "#ff9dbc", "core": "#fff1a8", "trail": "#ff9dbc", "shield": "#ffd0e5", "style": "heart", "animated": false},
	{"id": "lime", "name": "LIME POP", "cost": 60, "body": "#55d68a", "core": "#f5e27e", "trail": "#a8ffd0", "shield": "#55d68a", "style": "leaf", "animated": false},
	{"id": "violet", "name": "VIOLET COMET", "cost": 120, "body": "#b06cff", "core": "#a8ffd0", "trail": "#d7b5ff", "shield": "#b06cff", "style": "comet", "animated": false},
	{"id": "prism", "name": "PRISM PULSE", "cost": 220, "body": "#7cf5ff", "core": "#ffffff", "trail": "#ffffff", "shield": "#ffffff", "style": "prism", "animated": true}
]

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
var diamonds := 0
var owned_skins: Array[String] = ["classic"]
var equipped_skin := "classic"
var shop_open := false
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
var selected_times_table := 2
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
var run_diamonds_earned := 0
var run_stars_collected := 0
var run_perfect_jumps := 0
var run_good_jumps := 0
var run_jump_attempts := 0
var run_hits := 0
var run_dashes := 0
var run_best_combo := 0
var checkpoint_beats: Array = [0.0]
var checkpoint_index := 0
var particles: Array = []
var trail_particles: Array = []
var flash := 0.0
var message := ""
var message_time := 0.0
var selected_palette := 0
var rng := RandomNumberGenerator.new()
var music_player: AudioStreamPlayer
var ghost_woosh_player: AudioStreamPlayer
var slime_voice_player: AudioStreamPlayer
var slime_attack_player: AudioStreamPlayer
var skeleton_sprite: Texture2D
var ghost_float_sprite: Texture2D
var ghost_float_left_sprite: Texture2D
var ghost_attack_sprite: Texture2D
var ghost_idle_sprite: Texture2D
var ghost_death_sprite: Texture2D
var zombie_walk_sprite: Texture2D
var zombie_idle_sprite: Texture2D
var zombie_attack_sprite: Texture2D
var zombie_death_sprite: Texture2D
var music_started := false
var gravity_sign := 1.0
var gravity_until := 0.0
var catapult_state: Dictionary = {}
var catapult_boost_left := 0.0
var speed_until := 0.0
var speed_boost_multiplier := 1.0
var crash_timer := 0.0
var checkpoint_flash := 0.0
var crash_reason := ""
var chase_started := false
var chase_flash := 0.0
var intro_time_left := 0.0
var slam_next_beat := -1.0
var slam_offset := 0.0
var slam_velocity := 0.0
var slam_timer := 0.0
var slam_flash := 0.0
var ghost_attack_timer := 0.0
var ghost_attack_elapsed := 0.0
var ghost_attack_next_beat := -1.0
var ghost_attack_phase_started := false
var ghost_attack_resolved := false
var ghost_attack_dodged := false
var ghost_wave_active := false
var ghost_wave_x := -1.0
var ghost_wave_previous_x := -1.0
var ghost_wave_offsets: Dictionary = {}
var ghost_final_started := false
var ghost_final_timer := 0.0
var ghost_final_resolved := false
var ghost_defeated_pending := false
var ghost_end_death_started := false
var ghost_death_timer := 0.0
var slime_walk_time := 0.0
var slime_attack_timer := 0.0
var slime_attack_elapsed := 0.0
var slime_attack_resolved := false
var slime_attack_next_beat := -1.0
var slime_attack_phase_started := false
var slime_attack_visible := true
var slime_attack_cooldown := 0.0
var slime_end_death_started := false
var slime_death_timer := 0.0
var music_last_position := 0.0
var music_expected_playing := false
var audio_resync_time := 0.0
var audio_resync_position := 0.0
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
	ghost_float_sprite = load("res://assets/ghost-float-spritesheet.png") as Texture2D
	ghost_float_left_sprite = load("res://assets/ghost-float-left-spritesheet.png") as Texture2D
	ghost_attack_sprite = load("res://assets/ghost-attack-spritesheet.png") as Texture2D
	ghost_idle_sprite = load("res://assets/ghost-idle3-spritesheet.png") as Texture2D
	ghost_death_sprite = load("res://assets/ghost-death-spritesheet.png") as Texture2D
	zombie_walk_sprite = load("res://assets/zombievillager-walk-spritesheet.png") as Texture2D
	zombie_idle_sprite = load("res://assets/zombievillager-idle-spritesheet.png") as Texture2D
	zombie_attack_sprite = load("res://assets/zombievillager-attack-spritesheet.png") as Texture2D
	zombie_death_sprite = load("res://assets/zombievillager-death-spritesheet.png") as Texture2D
	ghost_woosh_player = AudioStreamPlayer.new()
	ghost_woosh_player.stream = load("res://assets/air_move.wav") as AudioStream
	ghost_woosh_player.volume_db = -3.0
	add_child(ghost_woosh_player)
	slime_voice_player = AudioStreamPlayer.new()
	slime_voice_player.stream = load("res://assets/slime-chase-voice.mp3") as AudioStream
	slime_voice_player.volume_db = -10.0
	slime_voice_player.max_polyphony = 1
	add_child(slime_voice_player)
	slime_attack_player = AudioStreamPlayer.new()
	slime_attack_player.stream = load("res://assets/slime-attack.wav") as AudioStream
	slime_attack_player.volume_db = -4.0
	add_child(slime_attack_player)
	queue_redraw()

func _apply_level(data: Dictionary) -> void:
	level = LevelData.validate(data)
	level_index = int(level.get("level_index", 0))
	objects = level["objects"]
	triggers = level["triggers"]
	runtime_objects.clear()
	consumed.clear(); triggered.clear(); catapult_state.clear()
	gravity_sign = 1.0; gravity_until = 0.0; speed_boost_multiplier = 1.0
	chase_started = false; chase_flash = 0.0; slam_next_beat = -1.0; slam_offset = 0.0; slam_velocity = 0.0; slam_timer = 0.0; slam_flash = 0.0
	ghost_attack_timer = 0.0; ghost_attack_elapsed = 0.0; ghost_attack_next_beat = -1.0; ghost_attack_phase_started = false; ghost_attack_resolved = false; ghost_attack_dodged = false; ghost_wave_active = false; ghost_wave_x = -1.0; ghost_wave_previous_x = -1.0; ghost_wave_offsets.clear(); ghost_final_started = false; ghost_final_timer = 0.0; ghost_final_resolved = false; ghost_defeated_pending = false; ghost_end_death_started = false; ghost_death_timer = 0.0
	slime_walk_time = 0.0; slime_attack_timer = 0.0; slime_attack_elapsed = 0.0; slime_attack_resolved = false; slime_attack_next_beat = -1.0; slime_attack_phase_started = false; slime_attack_visible = true; slime_attack_cooldown = 0.0; slime_end_death_started = false; slime_death_timer = 0.0
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
	music_last_position = 0.0
	music_expected_playing = false
	music_player.stream_paused = false

func _ensure_music() -> void:
	if music_player == null or music_player.stream == null: return
	music_expected_playing = true
	if not music_player.playing: music_player.play(music_last_position)
	music_player.stream_paused = false
	music_started = true

func _resume_music(position: float = -1.0) -> void:
	if music_player == null or music_player.stream == null: return
	if position >= 0.0: music_last_position = position
	music_expected_playing = true
	audio_resync_time = 0.0
	music_player.stream_paused = false
	music_player.play(music_last_position)
	music_started = true

func _maintain_music() -> void:
	if music_player == null or music_player.stream == null or not started or paused or build_mode or not music_expected_playing: return
	if music_player.playing and not music_player.stream_paused:
		music_last_position = music_player.get_playback_position()
		return
	if audio_resync_time <= 0.0:
		audio_resync_position = music_last_position
		audio_resync_time = AUDIO_RESYNC_SECONDS

func _finish_audio_resync() -> void:
	_resume_music(audio_resync_position)

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
	slam_timer = max(0.0, slam_timer - dt)
	slam_flash = max(0.0, slam_flash - dt)
	ghost_death_timer = max(0.0, ghost_death_timer - dt)
	slime_death_timer = max(0.0, slime_death_timer - dt)
	slime_attack_cooldown = max(0.0, slime_attack_cooldown - dt)
	slime_walk_time += dt
	if slam_offset != 0.0 or slam_velocity != 0.0:
		slam_velocity += GRAVITY * dt
		slam_offset += slam_velocity * dt
		if slam_offset >= 0.0:
			slam_offset = 0.0; slam_velocity = 0.0
	_update_particles(dt)
	_update_player_trail()
	if music_player != null: music_player.pitch_scale = 0.26 if quiz_active else _pace_multiplier()
	_maintain_music()
	if audio_resync_time > 0.0:
		audio_resync_time = max(0.0, audio_resync_time - dt)
		if audio_resync_time <= 0.0: _finish_audio_resync()
		queue_redraw(); return
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
	if ghost_end_death_started or slime_end_death_started:
		velocity = Vector2.ZERO
		if (ghost_end_death_started and ghost_death_timer <= 0.0) or (slime_end_death_started and slime_death_timer <= 0.0): _finish()
		return
	var in_intro: bool = intro_time_left > 0.0
	intro_time_left = max(0.0, intro_time_left - delta)
	if in_intro:
		# The tutorial is a real level prelude: keep the cube at the start line so
		# the first obstacles are still approaching when normal play begins.
		player = Vector2(START_X, FLOOR_Y - PLAYER_SIZE.y)
		velocity = Vector2.ZERO; jump_buffer = 0.0; dash_left = 0.0; dash_cooldown = 0.0; camera_x = 0.0
		if intro_time_left <= 0.0:
			run_time = 0.0; _resume_music(0.0); message = "%s • FIND THE BEAT" % str(level["display_name"]); message_time = 1.0
		return
	if slam_next_beat >= 0.0 and player.x >= START_X + slam_next_beat * _beat_width():
		_trigger_ground_slam()
		slam_next_beat += SLAM_INTERVAL_BEATS
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
		if platform["type"] != "moving_platform" and platform["type"] != "platform": continue
		var platform_rect := _object_rect(platform)
		if velocity.y >= 0.0 and Rect2(player, PLAYER_SIZE).intersects(platform_rect) and player.y + PLAYER_SIZE.y - platform_rect.position.y < 24.0:
			player.y = platform_rect.position.y - PLAYER_SIZE.y
			velocity.y = 0.0
	if not grounded and _is_grounded(): _spawn_skin_burst(player + PLAYER_SIZE * 0.5, 7)
	if player.y > VIEW.y + 160.0 or player.y < -180.0:
		_crash("MISSED THE PLATFORM")
		return
	if _chase_active() and not chase_started: _start_chase()
	_update_ghost_encounter(delta)
	_update_zombie_encounter(delta)
	_update_objects()
	if intro_time_left <= 0.0:
		_check_objects(); _check_triggers()
	if crash_timer > 0.0: return
	for i in range(checkpoint_beats.size()):
		if player.x >= START_X + checkpoint_beats[i] * _beat_width(): checkpoint_index = i
	if player.x >= START_X + float(level["length_beats"]) * _beat_width():
		if str(level.get("theme", "")) == "zombie" and not slime_end_death_started:
			slime_end_death_started = true; slime_death_timer = 1.7; message = "ZOMBIE DEFEATED"; message_time = 1.7
		elif ghost_defeated_pending and not ghost_end_death_started:
			ghost_end_death_started = true; ghost_death_timer = 1.25; message = "FINAL STRIKE"; message_time = 1.25
		elif not ghost_end_death_started: _finish()
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
	if finished:
		if event is InputEventMouseButton and event.pressed and _finish_menu_hit(event.position):
			_return_to_menu(); return
		if event is InputEventScreenTouch and event.pressed and _finish_menu_hit(event.position):
			_return_to_menu(); return
	if event.is_action_pressed("ui_cancel") and started:
		if finished: _return_to_menu()
		elif build_mode: _exit_builder()
		else: paused = not paused
		if paused or build_mode:
			music_expected_playing = false
			if music_player != null: music_player.stream_paused = true
		else: _resume_music()
		return
	if not started and shop_open:
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_S):
			shop_open = false; message = "SELECT A LEVEL"; message_time = 0.8; return
		if event is InputEventMouseButton and event.pressed:
			if _shop_button_hit(event.position): shop_open = false; return
			_shop_click(event.position); return
		if event is InputEventScreenTouch and event.pressed:
			if _shop_button_hit(event.position): shop_open = false; return
			_shop_click(event.position); return
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not started and event.keycode == KEY_S:
			shop_open = true; return
		if not started and event.keycode == KEY_MINUS:
			selected_times_table = max(2, selected_times_table - 1); _save_progress(); return
		if not started and event.keycode == KEY_EQUAL:
			selected_times_table = min(12, selected_times_table + 1); _save_progress(); return
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
			if drag_object_index != -1: _builder_drag(event.position)
			elif pan_dragging: _builder_pan(event.position.x)
		if event is InputEventMouseButton and event.pressed: _builder_click(event.position, event.button_index)
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _builder_release()
		if event is InputEventScreenDrag:
			if drag_object_index != -1: _builder_drag(event.position)
			elif pan_dragging: _builder_pan(event.position.x)
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
			if _shop_button_hit(event.position): shop_open = true; return
			if _times_table_minus_rect().has_point(event.position): selected_times_table = max(2, selected_times_table - 1); _save_progress(); return
			if _times_table_plus_rect().has_point(event.position): selected_times_table = min(12, selected_times_table + 1); _save_progress(); return
			var level_choice: int = _level_choice_at(event.position)
			if level_choice >= 0: _choose_level(level_choice)
			else: _start_run()
		elif _touch_jump_rect().has_point(event.position): jump_buffer = 0.12
		elif _touch_dash_rect().has_point(event.position): _start_dash()
	if event is InputEventScreenTouch and event.pressed:
		if not started:
			if _shop_button_hit(event.position): shop_open = true; return
			if _times_table_minus_rect().has_point(event.position): selected_times_table = max(2, selected_times_table - 1); _save_progress(); return
			if _times_table_plus_rect().has_point(event.position): selected_times_table = min(12, selected_times_table + 1); _save_progress(); return
			var level_touch_choice: int = _level_choice_at(event.position)
			if level_touch_choice >= 0: _choose_level(level_touch_choice)
			else: _start_run()
		elif _touch_jump_rect().has_point(event.position): jump_buffer = 0.12
		elif _touch_dash_rect().has_point(event.position): _start_dash()

func _start_run() -> void:
	if not started:
		if selected_level_index != level_index:
			_apply_level(LevelData.campaign_level(selected_level_index)); player = Vector2(START_X, FLOOR_Y - PLAYER_SIZE.y); velocity = Vector2.ZERO; camera_x = 0.0; run_time = 0.0; checkpoint_index = 0
		shield_hits = 3; invulnerability = 0.0; score = 0; combo = 0; quiz_points = 0; quiz_streak = 0; _reset_run_stats(); intro_time_left = INTRO_CLEAR_SECONDS
	started = true; paused = false; _ensure_music(); message = "%s • FIND THE BEAT" % str(level["display_name"]); message_time = 1.5

func _reset_run_stats() -> void:
	run_diamonds_earned = 0; run_stars_collected = 0; run_perfect_jumps = 0; run_good_jumps = 0; run_jump_attempts = 0; run_hits = 0; run_dashes = 0; run_best_combo = 0; trail_particles.clear()

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
	started = false; finished = false; paused = false; build_mode = false; quiz_active = false; quiz_feedback_time = 0.0; crash_timer = 0.0; camera_x = 0.0; run_time = 0.0; shop_open = false
	music_expected_playing = false
	if music_player != null: music_player.stop()
	_apply_level(LevelData.campaign_level(selected_level_index))
	message = "SELECT A LEVEL"; message_time = 1.0

func _load_progress() -> void:
	unlocked_level = 0; best_scores = [0, 0, 0]; diamonds = 0; owned_skins = ["classic"]; equipped_skin = "classic"
	if not OS.has_feature("web"): return
	var raw: Variant = JavaScriptBridge.eval("localStorage.getItem('neon_twice_progress') || ''")
	if not raw is String or str(raw).is_empty(): return
	var parsed: Variant = JSON.parse_string(str(raw))
	if not parsed is Dictionary: return
	unlocked_level = clampi(int(parsed.get("unlocked_level", 0)), 0, LEVEL_COUNT - 1)
	var saved_scores: Variant = parsed.get("best_scores", [])
	if saved_scores is Array:
		for i in range(mini(LEVEL_COUNT, saved_scores.size())): best_scores[i] = int(saved_scores[i])
	diamonds = maxi(0, int(parsed.get("diamonds", 0)))
	var saved_skins: Variant = parsed.get("owned_skins", ["classic"])
	if saved_skins is Array:
		owned_skins.clear()
		for skin_id in saved_skins:
			if _skin_by_id(str(skin_id)).is_empty() == false and not owned_skins.has(str(skin_id)): owned_skins.append(str(skin_id))
	if not owned_skins.has("classic"): owned_skins.push_front("classic")
	var saved_equipped := str(parsed.get("equipped_skin", "classic"))
	equipped_skin = saved_equipped if owned_skins.has(saved_equipped) else "classic"
	selected_times_table = clampi(int(parsed.get("times_table", 2)), 2, 12)

func _save_progress() -> void:
	if not OS.has_feature("web"): return
	var payload: String = JSON.stringify({"unlocked_level": unlocked_level, "best_scores": best_scores, "diamonds": diamonds, "owned_skins": owned_skins, "equipped_skin": equipped_skin, "times_table": selected_times_table})
	JavaScriptBridge.eval("localStorage.setItem('neon_twice_progress', %s)" % JSON.stringify(payload))

func _skin_by_id(skin_id: String) -> Dictionary:
	for skin in SKINS:
		if str(skin["id"]) == skin_id: return skin
	return {}

func _current_skin() -> Dictionary:
	var skin := _skin_by_id(equipped_skin)
	return skin if not skin.is_empty() else _skin_by_id("classic")

func _shop_card_rect(index: int) -> Rect2:
	return Rect2(55.0 + (index % 3) * 400.0, 150.0 + int(index / 3) * 230.0, 370.0, 200.0)

func _shop_button_rect() -> Rect2:
	var screen_size := get_viewport_rect().size
	return Rect2(max(20.0, screen_size.x - SHOP_BUTTON_SIZE.x - 55.0), 28.0, SHOP_BUTTON_SIZE.x, SHOP_BUTTON_SIZE.y)

func _shop_button_hit(pos: Vector2) -> bool:
	var screen_rect := _shop_button_rect()
	var logical_rect := Rect2(VIEW.x - SHOP_BUTTON_SIZE.x - 55.0, 28.0, SHOP_BUTTON_SIZE.x, SHOP_BUTTON_SIZE.y)
	return screen_rect.grow(16.0).has_point(pos) or logical_rect.grow(16.0).has_point(pos)

func _times_table_minus_rect() -> Rect2:
	return Rect2(420.0, 108.0, 56.0, 48.0)

func _times_table_plus_rect() -> Rect2:
	return Rect2(804.0, 108.0, 56.0, 48.0)

func _finish_menu_rect() -> Rect2:
	return Rect2((VIEW.x - 320.0) * 0.5, 535.0, 320.0, 60.0)

func _finish_menu_hit(pos: Vector2) -> bool:
	var logical_rect := _finish_menu_rect()
	var screen_size := get_viewport_rect().size
	var screen_rect := Rect2((screen_size.x - 320.0) * 0.5, max(20.0, screen_size.y - 74.0), 320.0, 60.0)
	return logical_rect.grow(16.0).has_point(pos) or screen_rect.grow(16.0).has_point(pos)

func _touch_jump_rect() -> Rect2:
	var screen_size := get_viewport_rect().size
	return Rect2(0.0, screen_size.y * 0.62, screen_size.x * 0.55, screen_size.y * 0.38)

func _touch_dash_rect() -> Rect2:
	var screen_size := get_viewport_rect().size
	return Rect2(screen_size.x * 0.55, screen_size.y * 0.62, screen_size.x * 0.45, screen_size.y * 0.38)

func _shop_click(pos: Vector2) -> void:
	for i in range(SKINS.size()):
		if not _shop_card_rect(i).has_point(pos): continue
		var skin: Dictionary = SKINS[i]
		var skin_id := str(skin["id"])
		if owned_skins.has(skin_id):
			equipped_skin = skin_id; _save_progress(); message = "%s EQUIPPED" % str(skin["name"]); message_time = 1.0
		elif diamonds >= int(skin["cost"]):
			diamonds -= int(skin["cost"]); owned_skins.append(skin_id); equipped_skin = skin_id; _save_progress(); message = "%s UNLOCKED" % str(skin["name"]); message_time = 1.2
		else:
			message = "NEED %d MORE DIAMONDS" % (int(skin["cost"]) - diamonds); message_time = 1.2
		return

func _restart_run() -> void:
	_apply_level(level); player = Vector2(START_X, FLOOR_Y - PLAYER_SIZE.y); velocity = Vector2.ZERO; camera_x = 0.0; run_time = 0.0; checkpoint_index = 0; combo = 0; score = 0; quiz_points = 0; quiz_streak = 0; shield_hits = 3; invulnerability = 0.0; crash_timer = 0.0; checkpoint_flash = 0.0; finished = false; quiz_active = false; quiz_feedback_time = 0.0; quiz_snapshot.clear(); build_mode = false; paused = false; speed_until = 0.0; catapult_boost_left = 0.0; runtime_objects.clear(); _reset_run_stats(); intro_time_left = INTRO_CLEAR_SECONDS; slam_next_beat = -1.0; slam_offset = 0.0; slam_velocity = 0.0; slam_timer = 0.0; _resume_music(); _start_run()

func _toggle_builder() -> void:
	build_mode = not build_mode; paused = build_mode
	if build_mode: _reset_edit_history()
	music_expected_playing = not build_mode
	if music_player != null: music_player.stream_paused = build_mode
	message = "BUILDER ON" if build_mode else "RUN RESUMED"; message_time = 1.0

func _exit_builder() -> void:
	build_mode = false; paused = false
	_resume_music()
	message = "PRESS ENTER TO TEST"; message_time = 1.4

func _builder_key(key: Key) -> void:
	if key == KEY_ESCAPE or key == KEY_B: _exit_builder(); return
	if key == KEY_ENTER: _restart_run(); return
	if key == KEY_T: _test_from_builder_position(); return
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

func _builder_player_rect() -> Rect2:
	return Rect2(Vector2(player.x - camera_x, player.y), PLAYER_SIZE)

func _test_from_builder_position() -> void:
	if not build_mode: return
	build_mode = false; paused = false; started = true; finished = false; quiz_active = false; quiz_feedback_time = 0.0; intro_time_left = 0.0
	run_time = max(0.0, (player.x - START_X) / RUN_SPEED)
	velocity = Vector2.ZERO; dash_left = 0.0; crash_timer = 0.0; _ensure_music()
	message = "TESTING FROM CUBE POSITION"; message_time = 1.2

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
	if drag_object_index == -2:
		player.x = max(START_X, camera_x + pos.x - PLAYER_SIZE.x * 0.5)
		player.y = clamp(pos.y - PLAYER_SIZE.y * 0.5, 90.0, FLOOR_Y - PLAYER_SIZE.y)
		velocity = Vector2.ZERO
		return
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
	if drag_object_index == -2:
		message = "CUBE TEST POSITION SET • PRESS T TO TEST"; message_time = 1.2
		drag_object_index = -1
		pan_dragging = false; pan_moved = false
		return
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
		if pos.x < 145.0: _export_level()
		elif pos.x < 300.0: _import_level()
		elif pos.x >= 1000.0: _test_from_builder_position()
		return
	var beat: float = max(0.0, round((camera_x + pos.x - START_X) / _beat_width() * 4.0) / 4.0)
	var lane: float = clamp(round((FLOOR_Y - pos.y) / LANE_HEIGHT * 2.0) / 2.0, -1.0, 3.0)
	if button == MOUSE_BUTTON_RIGHT: _remove_nearest(beat, lane); _record_edit(); return
	if button == MOUSE_BUTTON_MIDDLE:
		selected_object_index = _object_index_at(pos); _copy_selected(); return
	if button == MOUSE_BUTTON_LEFT:
		if _builder_player_rect().grow(18.0).has_point(pos):
			drag_object_index = -2
			return
		selected_object_index = _object_index_at(pos)
		if selected_object_index >= 0:
			drag_object_index = selected_object_index
			return
		pan_dragging = true; pan_last_x = pos.x; pan_moved = false; pending_place_pos = pos

func _default_properties(kind: String) -> Dictionary:
	match kind:
		"saw": return {"radius": 30.0, "spin_speed": 4.0}
		"catapult": return {"delay_beats": 1.0, "launch_beats": 2.0}
		"bounce_pad": return {"strength": 1.0}
		"moving_platform": return {"travel_beats": 4.0, "distance_lanes": 2.0}
		"platform": return {"width": 2.0, "height": 0.25}
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
		if kind == "gravity_portal" and player.x >= x:
			gravity_sign = -1.0; gravity_until = run_time + float(object["properties"].get("duration_beats", 8.0)) * _music_beat(); consumed[id] = true

func _speed_multiplier() -> float:
	if run_time < speed_until: return speed_boost_multiplier
	return 1.0

func _chase_active() -> bool:
	var chase_beat: float = float(level.get("chase_beat", -1.0))
	return started and chase_beat >= 0.0 and player.x >= START_X + chase_beat * _beat_width()

func _start_chase() -> void:
	if str(level.get("theme", "")) == "metro":
		_start_ghost_chase()
		return
	if str(level.get("theme", "")) == "zombie":
		_start_slime_chase()
		return
	chase_started = true; chase_flash = 1.2; message = "THE CARNIVAL IS CHASING YOU"; message_time = 1.5
	var chase_beat: float = float(level.get("chase_beat", 92.0))
	slam_next_beat = chase_beat + SLAM_INTERVAL_BEATS

func _start_ghost_chase() -> void:
	chase_started = true; chase_flash = 1.2; ghost_attack_next_beat = -1.0; ghost_attack_phase_started = false; ghost_attack_timer = 0.0; ghost_attack_elapsed = 0.0; ghost_attack_resolved = false; ghost_wave_active = false; ghost_wave_x = -1.0; ghost_wave_previous_x = -1.0; ghost_wave_offsets.clear(); ghost_final_started = false; ghost_final_timer = 0.0; ghost_final_resolved = false; ghost_death_timer = 0.0
	message = "A GHOST IS HUNTING YOU"; message_time = 1.5

func _start_slime_chase() -> void:
	chase_started = true; chase_flash = 1.2; slime_attack_next_beat = float(level.get("length_beats", 210.0)) * 0.5 + 8.0; slime_attack_phase_started = false; slime_attack_timer = 0.0; slime_attack_elapsed = 0.0; slime_attack_visible = true; slime_attack_cooldown = 0.0; slime_end_death_started = false; slime_death_timer = 0.0
	if slime_voice_player != null and slime_voice_player.stream != null:
		if slime_voice_player.stream is AudioStreamMP3: (slime_voice_player.stream as AudioStreamMP3).loop = true
		slime_voice_player.play()
	message = "A ZOMBIE VILLAGER IS AFTER YOU"; message_time = 1.5

func _update_zombie_encounter(delta: float) -> void:
	if str(level.get("theme", "")) != "zombie" or not chase_started: return
	if slime_voice_player != null and slime_voice_player.stream != null and not slime_voice_player.playing and not slime_end_death_started:
		slime_voice_player.play()
	if slime_attack_timer > 0.0:
		slime_attack_timer -= delta; slime_attack_elapsed += delta
		if slime_attack_elapsed > 0.42 and slime_attack_elapsed < 0.70 and not slime_attack_resolved:
			slime_attack_resolved = true
			# Platforms are the intended escape route: a player above the floor is safe.
			if player.y + PLAYER_SIZE.y > FLOOR_Y - 92.0: _take_hit("ZOMBIE STRIKE")
		if slime_attack_timer <= 0.0:
			slime_attack_visible = false; slime_attack_cooldown = _music_beat() * 5.0
		return
	if slime_attack_cooldown > 0.0:
		return
	var attack_start_beat := float(level.get("length_beats", 210.0)) * 0.5
	if not slime_attack_phase_started and player.x >= START_X + attack_start_beat * _beat_width():
		slime_attack_phase_started = true; slime_attack_next_beat = attack_start_beat + 8.0; slime_attack_visible = true; message = "THE ZOMBIE TURNS BACK! USE THE PLATFORMS"; message_time = 1.7
	if slime_attack_phase_started and slime_attack_next_beat >= 0.0 and player.x >= START_X + slime_attack_next_beat * _beat_width():
		slime_attack_timer = 1.05; slime_attack_elapsed = 0.0; slime_attack_resolved = false; slime_attack_visible = true; slime_attack_next_beat += 20.0
		if slime_attack_player != null and slime_attack_player.stream != null: slime_attack_player.play()
		message = "ZOMBIE ATTACK!"; message_time = 0.8

func _update_ghost_encounter(delta: float) -> void:
	if str(level.get("theme", "")) != "metro" or not chase_started: return
	for id in ghost_wave_offsets.keys():
		var bounce: Dictionary = ghost_wave_offsets[id]
		bounce["offset"] = float(bounce["offset"]) + float(bounce["velocity"]) * delta
		bounce["velocity"] = float(bounce["velocity"]) + 1800.0 * delta
		if float(bounce["offset"]) >= 0.0: ghost_wave_offsets.erase(id)
		else: ghost_wave_offsets[id] = bounce
	if ghost_death_timer > 0.0 or ghost_defeated_pending: return
	if ghost_final_started:
		ghost_final_timer -= delta
		if ghost_final_timer <= 0.0 and not ghost_final_resolved:
			ghost_final_resolved = true; ghost_final_started = false; _take_hit("THE GHOST CAUGHT YOU")
		return
	var attack_start_beat := float(level.get("length_beats", 196.0)) * 0.5
	if not ghost_attack_phase_started:
		if player.x >= START_X + attack_start_beat * _beat_width():
			ghost_attack_phase_started = true; ghost_attack_next_beat = attack_start_beat + 8.0
		return
	if ghost_wave_active:
		ghost_wave_previous_x = ghost_wave_x; ghost_wave_x -= 1180.0 * delta
		if ghost_wave_previous_x >= player.x - camera_x and ghost_wave_x <= player.x - camera_x:
			velocity.y = JUMP_VELOCITY * 0.72 * gravity_sign; _spawn_skin_burst(player + PLAYER_SIZE * 0.5, 7)
		for object in objects + runtime_objects:
			var object_screen_x := _object_x(object) - camera_x
			if ghost_wave_previous_x >= object_screen_x and ghost_wave_x <= object_screen_x and object_screen_x > -80.0 and object_screen_x < VIEW.x + 80.0:
				ghost_wave_offsets[object["id"]] = {"offset": -120.0, "velocity": -560.0}
		if ghost_wave_x <= -120.0: ghost_wave_active = false
	if ghost_attack_timer > 0.0:
		ghost_attack_timer -= delta; ghost_attack_elapsed += delta
		return
	var final_beat := float(level.get("length_beats", 196.0)) - 30.0
	if player.x >= START_X + final_beat * _beat_width() and not ghost_final_resolved:
		_start_ghost_final()
	elif ghost_attack_next_beat >= 0.0 and player.x >= START_X + ghost_attack_next_beat * _beat_width():
		_begin_ghost_attack()

func _begin_ghost_attack() -> void:
	ghost_attack_timer = 1.02; ghost_attack_elapsed = 0.0; ghost_attack_resolved = false; ghost_wave_active = true; ghost_wave_x = VIEW.x + 120.0; ghost_wave_previous_x = ghost_wave_x; ghost_attack_next_beat += 18.0
	if ghost_woosh_player != null and ghost_woosh_player.stream != null: ghost_woosh_player.play()

func _start_ghost_final() -> void:
	ghost_final_started = true; ghost_final_timer = 3.0; ghost_final_resolved = false; message = "DASH THE GHOST!"; message_time = 3.0

func _defeat_ghost() -> void:
	if ghost_final_started and not ghost_final_resolved:
		ghost_final_resolved = true; ghost_defeated_pending = true; score += 600; _combo_event("GHOST DEFEATED"); message = "GHOST DEFEATED!"; message_time = 1.25

func _trigger_ground_slam() -> void:
	slam_timer = 0.72
	slam_flash = 0.42
	slam_velocity = -520.0
	velocity.y = min(velocity.y, -430.0)
	_spawn_burst(Vector2(player.x + 36.0, FLOOR_Y - 4.0), Color("#f5e27e"), 18)
	message = "GROUND SLAM!"; message_time = 0.55

func _check_objects() -> void:
	var body := Rect2(player, PLAYER_SIZE)
	for object in objects + runtime_objects:
		var id: String = object["id"]; var kind: String = object["type"]
		if consumed.has(id): continue
		if invulnerability > 0.0 and (kind == "spike" or kind == "block" or kind == "saw"): continue
		var rect := _object_rect(object)
		if not body.intersects(rect): continue
		match kind:
			"spike", "block":
				if dash_left > 0.0: score += 40; consumed[id] = true; _spawn_burst(rect.position + rect.size * 0.5, Color("#ff698f"), 14)
				else: _take_hit("HIT THE BEAT WALL")
			"saw": _take_hit("SAW BLADE")
			"catapult":
				catapult_boost_left = float(object["properties"].get("launch_beats", 2.0)) * _music_beat(); velocity.x = DASH_SPEED; velocity.y = JUMP_VELOCITY * 1.15; consumed[id] = true; _combo_event("CATAPULT"); _spawn_skin_burst(rect.position + rect.size * 0.5, 12); message = "CATAPULT! UP + FORWARD"; message_time = 1.0
			"bounce_pad": velocity.y = JUMP_VELOCITY * float(object["properties"].get("strength", 1.0)); consumed[id] = true; _combo_event("BOUNCE")
			"speed_ring": score += 75; consumed[id] = true; speed_boost_multiplier = float(object["properties"].get("multiplier", 1.25)); speed_until = run_time + float(object["properties"].get("duration_beats", 4.0)) * _music_beat(); _combo_event("SPEED UP"); message = "SPEED RING • x%.2f" % speed_boost_multiplier; message_time = 1.0; _spawn_burst(rect.position + rect.size * 0.5, Color("#f5e27e"), 18)
			"star": score += 75; diamonds += 1; run_diamonds_earned += 1; run_stars_collected += 1; consumed[id] = true; _combo_event("COLLECT"); _spawn_burst(rect.position + rect.size * 0.5, Color("#f5e27e"), 10); _save_progress()
			"checkpoint": checkpoint_index = max(checkpoint_index, checkpoint_beats.find(float(object["beat"])))

func _check_triggers() -> void:
	for trigger in triggers:
		if triggered.has(trigger["id"]): continue
		if player.x >= START_X + float(trigger["beat"]) * _beat_width(): triggered[trigger["id"]] = true; _start_quiz(trigger); return

func _start_quiz(trigger: Dictionary) -> void:
	quiz_snapshot = {"player": player, "velocity": velocity, "camera_x": camera_x, "run_time": run_time, "gravity_sign": gravity_sign, "gravity_until": gravity_until, "speed_until": speed_until, "catapult_boost_left": catapult_boost_left, "music_position": music_player.get_playback_position() if music_player != null else 0.0}
	quiz_active = true; quiz_input_lock = 0.18; quiz_feedback_time = 0.0; quiz_time = 10.0; quiz_table = selected_times_table; quiz_number = rng.randi_range(1, 12)
	var correct: int = quiz_number * quiz_table; quiz_choices = [correct, correct + rng.randi_range(1, 3), max(2, correct - rng.randi_range(1, 3))]; quiz_choices.shuffle(); quiz_correct_index = quiz_choices.find(correct); message = "TIME SHIFT"; message_time = 1.0

func _answer_quiz(choice: int) -> void:
	if not quiz_active: return
	quiz_active = false
	var correct_answer: int = quiz_number * quiz_table
	if choice == quiz_correct_index:
		_restore_quiz_snapshot()
		quiz_points += 1; quiz_streak += 1
		var reward: int = 250 + max(0, quiz_streak - 1) * 100
		diamonds += 10 + max(0, quiz_streak - 1); run_diamonds_earned += 10 + max(0, quiz_streak - 1); score += reward; invulnerability = max(invulnerability, 2.0); _combo_event("SOLVED"); message = "CORRECT +%d • DIAMONDS +%d" % [reward, 10 + max(0, quiz_streak - 1)]; _save_progress()
	else:
		_restore_quiz_snapshot()
		quiz_feedback_answer = correct_answer; quiz_feedback_reason = "TIME UP" if choice < 0 else "WRONG TIMES TABLE"; quiz_feedback_text = "%d × %d = %d • CORRECT ANSWER: %d" % [quiz_table, quiz_number, correct_answer, correct_answer]; quiz_feedback_time = 2.0; combo = 0; quiz_streak = 0; flash = 0.25
	message_time = 1.5

func _restore_quiz_snapshot() -> void:
	if quiz_snapshot.is_empty(): return
	player = quiz_snapshot["player"]; velocity = quiz_snapshot["velocity"]; camera_x = float(quiz_snapshot["camera_x"]); run_time = float(quiz_snapshot["run_time"]); gravity_sign = float(quiz_snapshot["gravity_sign"]); gravity_until = float(quiz_snapshot["gravity_until"]); speed_until = float(quiz_snapshot["speed_until"]); catapult_boost_left = float(quiz_snapshot["catapult_boost_left"])
	var restore_position: float = float(quiz_snapshot["music_position"])
	if music_player != null: _resume_music(restore_position)
	quiz_snapshot.clear()

func _resolve_quiz_feedback() -> void:
	quiz_feedback_time = 0.0
	_resume_music(music_last_position)
	_take_hit(quiz_feedback_reason)
	message = quiz_feedback_reason; message_time = 1.0

func _start_dash() -> void:
	if dash_cooldown > 0.0 or dash_left > 0.0: return
	dash_left = DASH_TIME; dash_cooldown = _music_beat() * 2.0; velocity = Vector2(DASH_SPEED, 0.0); run_dashes += 1; _spawn_skin_burst(player + PLAYER_SIZE * 0.5, 8); _combo_event("DASH"); _defeat_ghost()

func _take_hit(reason: String) -> void:
	if invulnerability > 0.0: return
	run_hits += 1
	if shield_hits > 0:
		shield_hits -= 1; invulnerability = 0.8; velocity.y = -260.0; flash = 0.22; message = "%s • SHIELD %d/3" % [reason, shield_hits]; message_time = 1.2
	else: _crash(reason)

func _crash(reason: String) -> void:
	combo = 0; quiz_streak = 0; flash = 0.35; crash_reason = reason; crash_timer = 0.42; message = "CRASH!"; message_time = 0.42; _spawn_burst(player + PLAYER_SIZE * 0.5, Color("#ff698f"), 24)

func _respawn_at_checkpoint() -> void:
	player = Vector2(START_X + checkpoint_beats[checkpoint_index] * _beat_width(), FLOOR_Y - PLAYER_SIZE.y)
	velocity = Vector2.ZERO; dash_left = 0.0; dash_cooldown = 0.0; gravity_sign = 1.0; gravity_until = 0.0; speed_until = 0.0; speed_boost_multiplier = 1.0; catapult_boost_left = 0.0; quiz_active = false; quiz_feedback_time = 0.0; consumed.clear(); triggered.clear(); catapult_state.clear(); runtime_objects.clear(); invulnerability = 0.55; checkpoint_flash = 1.5; slam_offset = 0.0; slam_velocity = 0.0; slam_timer = 0.0
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

func _run_accuracy_percent() -> int:
	if run_jump_attempts <= 0: return 100
	return int(round(float(run_perfect_jumps + run_good_jumps) / float(run_jump_attempts) * 100.0))

func _is_grounded() -> bool:
	if gravity_sign < 0.0: return false
	if player.y + PLAYER_SIZE.y >= FLOOR_Y - 1.0: return true
	for platform in objects:
		if platform["type"] == "moving_platform" or platform["type"] == "platform":
			var rect := _object_rect(platform)
			if abs(player.y + PLAYER_SIZE.y - rect.position.y) < 8.0 and player.x + PLAYER_SIZE.x > rect.position.x and player.x < rect.end.x: return true
	return false

func _jump_beat_event() -> void:
	run_jump_attempts += 1
	var beat: float = _music_beat()
	var error: float = _beat_distance()
	if error <= beat * 0.10:
		run_perfect_jumps += 1; _spawn_skin_burst(player + PLAYER_SIZE * 0.5, 8)
		_combo_event("PERFECT JUMP")
		score += 150
		message = "PERFECT JUMP +150"
	elif error <= beat * 0.24:
		run_good_jumps += 1; _spawn_skin_burst(player + PLAYER_SIZE * 0.5, 5)
		_combo_event("GOOD JUMP")
		score += 60
		message = "GOOD JUMP +60"
	else:
		_combo_event("JUMP")

func _combo_event(label: String) -> void:
	combo += 1; best_combo = max(best_combo, combo); run_best_combo = max(run_best_combo, combo); score += 20 + combo * 2; message = "GOOD " + label; message_time = 0.55
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
	var kind: String = object["type"]; var x := _object_x(object); var y := _object_y(object); var slam_y := (slam_offset if chase_started else 0.0) + float(ghost_wave_offsets.get(object["id"], {}).get("offset", 0.0))
	match kind:
		"spike": return Rect2(x - 20, FLOOR_Y - 54 + slam_y, 40, 54)
		"block": return Rect2(x - 22, FLOOR_Y - 82 * float(object["properties"].get("height", 1.0)) + slam_y, 44, 82 * float(object["properties"].get("height", 1.0)))
		"saw":
			var saw_radius: float = float(object["properties"].get("radius", 30.0))
			return Rect2(x - saw_radius, y - saw_radius * 2.0, saw_radius * 2.0, saw_radius * 2.0)
		"catapult", "bounce_pad": return Rect2(x - 32, FLOOR_Y - 28 + slam_y, 64, 28)
		"moving_platform": return Rect2(x - 45, y - 15 + slam_y, 90, 30)
		"platform": return Rect2(x - 62, y - 10 + slam_y, 124, 20)
		"gravity_portal": return Rect2(x - 28, FLOOR_Y - 170 + slam_y, 56, 170)
		"speed_ring", "star": return Rect2(x - 18, y - 18 + slam_y, 36, 36)
		"checkpoint": return Rect2(x - 16, FLOOR_Y - 100 + slam_y, 32, 100)
	return Rect2(x - 20, y - 20 + slam_y, 40, 40)

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
	for i in range(trail_particles.size() - 1, -1, -1):
		trail_particles[i]["p"] += trail_particles[i]["v"] * delta; trail_particles[i]["v"] *= 0.90; trail_particles[i]["life"] -= delta
		if trail_particles[i]["life"] <= 0.0: trail_particles.remove_at(i)
func _spawn_burst(origin: Vector2, color: Color, count: int) -> void:
	for i in count: particles.append({"p": origin, "v": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(40.0, 220.0), "life": rng.randf_range(0.25, 0.7), "color": color, "style": "dot"})

func _spawn_skin_burst(origin: Vector2, count: int) -> void:
	var skin := _current_skin()
	var style := str(skin.get("style", "spark"))
	var color := Color(str(skin.get("trail", "#7cf5ff")))
	if bool(skin.get("animated", false)): color = Color.from_hsv(fmod(background_time * 0.12, 1.0), 0.58, 1.0)
	for i in count:
		particles.append({"p": origin, "v": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(45.0, 175.0), "life": rng.randf_range(0.32, 0.72), "color": color, "style": style})

func _update_player_trail() -> void:
	if not started or finished or build_mode or quiz_active or intro_time_left > 0.0: return
	var skin := _current_skin()
	var color := Color(str(skin.get("trail", "#7cf5ff")))
	if bool(skin.get("animated", false)): color = Color.from_hsv(fmod(background_time * 0.12, 1.0), 0.58, 1.0)
	var life := 0.42 if dash_left > 0.0 else 0.24
	var size := 9.0 if dash_left > 0.0 else 5.0
	trail_particles.append({"p": player + PLAYER_SIZE * 0.5 - Vector2(15.0, 0.0), "v": Vector2(-35.0 if dash_left > 0.0 else -12.0, 0.0), "life": life, "max_life": life, "size": size, "color": color, "style": str(skin.get("style", "spark"))})
func _draw_effect_particle(particle: Dictionary, screen_position: Vector2) -> void:
	var life: float = float(particle.get("life", 0.0)); var alpha: float = clamp(life / float(particle.get("max_life", 0.7)), 0.0, 1.0); var color := Color(particle["color"], alpha); var size: float = float(particle.get("size", 4.0)) * (0.45 + alpha * 0.55); var style := str(particle.get("style", "dot"))
	if style == "heart":
		draw_circle(screen_position + Vector2(-size * 0.35, -size * 0.2), size * 0.42, color); draw_circle(screen_position + Vector2(size * 0.35, -size * 0.2), size * 0.42, color); draw_colored_polygon(PackedVector2Array([screen_position + Vector2(-size * 0.75, 0), screen_position + Vector2(size * 0.75, 0), screen_position + Vector2(0, size)]), color)
	elif style == "leaf" or style == "comet":
		draw_colored_polygon(PackedVector2Array([screen_position + Vector2(0, -size), screen_position + Vector2(size * 0.55, 0), screen_position + Vector2(0, size), screen_position + Vector2(-size * 0.55, 0)]), color)
	else:
		draw_circle(screen_position, size, color)

func _draw() -> void:
	_draw_background(); _draw_world(); _draw_hud()
	if started and intro_time_left > 0.0 and _is_touch_device(): _draw_touch_guide()
	if not started: _draw_title()
	if quiz_active or quiz_feedback_time > 0.0: _draw_quiz()
	if build_mode: _draw_builder()
	if finished: _draw_finish()
	if flash > 0.0: draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(1.0, 0.35, 0.5, flash * 0.35))
	if slam_flash > 0.0: draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(1.0, 0.88, 0.55, slam_flash * 0.12))

func _draw_background() -> void:
	var pulse: float = 0.5 + 0.5 * sin(background_time * TAU / _music_beat())
	var screen_size := get_viewport_rect().size
	var fill_size := Vector2(max(screen_size.x, VIEW.x), max(screen_size.y, VIEW.y))
	var theme: String = str(level.get("theme", "skeleton"))
	var base_color: Color = Color("#17143e")
	if theme == "metro": base_color = Color("#101b38")
	if theme == "boss": base_color = Color("#24133f")
	if theme == "zombie": base_color = Color("#182b31")
	draw_rect(Rect2(Vector2.ZERO, fill_size), base_color)
	var band_count := int(ceil(fill_size.y / 80.0))
	var band_start: Color = Color("#21194e") if theme == "skeleton" else (Color("#14264b") if theme == "metro" else (Color("#203d3c") if theme == "zombie" else Color("#32164f")))
	var band_end: Color = Color("#583070") if theme == "skeleton" else (Color("#254d78") if theme == "metro" else (Color("#4d6b50") if theme == "zombie" else Color("#8d295e")))
	for band in range(band_count): draw_rect(Rect2(0, band * 80, fill_size.x, 82), band_start.lerp(band_end, min(1.0, float(band) / 9.0)))
	for x in range(-100, int(fill_size.x) + 1500, 100):
		var sx := fmod(x - camera_x * 0.15, 1500.0); draw_line(Vector2(sx, 0), Vector2(sx - 260, VIEW.y), Color(0.7, 0.45, 0.95, 0.11), 1.0)
	for y in range(80, int(fill_size.y) + 80, 80): draw_line(Vector2(0, y), Vector2(fill_size.x, y), Color(0.7, 0.45, 0.95, 0.10), 1.0)
	_draw_beat_layers(fill_size, pulse)
	_draw_background_details(fill_size, pulse)
	match theme:
		"metro": _draw_metro_background(pulse, fill_size)
		"boss": _draw_boss_background(pulse, fill_size)
		"zombie": _draw_zombie_background(pulse, fill_size)
		_: _draw_kawaii_bone_carnival(pulse)
	if theme == "skeleton": _draw_chaser()
	elif theme == "metro": _draw_ghost_chaser()
	elif theme == "zombie": _draw_zombie_chaser()
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

func _draw_zombie_background(pulse: float, fill_size: Vector2) -> void:
	# A separate moonlit village look for level 3: fog, rooftops and drifting crows.
	draw_circle(Vector2(fill_size.x * 0.78, 170.0), 76.0 + pulse * 5.0, Color(0.82, 0.94, 0.72, 0.13))
	draw_circle(Vector2(fill_size.x * 0.78, 170.0), 58.0, Color("#d7e3bd"))
	for i in range(7):
		var house_x := fmod(i * 230.0 - camera_x * 0.16, fill_size.x + 300.0) - 150.0
		var house_y := FLOOR_Y - 120.0 - float(i % 3) * 25.0
		draw_rect(Rect2(house_x, house_y, 130.0, 120.0), Color(0.08, 0.14, 0.16, 0.66))
		draw_colored_polygon(PackedVector2Array([Vector2(house_x - 18, house_y), Vector2(house_x + 65, house_y - 64), Vector2(house_x + 148, house_y)]), Color(0.10, 0.18, 0.18, 0.72))
		for window in range(2): draw_rect(Rect2(house_x + 24.0 + window * 58.0, house_y + 35.0, 18.0, 26.0), Color(0.86, 0.72, 0.35, 0.28 + pulse * 0.16))
	for i in range(5):
		var fog_x := fmod(100.0 + i * 300.0 + background_time * (12.0 + i), fill_size.x + 260.0) - 130.0
		var fog_y := 410.0 + sin(background_time * 0.7 + i) * 18.0
		draw_line(Vector2(fog_x - 140.0, fog_y), Vector2(fog_x + 140.0, fog_y), Color(0.72, 0.88, 0.78, 0.10), 18.0)
	for i in range(6):
		var crow_x := fmod(i * 260.0 + background_time * 35.0 - camera_x * 0.08, fill_size.x + 180.0) - 90.0
		var crow_y := 105.0 + float(i % 3) * 48.0 + sin(background_time * 2.0 + i) * 8.0
		draw_arc(Vector2(crow_x, crow_y), 12.0, PI + 0.2, TAU - 0.2, 10, Color(0.08, 0.10, 0.12, 0.65), 3.0)

func _draw_chaser() -> void:
	var chase_mode: bool = _chase_active()
	var chaser_offset: float = 250.0 if chase_mode else 350.0
	var chaser_x: float = clampf(player.x - camera_x - chaser_offset, 150.0, 470.0)
	var leader_origin: Vector2 = Vector2(chaser_x, 580.0)
	var forced_frame := 10 if slam_timer > 0.0 else -1
	_draw_marching_skeleton(leader_origin, 0.70, Color("#fff5dd"), 0.0, true, forced_frame)
	if slam_timer > 0.0: _draw_slam_effect(chaser_x)

func _draw_ghost_chaser() -> void:
	if not chase_started: return
	var player_screen_x := player.x - camera_x
	var ghost_x := clampf(player_screen_x - 245.0, 120.0, 520.0)
	var ghost_origin := Vector2(ghost_x, FLOOR_Y - 24.0)
	var sprite: Texture2D = ghost_float_sprite
	var frame_count := 8
	var frame_index := int(floor(background_time / _music_beat() * 5.0)) % frame_count
	var ghost_scale := 1.62
	if ghost_death_timer > 0.0:
		sprite = ghost_death_sprite; frame_count = 12; frame_index = clampi(int(floor((1.25 - ghost_death_timer) / 1.25 * frame_count)), 0, frame_count - 1); ghost_x = clampf(player_screen_x + 190.0, 610.0, 1030.0); ghost_origin = Vector2(ghost_x, FLOOR_Y - 28.0); ghost_scale = 1.52
	elif ghost_final_started:
		sprite = ghost_idle_sprite; frame_count = 8; frame_index = int(floor(background_time / _music_beat() * 4.0)) % frame_count; ghost_x = clampf(player_screen_x + 190.0, 610.0, 1030.0); ghost_origin = Vector2(ghost_x, FLOOR_Y - 28.0); ghost_scale = 1.48
	elif ghost_attack_timer > 0.0:
		sprite = ghost_attack_sprite; frame_count = 12; frame_index = clampi(int(floor(ghost_attack_elapsed / 0.92 * frame_count)), 0, frame_count - 1); ghost_x = clampf(player_screen_x + 500.0, 940.0, 1140.0); ghost_origin = Vector2(ghost_x, FLOOR_Y - 22.0); ghost_scale = 1.62
	elif ghost_attack_phase_started:
		sprite = ghost_float_left_sprite; frame_count = 8; frame_index = int(floor(background_time / _music_beat() * 5.0)) % frame_count; ghost_x = clampf(player_screen_x + 500.0, 940.0, 1140.0); ghost_origin = Vector2(ghost_x, FLOOR_Y - 24.0); ghost_scale = 1.62
	draw_circle(ghost_origin + Vector2(0.0, -110.0), 128.0 + _beat_pulse() * 16.0, Color(0.72, 0.54, 0.95, 0.10))
	_draw_ghost_sprite(sprite, ghost_origin, ghost_scale, frame_index, Color(1.0, 1.0, 1.0, 0.98))
	if ghost_wave_active:
		var wave_x := ghost_wave_x
		for i in range(7):
			var y := 150.0 + i * 62.0
			draw_line(Vector2(wave_x, y), Vector2(wave_x - 34.0, y + 30.0), Color(1.0, 0.68, 0.86, 0.72), 6.0)
			draw_line(Vector2(wave_x - 34.0, y + 30.0), Vector2(wave_x, y + 60.0), Color(0.74, 0.55, 1.0, 0.72), 6.0)

func _draw_zombie_chaser() -> void:
	if not chase_started or not slime_attack_visible and slime_death_timer <= 0.0: return
	var player_screen_x := player.x - camera_x
	var slime_x := clampf(player_screen_x - 290.0, 110.0, 430.0)
	var slime_y := FLOOR_Y - 42.0
	var mode := "walk"
	var progress := 0.0
	var sprite: Texture2D = zombie_walk_sprite
	var frame_count := 8
	var cell_size := 437.0
	var flip_h := true
	if slime_death_timer > 0.0:
		mode = "death"; progress = 1.0 - slime_death_timer / 1.7; sprite = zombie_death_sprite; frame_count = 12; cell_size = 501.0; flip_h = false; slime_x = clampf(player_screen_x + 160.0, 760.0, 1120.0); slime_y = FLOOR_Y - 50.0
	elif slime_attack_phase_started:
		slime_x = clampf(player_screen_x + 500.0, 980.0, 1180.0); slime_y = FLOOR_Y - 46.0; flip_h = false
		if slime_attack_timer > 0.0: mode = "attack"; progress = slime_attack_elapsed / 1.05; sprite = zombie_attack_sprite; frame_count = 4; cell_size = 421.0
		else: mode = "idle"; sprite = zombie_idle_sprite; frame_count = 4; cell_size = 408.0
	var bob := sin(slime_walk_time * 7.0) * 4.0 if mode == "walk" else 0.0
	var scale := 0.78 if mode == "walk" else 0.82
	if mode == "attack": scale = 0.88
	draw_circle(Vector2(slime_x, slime_y - 56.0 + bob), 82.0 + _beat_pulse() * 10.0, Color(0.36, 1.0, 0.72, 0.10))
	var frame_index := 0
	if mode == "walk": frame_index = int(floor(background_time / _music_beat() * 2.0)) % frame_count
	elif mode == "idle": frame_index = int(floor(background_time / _music_beat() * 2.0)) % frame_count
	elif mode == "attack": frame_index = clampi(int(floor(progress * frame_count)), 0, frame_count - 1)
	elif mode == "death": frame_index = clampi(int(floor(progress * frame_count)), 0, frame_count - 1)
	if sprite != null:
		_draw_zombie_sprite(sprite, Vector2(slime_x, slime_y + bob), scale, frame_index, frame_count, cell_size, flip_h, Color(1.0, 1.0, 1.0, 0.98))
	else:
		_draw_procedural_zombie(Vector2(slime_x, slime_y + bob), scale, mode, progress)

func _draw_zombie_sprite(sprite: Texture2D, origin: Vector2, scale: float, frame_index: int, frame_count: int, cell_size: float, flip_h: bool, tint: Color) -> void:
	if sprite == null: return
	var source := Rect2(Vector2(float(frame_index % 4) * cell_size, float(int(frame_index / 4)) * cell_size), Vector2(cell_size, cell_size))
	var signed_scale := -scale if flip_h else scale
	draw_set_transform(origin, 0.0, Vector2(signed_scale, scale))
	draw_texture_rect_region(sprite, Rect2(Vector2(-cell_size * 0.5, -cell_size * 0.82), Vector2(cell_size, cell_size)), source, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_procedural_zombie(origin: Vector2, scale: float, mode: String, progress: float) -> void:
	# Stable drawn fallback for the supplied walk/idle/attack/death reference set.
	# Every pose is generated, so there are no missing-frame flashes.
	var death_progress := clampf(progress, 0.0, 1.0) if mode == "death" else 0.0
	var lean := 0.0
	if mode == "walk": lean = sin(slime_walk_time * 7.0) * 0.04
	elif mode == "attack": lean = -0.24 * sin(clampf(progress, 0.0, 1.0) * PI)
	elif mode == "death": lean = death_progress * 1.1
	var alpha := 1.0 - death_progress * 0.35
	var face := -1.0 if mode == "attack" or mode == "idle" or mode == "death" else 1.0
	draw_set_transform(origin, lean, Vector2(scale, scale * (1.0 - death_progress * 0.5)))
	# Boots and trousers give the chase a readable villager silhouette.
	draw_line(Vector2(-18, -52), Vector2(-25 + sin(slime_walk_time * 7.0) * 12.0, 0), Color("#2d3546", alpha), 15.0)
	draw_line(Vector2(18, -52), Vector2(25 - sin(slime_walk_time * 7.0) * 12.0, 0), Color("#2d3546", alpha), 15.0)
	draw_line(Vector2(-25, 0), Vector2(-42, 2), Color("#161c2a", alpha), 9.0)
	draw_line(Vector2(25, 0), Vector2(42, 2), Color("#161c2a", alpha), 9.0)
	draw_rect(Rect2(-31, -108, 62, 60), Color("#68756d", alpha))
	draw_line(Vector2(-28, -102), Vector2(28, -102), Color("#9aa889", alpha), 4.0)
	var arm_swing := sin(slime_walk_time * 7.0) * 18.0
	if mode == "attack":
		draw_line(Vector2(-20, -91), Vector2(-92, -66), Color("#8ca68e", alpha), 13.0)
		draw_circle(Vector2(-96, -65), 13.0, Color("#a6c39b", alpha))
	else:
		draw_line(Vector2(-25, -91), Vector2(-45, -55 + arm_swing), Color("#8ca68e", alpha), 12.0)
		draw_line(Vector2(25, -91), Vector2(45, -55 - arm_swing), Color("#8ca68e", alpha), 12.0)
	var head := Vector2(0, -137)
	draw_circle(head, 31.0, Color("#93b18d", alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(-32, -151), Vector2(-15, -177), Vector2(7, -166), Vector2(30, -177), Vector2(33, -145)]), Color("#3a4540", alpha))
	draw_circle(head + Vector2(11.0 * face, -5.0), 5.0, Color("#d8f6b6", alpha))
	draw_circle(head + Vector2(11.0 * face, -5.0), 2.0, Color("#4a242e", alpha))
	draw_circle(head + Vector2(-9.0 * face, -3.0), 5.0, Color("#d8f6b6", alpha))
	draw_circle(head + Vector2(-9.0 * face, -3.0), 2.0, Color("#4a242e", alpha))
	draw_line(head + Vector2(-13, 12), head + Vector2(16, 10), Color("#4a242e", alpha), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if mode == "death":
		for i in range(8):
			var angle := i * TAU / 8.0 + death_progress * 2.0
			var p := origin + Vector2.from_angle(angle) * (30.0 + death_progress * 105.0)
			draw_circle(p, max(2.0, 7.0 * (1.0 - death_progress)), Color(0.58, 0.82, 0.52, 1.0 - death_progress))

func _draw_ghost_sprite(sprite: Texture2D, origin: Vector2, scale: float, frame_index: int, tint: Color) -> void:
	if sprite == null: return
	var cell := 256.0
	var source := Rect2(Vector2(float(frame_index % 4) * cell, float(int(frame_index / 4)) * cell), Vector2(cell, cell))
	var size := Vector2(cell, cell) * scale
	var destination := Rect2(origin - Vector2(size.x * 0.5, size.y * 0.78), size)
	draw_texture_rect_region(sprite, destination, source, tint)

func _draw_slam_effect(chaser_x: float) -> void:
	var progress: float = 1.0 - slam_timer / 0.72
	var impact := Vector2(chaser_x + 42.0, FLOOR_Y + slam_offset - 5.0)
	var ring_size: float = 28.0 + progress * 145.0
	var effect_alpha: float = max(0.0, 1.0 - progress * 0.85)
	draw_arc(impact, ring_size, PI, TAU, 24, Color(1.0, 0.84, 0.47, effect_alpha), 7.0)
	draw_arc(impact, ring_size * 0.72, 0.0, PI, 20, Color(0.66, 1.0, 0.83, effect_alpha), 4.0)
	draw_line(Vector2(chaser_x + 44.0, 306.0), impact, Color(1.0, 0.93, 0.72, effect_alpha), 9.0)
	draw_colored_polygon(PackedVector2Array([impact + Vector2(-34, 0), impact + Vector2(-11, -13), impact + Vector2(0, 0), impact + Vector2(18, -17), impact + Vector2(45, 0)]), Color(1.0, 0.78, 0.55, effect_alpha * 0.55))

func _draw_marching_skeleton(origin: Vector2, scale: float, tint: Color, phase_offset: float, leader: bool, forced_frame: int = -1) -> void:
	if skeleton_sprite == null: return
	var sprite_frame_count: float = 12.0
	var sprite_frame_position: float = fmod(background_time / _music_beat() * 6.0 + phase_offset, sprite_frame_count)
	var sprite_frame_index: int = forced_frame if forced_frame >= 0 else int(floor(sprite_frame_position))
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
		if not consumed.has(object["id"]) and intro_time_left <= 0.0: _draw_object(object)
	for trail in trail_particles: _draw_effect_particle(trail, trail["p"] - Vector2(camera_x, 0))
	for particle in particles: _draw_effect_particle(particle, particle["p"] - Vector2(camera_x, 0))
	var center := player - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5
	_draw_player(center)
	if shield_hits > 0 or invulnerability > 0.0:
		var shield_color := Color(str(_current_skin().get("shield", "#a8ffd0"))) if shield_hits > 0 else Color("#ffffff")
		draw_arc(center, 38.0 + sin(background_time * 8.0) * 3.0, 0.0, TAU, 32, shield_color, 4.0)
	if crash_timer > 0.0:
		draw_circle(player - Vector2(camera_x, 0) + PLAYER_SIZE * 0.5, 42.0 + sin(background_time * 24.0) * 5.0, Color(1.0, 0.25, 0.45, 0.12))

func _draw_player(center: Vector2) -> void:
	var skin: Dictionary = _current_skin()
	var body := Color(str(skin.get("body", "#75f1ff")))
	var core := Color(str(skin.get("core", "#f5e27e")))
	var animated: bool = bool(skin.get("animated", false))
	if animated: body = Color.from_hsv(fmod(background_time * 0.12, 1.0), 0.58, 1.0)
	var rotation := run_time * 2.0 if dash_left > 0.0 else 0.0
	var squash := 1.0 + sin(background_time * 16.0) * 0.035 if _is_grounded() else 1.0
	draw_set_transform(center, rotation, Vector2(squash, 2.0 - squash))
	if dash_left > 0.0:
		draw_line(Vector2(-42, 0), Vector2(-24, 0), Color(body, 0.55), 8.0)
		draw_arc(Vector2.ZERO, 31.0 + sin(background_time * 28.0) * 3.0, -0.8, 0.8, 16, Color(str(skin.get("trail", "#7cf5ff"))), 4.0)
	draw_rect(Rect2(-23, -23, 46, 46), body)
	draw_rect(Rect2(-16, -16, 32, 32), Color("#182450"))
	draw_rect(Rect2(-8, -8, 16, 16), core)
	if animated:
		for i in range(4):
			var angle := background_time * 3.0 + i * TAU / 4.0
			draw_circle(Vector2(cos(angle), sin(angle)) * 31.0, 3.0, Color(body, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _is_touch_device() -> bool:
	if not OS.has_feature("web"): return false
	return bool(JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(pointer: coarse)').matches"))

func _draw_touch_guide() -> void:
	var screen_size := get_viewport_rect().size
	var alpha: float = clamp(intro_time_left / 1.25, 0.0, 1.0) * 0.88
	var jump_rect := _touch_jump_rect().grow(-12.0)
	var dash_rect := _touch_dash_rect().grow(-12.0)
	draw_rect(jump_rect, Color(0.10, 0.45, 0.55, alpha * 0.42))
	draw_rect(dash_rect, Color(0.55, 0.18, 0.55, alpha * 0.42))
	draw_string(ThemeDB.fallback_font, Vector2(0, screen_size.y * 0.60), "GET READY", HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 24, Color(1.0, 0.95, 0.72, alpha))
	draw_string(ThemeDB.fallback_font, Vector2(jump_rect.position.x, jump_rect.position.y + 58.0), "TAP TO JUMP", HORIZONTAL_ALIGNMENT_CENTER, jump_rect.size.x, 22, Color(0.66, 1.0, 0.83, alpha))
	draw_string(ThemeDB.fallback_font, Vector2(dash_rect.position.x, dash_rect.position.y + 58.0), "TAP TO DASH", HORIZONTAL_ALIGNMENT_CENTER, dash_rect.size.x, 22, Color(1.0, 0.72, 0.88, alpha))
	var jump_center := jump_rect.position + Vector2(jump_rect.size.x * 0.5, 104.0)
	var dash_center := dash_rect.position + Vector2(dash_rect.size.x * 0.5, 104.0)
	draw_circle(jump_center, 18.0, Color(0.66, 1.0, 0.83, alpha * 0.8))
	draw_line(jump_center + Vector2(0, 4), jump_center - Vector2(0, 18), Color("#182450"), 5.0)
	draw_colored_polygon(PackedVector2Array([jump_center - Vector2(0, 28), jump_center - Vector2(10, 14), jump_center + Vector2(10, 14)]), Color("#182450"))
	draw_line(dash_center - Vector2(28, 0), dash_center + Vector2(28, 0), Color("#182450"), 7.0)
	draw_colored_polygon(PackedVector2Array([dash_center + Vector2(38, 0), dash_center + Vector2(20, -12), dash_center + Vector2(20, 12)]), Color("#182450"))

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
	var kind: String = object["type"]; var rect := _object_rect(object); rect.position.x -= camera_x; var center := rect.get_center(); var slam_floor := FLOOR_Y + (slam_offset if chase_started else 0.0) + float(ghost_wave_offsets.get(object["id"], {}).get("offset", 0.0))
	match kind:
		"spike":
			draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x, slam_floor), Vector2(center.x, rect.position.y), Vector2(rect.end.x, slam_floor)]), Color("#ed496f"))
			draw_line(Vector2(center.x - 7, rect.position.y + 18), Vector2(center.x + 7, rect.position.y + 30), Color("#ffd6e2"), 4.0)
		"block":
			draw_rect(rect, Color("#ed496f")); draw_rect(rect.grow(-7.0), Color("#8d2348"), false, 4.0); draw_circle(rect.get_center(), 8.0, Color("#ffb6c9"))
		"saw":
			var saw_radius := rect.size.x * 0.5
			var saw_center := rect.get_center()
			draw_circle(saw_center, saw_radius + 7.0 + sin(background_time * 10.0) * 2.0, Color(0.93, 0.29, 0.44, 0.16))
			draw_set_transform(saw_center, background_time * float(object["properties"].get("spin_speed", 4.0)), Vector2.ONE)
			for tooth in range(12):
				var a := tooth * TAU / 12.0
				var p0 := Vector2.from_angle(a) * (saw_radius - 3.0)
				var p1 := Vector2.from_angle(a + 0.13) * (saw_radius + 8.0)
				var p2 := Vector2.from_angle(a + 0.26) * (saw_radius - 3.0)
				draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color("#ff4f73"))
			draw_circle(Vector2.ZERO, saw_radius - 5.0, Color("#d92e58")); draw_circle(Vector2.ZERO, 9.0, Color("#ffd1dc")); draw_circle(Vector2.ZERO, 4.0, Color("#7f1c43"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"catapult":
			draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Vector2(rect.end.x - 10.0, rect.position.y + 7.0), Vector2(rect.position.x + 18.0, rect.position.y + 2.0)]), Color("#55d68a")); draw_line(Vector2(center.x - 18.0, rect.end.y - 4.0), Vector2(center.x + 8.0, rect.position.y - 12.0), Color("#124d46"), 7.0); draw_circle(Vector2(center.x - 18.0, rect.end.y - 4.0), 8.0, Color("#a8ffd0")); draw_circle(Vector2(center.x + 8.0, rect.position.y - 12.0), 10.0, Color("#f5e27e")); draw_colored_polygon(PackedVector2Array([Vector2(center.x + 8.0, rect.position.y - 34.0), Vector2(center.x - 2.0, rect.position.y - 20.0), Vector2(center.x + 3.0, rect.position.y - 20.0), Vector2(center.x + 3.0, rect.position.y - 10.0), Vector2(center.x + 13.0, rect.position.y - 10.0), Vector2(center.x + 13.0, rect.position.y - 20.0), Vector2(center.x + 18.0, rect.position.y - 20.0)]), Color("#a8ffd0"))
		"bounce_pad":
			draw_rect(rect, Color("#55d68a")); draw_line(Vector2(rect.position.x + 8, rect.end.y - 6), Vector2(center.x, rect.position.y + 5), Color("#124d46"), 4.0); draw_line(Vector2(rect.end.x - 8, rect.end.y - 6), Vector2(center.x, rect.position.y + 5), Color("#124d46"), 4.0)
		"moving_platform":
			draw_rect(rect, Color("#55d68a")); draw_line(Vector2(rect.position.x - 18, center.y), Vector2(rect.position.x - 3, center.y), Color("#a8ffd0"), 3.0); draw_line(Vector2(rect.end.x + 3, center.y), Vector2(rect.end.x + 18, center.y), Color("#a8ffd0"), 3.0)
		"platform":
			draw_rect(rect, Color("#55d68a")); draw_rect(rect.grow(-4.0), Color("#1e6d63")); draw_line(Vector2(rect.position.x + 8, rect.position.y + 4), Vector2(rect.end.x - 8, rect.position.y + 4), Color("#a8ffd0"), 3.0)
		"gravity_portal":
			draw_circle(center, 35.0 + sin(background_time * 4.0) * 3.0, Color(0.25, 0.95, 0.58, 0.18)); draw_arc(center, 35.0, 0.0, TAU, 24, Color("#55d68a"), 7.0); draw_arc(center, 20.0, 0.0, TAU, 16, Color("#a8ffd0"), 3.0)
		"speed_ring":
			draw_circle(center, 32.0 + sin(background_time * 8.0) * 4.0, Color(0.96, 0.85, 0.32, 0.12)); draw_arc(center, 18.0, background_time * 3.0, background_time * 3.0 + TAU * 0.78, 20, Color("#55d68a"), 7.0); draw_arc(center, 29.0, -background_time * 2.0, -background_time * 2.0 + TAU * 0.78, 20, Color("#a8ffd0"), 4.0); draw_string(ThemeDB.fallback_font, center + Vector2(-12, 5), "▶", HORIZONTAL_ALIGNMENT_CENTER, 24, 16, Color("#f5e27e"))
		"star":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -18), center + Vector2(9, 0), center + Vector2(0, 18), center + Vector2(-9, 0)]), Color("#f5e27e")); draw_circle(center, 5.0, Color("#fff8cf"))
		"checkpoint":
			draw_line(Vector2(center.x, rect.end.y), Vector2(center.x, rect.position.y), Color("#55d68a"), 5.0); draw_colored_polygon(PackedVector2Array([Vector2(center.x + 2, rect.position.y + 4), Vector2(center.x + 30, rect.position.y + 14), Vector2(center.x + 2, rect.position.y + 25)]), Color("#a8ffd0"))

func _draw_hud() -> void:
	draw_rect(Rect2(24, 20, 690, 80), Color(0.04, 0.06, 0.16, 0.84)); draw_string(ThemeDB.fallback_font, Vector2(44, 52), "%02d  %s" % [level_index + 1, str(level["display_name"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(44, 80), "SCORE %06d    COMBO x%d    SHIELD %d/3    ♦ %03d" % [score, combo, shield_hits, diamonds], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 300, 46), "%d BPM  •  %s" % [int(level["music"]["bpm"]), "BUILDER" if build_mode else ("SLOWED" if quiz_active else ("CHASE" if _chase_active() else "ON BEAT"))], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#cbbaff")); draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 300, 76), "DISTANCE %04d m" % int(player.x / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#8fa8df"))
	if quiz_streak > 0: draw_string(ThemeDB.fallback_font, Vector2(470, 52), "QUIZ STREAK x%d" % quiz_streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a8ffd0"))
	if run_time < speed_until and started: draw_string(ThemeDB.fallback_font, Vector2(470, 80), "SPEED BOOST x%.2f  %.1fs" % [speed_boost_multiplier, max(0.0, speed_until - run_time)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a8ffd0"))
	if audio_resync_time > 0.0: draw_string(ThemeDB.fallback_font, Vector2(0, 145), "RESYNCING BEAT %.1f" % audio_resync_time, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 19, Color("#a8ffd0"))
	if message_time > 0.0: draw_string(ThemeDB.fallback_font, Vector2(VIEW.x / 2 - 200, 145), message, HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color("#ffffff"))
	if ghost_final_started:
		var final_rect := Rect2(390, 176, 500, 72); draw_rect(final_rect, Color(0.35, 0.16, 0.48, 0.94)); draw_rect(final_rect, Color("#f5e27e"), false, 4.0); draw_string(ThemeDB.fallback_font, final_rect.position + Vector2(0, 48), "DASH THE GHOST!", HORIZONTAL_ALIGNMENT_CENTER, final_rect.size.x, 34, Color("#ffffff"))
	if crash_timer > 0.0: draw_string(ThemeDB.fallback_font, Vector2(0, 188), "%s  •  TAP / SPACE TO RETRY NOW" % crash_reason, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#ffb6c9"))
	if started and not quiz_active and not build_mode and not finished: draw_string(ThemeDB.fallback_font, Vector2(34, VIEW.y - 30), "SPACE / TAP JUMP     X / TAP DASH     B BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 1.0, 0.7))

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.78)); draw_string(ThemeDB.fallback_font, Vector2(0, 68), "NEON TWICE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 54, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(0, 108), "SHOP" if shop_open else "CHOOSE YOUR BEAT", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, Color("#f5e27e"))
	var shop_button := _shop_button_rect()
	draw_rect(shop_button, Color("#55d68a") if shop_open else Color("#26336e")); draw_rect(shop_button, Color("#7cf5ff"), false, 3.0); draw_string(ThemeDB.fallback_font, shop_button.position + Vector2(14, 24), "BACK" if shop_open else "SHOP  ♦ %03d" % diamonds, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffffff"))
	if shop_open:
		_draw_shop(); return
	draw_string(ThemeDB.fallback_font, Vector2(0, 142), "TIMES TABLE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 16, Color("#a9b8ef"))
	var table_rect := Rect2(476.0, 108.0, 328.0, 48.0)
	draw_rect(table_rect, Color("#182450")); draw_rect(table_rect, Color("#b06cff"), false, 3.0)
	draw_rect(_times_table_minus_rect(), Color("#26336e")); draw_rect(_times_table_plus_rect(), Color("#26336e"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 142), "× %d" % selected_times_table, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(438, 141), "−", HORIZONTAL_ALIGNMENT_CENTER, 20, 28, Color("#f5e27e")); draw_string(ThemeDB.fallback_font, Vector2(822, 141), "+", HORIZONTAL_ALIGNMENT_CENTER, 20, 28, Color("#f5e27e"))
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

func _draw_shop() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(55, 132), "CHOOSE YOUR CUBE • PRESS S OR ESC TO RETURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#cbbaff"))
	for i in range(SKINS.size()):
		var skin: Dictionary = SKINS[i]
		var card := _shop_card_rect(i)
		var skin_id := str(skin["id"])
		var owned := owned_skins.has(skin_id)
		var equipped := equipped_skin == skin_id
		draw_rect(card, Color("#26336e") if equipped else Color("#182450")); draw_rect(card, Color("#a8ffd0") if equipped else (Color("#7cf5ff") if owned else Color("#70789f")), false, 4.0)
		var preview := card.position + Vector2(52.0, 74.0)
		var body := Color(str(skin["body"]))
		if bool(skin.get("animated", false)): body = Color.from_hsv(fmod(background_time * 0.12, 1.0), 0.58, 1.0)
		draw_rect(Rect2(preview - Vector2(28, 28), Vector2(56, 56)), body); draw_rect(Rect2(preview - Vector2(19, 19), Vector2(38, 38)), Color("#182450")); draw_rect(Rect2(preview - Vector2(9, 9), Vector2(18, 18)), Color(str(skin["core"])))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(100, 45), str(skin["name"]), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 120, 20, Color("#ffffff"))
		var status := "EQUIPPED" if equipped else ("EQUIP" if owned else "%d DIAMONDS" % int(skin["cost"]))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(100, 92), status, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 120, 17, Color("#a8ffd0") if owned else Color("#f5e27e"))
		draw_string(ThemeDB.fallback_font, card.position + Vector2(24, 164), "ANIMATED BEAT SKIN" if bool(skin.get("animated", false)) else "BEAT RUNNER STYLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a9b8ef"))

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
	draw_rect(Rect2(0, 0, 300, VIEW.y), Color("#0c1230")); draw_rect(Rect2(0, 0, 300, 112), Color("#182450")); draw_string(ThemeDB.fallback_font, Vector2(24, 38), "BEAT BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#7cf5ff")); draw_string(ThemeDB.fallback_font, Vector2(24, 63), "Drag empty space to pan", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a9b8ef"))
	draw_rect(Rect2(16, 72, 126, 28), Color("#26336e")); draw_rect(Rect2(150, 72, 134, 28), Color("#26336e")); draw_string(ThemeDB.fallback_font, Vector2(26, 92), "EXPORT JSON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a8ffd0")); draw_string(ThemeDB.fallback_font, Vector2(160, 92), "IMPORT JSON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f5e27e"))
	for i in range(PALETTE.size()):
		var y := 130.0 + i * 42.0; var selected := i == selected_palette; draw_rect(Rect2(16, y - 28, 268, 36), Color("#26336e") if selected else Color("#11183e")); draw_string(ThemeDB.fallback_font, Vector2(30, y - 4), "%d  %s" % [(i + 1) % 10, PALETTE[i].replace("_", " ").to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f5e27e") if selected else Color("#d6defc"))
	for beat in range(0, int(level.get("length_beats", 200.0)) + 1, 4):
		var x := START_X + float(beat) * _beat_width() - camera_x
		if x < 300.0 or x > VIEW.x: continue
		draw_line(Vector2(x, 116), Vector2(x, VIEW.y), Color(0.48, 0.63, 0.92, 0.20), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(x + 4, 136), "%d" % beat, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8fa8df"))
	for trigger in triggers:
		var tx := START_X + float(trigger["beat"]) * _beat_width() - camera_x
		if tx < 300.0 or tx > VIEW.x: continue
		draw_line(Vector2(tx, 150), Vector2(tx, FLOOR_Y), Color("#f5e27e"), 5.0)
		draw_circle(Vector2(tx, 160), 12.0, Color("#f5e27e")); draw_string(ThemeDB.fallback_font, Vector2(tx - 34, 190), "× %d" % selected_times_table, HORIZONTAL_ALIGNMENT_CENTER, 68, 16, Color("#fff1a8"))
	draw_string(ThemeDB.fallback_font, Vector2(330, 92), "Yellow lines = timetable questions • drag cyan cube • T test from cube • Enter restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffffff"))
	draw_rect(Rect2(1000, 56, 240, 44), Color("#55d68a")); draw_rect(Rect2(1000, 56, 240, 44), Color("#a8ffd0"), false, 3.0); draw_string(ThemeDB.fallback_font, Vector2(1018, 85), "TEST FROM CUBE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#102d36"))

func _draw_finish() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.90))
	draw_string(ThemeDB.fallback_font, Vector2(0, 150), "LEVEL COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 54, Color("#7cf5ff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 198), "%s" % str(level["display_name"]), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 24, Color("#a8ffd0"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 246), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 28, Color("#f5e27e"))
	_draw_finish_stat(Rect2(80, 285, 250, 112), "DIAMONDS EARNED", "+%d" % run_diamonds_earned, Color("#f5e27e"))
	_draw_finish_stat(Rect2(365, 285, 250, 112), "PERFECT BEATS", "%d" % run_perfect_jumps, Color("#7cf5ff"))
	_draw_finish_stat(Rect2(650, 285, 250, 112), "ON-BEAT ACCURACY", "%d%%" % _run_accuracy_percent(), Color("#a8ffd0"))
	_draw_finish_stat(Rect2(935, 285, 250, 112), "MISSED OPPORTUNITIES", "%d" % max(0, run_jump_attempts - run_perfect_jumps - run_good_jumps + run_hits), Color("#ff9dbc"))
	_draw_finish_stat(Rect2(220, 425, 250, 92), "QUIZZES SOLVED", "%d" % quiz_points, Color("#b06cff"))
	_draw_finish_stat(Rect2(515, 425, 250, 92), "BEST COMBO", "x%d" % run_best_combo, Color("#ffffff"))
	_draw_finish_stat(Rect2(810, 425, 250, 92), "DASHES", "%d" % run_dashes, Color("#d7b5ff"))
	var menu_button := _finish_menu_rect()
	draw_rect(menu_button, Color("#26336e")); draw_rect(menu_button, Color("#7cf5ff"), false, 3.0)
	draw_string(ThemeDB.fallback_font, menu_button.position + Vector2(0, 38), "TOUCH: BACK TO LEVELS", HORIZONTAL_ALIGNMENT_CENTER, menu_button.size.x, 18, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 620), "SPACE: PLAY AGAIN  •  ESC: LEVELS", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 16, Color("#a9b8ef"))

func _draw_finish_stat(rect: Rect2, label: String, value: String, color: Color) -> void:
	draw_rect(rect, Color("#182450")); draw_rect(rect, Color(color, 0.55), false, 3.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 34), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color("#cbbaff"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 83), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30, color)
