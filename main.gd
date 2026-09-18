extends Node2D

const VIEW := Vector2(1280.0, 720.0)
const FLOOR_Y := 585.0
const PLAYER_SIZE := Vector2(46.0, 46.0)
const BPM := 120.0
const BEAT := 60.0 / BPM
const RUN_SPEED := 360.0
const GRAVITY := 1900.0
const JUMP_VELOCITY := -720.0
const DASH_SPEED := 920.0
const DASH_TIME := 0.20
const LEVEL_END := 9200.0

var player := Vector2(150.0, FLOOR_Y - PLAYER_SIZE.y)
var velocity := Vector2.ZERO
var camera_x := 0.0
var started := false
var finished := false
var paused := false
var dash_left := 0.0
var dash_cooldown := 0.0
var jump_buffer := 0.0
var coyote := 0.0
var beat_clock := 0.0
var run_time := 0.0
var quiz_active := false
var quiz_time := 0.0
var quiz_number := 0
var quiz_choices: Array[int] = []
var quiz_correct_index := 0
var quiz_index := -1
var next_quiz := 0
var quiz_points := 0
var combo := 0
var best_combo := 0
var score := 0
var distance := 0.0
var checkpoints := [0.0, 3200.0, 6400.0]
var checkpoint_index := 0
var stars: Array[Vector2] = []
var obstacles: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var flash := 0.0
var message := ""
var message_time := 0.0
var rng := RandomNumberGenerator.new()
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var music_phase := 0.0
var music_sample_clock := 0.0
var audio_enabled := true

func _ready() -> void:
	rng.seed = 20260918
	_build_level()
	_setup_music()
	queue_redraw()

func _build_level() -> void:
	# Every entry is authored on the same 120 BPM grid as the music.
	obstacles.clear()
	stars.clear()
	for beat in range(2, 184):
		var x := 150.0 + beat * RUN_SPEED * BEAT
		if beat % 7 == 0 or beat % 11 == 0:
			obstacles.append({"rect": Rect2(x, FLOOR_Y - 54.0, 40.0, 54.0), "kind": "spike"})
		if beat % 13 == 0:
			obstacles.append({"rect": Rect2(x + 120.0, FLOOR_Y - 82.0, 42.0, 82.0), "kind": "tall"})
		if beat % 17 == 0:
			obstacles.append({"rect": Rect2(x + 220.0, FLOOR_Y - 34.0, 90.0, 34.0), "kind": "block"})
		if beat % 5 == 0:
			stars.append(Vector2(x + 65.0, FLOOR_Y - (120.0 if beat % 10 == 0 else 78.0)))
	for x in [150.0 + 31.0 * RUN_SPEED * BEAT, 150.0 + 67.0 * RUN_SPEED * BEAT, 150.0 + 105.0 * RUN_SPEED * BEAT]:
		stars.append(Vector2(x, FLOOR_Y - 150.0))

func _setup_music() -> void:
	# Original procedural synth loop: no third-party code or asset is required.
	music_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 2.0
	music_player.stream = stream
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
	var real_delta := min(delta, 0.05)
	if message_time > 0.0:
		message_time -= real_delta
	if flash > 0.0:
		flash -= real_delta
	_update_particles(real_delta)
	_fill_music(real_delta)
	if not started or finished or paused:
		queue_redraw()
		return
	if quiz_active:
		_quiz_step(real_delta)
	else:
		_run_step(real_delta)
	queue_redraw()

func _run_step(delta: float) -> void:
	var slow := 1.0
	run_time += delta
	beat_clock = fmod(run_time, BEAT)
	distance = player.x
	var was_grounded := _is_grounded()
	if was_grounded:
		coyote = 0.10
	else:
		coyote = max(0.0, coyote - delta)
	jump_buffer = max(0.0, jump_buffer - delta)
	dash_cooldown = max(0.0, dash_cooldown - delta)
	if dash_left > 0.0:
		dash_left -= delta
		velocity = Vector2(DASH_SPEED, 0.0)
	else:
		velocity.x = RUN_SPEED
		velocity.y += GRAVITY * delta
		if jump_buffer > 0.0 and (was_grounded or coyote > 0.0):
			velocity.y = JUMP_VELOCITY
			jump_buffer = 0.0
			coyote = 0.0
			_combo_event("JUMP")
	player += velocity * delta * slow
	if player.y + PLAYER_SIZE.y >= FLOOR_Y:
		player.y = FLOOR_Y - PLAYER_SIZE.y
		velocity.y = 0.0
	if player.y > VIEW.y + 160.0:
		_crash("MISSED THE PLATFORM")
	_collect_stars()
	_check_obstacles()
	_check_quiz_gate()
	for i in range(checkpoints.size()):
		if player.x >= checkpoints[i]:
			checkpoint_index = i
	if player.x >= LEVEL_END:
		_finish()
	camera_x = clamp(player.x - 250.0, 0.0, LEVEL_END - VIEW.x + 150.0)

func _quiz_step(delta: float) -> void:
	quiz_time -= delta
	# The world continues in dramatic slow motion while the player answers.
	player.x += RUN_SPEED * delta * 0.24
	player.y = min(player.y, FLOOR_Y - PLAYER_SIZE.y)
	camera_x = clamp(player.x - 250.0, 0.0, LEVEL_END - VIEW.x + 150.0)
	if quiz_time <= 0.0:
		_answer_quiz(-1)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		if finished:
			_restart_run()
			return
		if not started:
			started = true
			message = "FIND THE BEAT"
			message_time = 1.5
		elif quiz_active:
			_answer_quiz(0)
		else:
			jump_buffer = 0.12
	if event.is_action_pressed("dash"):
		if not started:
			started = true
		elif not quiz_active:
			_start_dash()
	if event is InputEventKey and event.pressed and not event.echo and quiz_active:
		if event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_answer_quiz(event.keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		if quiz_active:
			var choice := _quiz_choice_at(event.position)
			if choice >= 0:
				_answer_quiz(choice)
		elif event.position.y > VIEW.y * 0.68:
			if event.position.x < VIEW.x * 0.55:
				jump_buffer = 0.12
			else:
				_start_dash()
	if event is InputEventScreenTouch and event.pressed:
		if quiz_active:
			var touch_choice := _quiz_choice_at(event.position)
			if touch_choice >= 0:
				_answer_quiz(touch_choice)
		elif event.position.y > VIEW.y * 0.62:
			if event.position.x < VIEW.x * 0.55:
				jump_buffer = 0.12
			else:
				_start_dash()
	if event.is_action_pressed("ui_cancel") and started:
		paused = not paused

func _restart_run() -> void:
	player = Vector2(150.0, FLOOR_Y - PLAYER_SIZE.y)
	velocity = Vector2.ZERO
	camera_x = 0.0
	started = true
	finished = false
	paused = false
	quiz_active = false
	quiz_index = -1
	next_quiz = 0
	checkpoint_index = 0
	combo = 0
	score = 0
	quiz_points = 0
	checkpoint_index = 0
	run_time = 0.0
	beat_clock = 0.0
	message = "FIND THE BEAT"
	message_time = 1.5
	_build_level()

func _start_dash() -> void:
	if dash_cooldown > 0.0 or dash_left > 0.0:
		return
	dash_left = DASH_TIME
	dash_cooldown = BEAT * 2.0
	velocity = Vector2(DASH_SPEED, 0.0)
	_combo_event("DASH")
	_spawn_burst(player + PLAYER_SIZE * 0.5, Color("#f2d35e"), 12)

func _check_quiz_gate() -> void:
	var gates := [2200.0, 4700.0, 7200.0]
	if next_quiz < gates.size() and player.x >= gates[next_quiz]:
		_start_quiz(next_quiz)

func _start_quiz(index: int) -> void:
	quiz_active = true
	quiz_index = index
	next_quiz += 1
	quiz_time = 3.2
	quiz_number = rng.randi_range(1, 12)
	var correct := quiz_number * 2
	quiz_choices = [correct, correct + rng.randi_range(1, 3), max(2, correct - rng.randi_range(1, 3))]
	quiz_choices.shuffle()
	quiz_correct_index = quiz_choices.find(correct)
	message = "TIME SHIFT"
	message_time = 1.0
	_spawn_burst(player + PLAYER_SIZE * 0.5, Color("#7cf5ff"), 22)

func _answer_quiz(choice: int) -> void:
	if not quiz_active:
		return
	var correct := choice == quiz_correct_index
	quiz_active = false
	if correct:
		quiz_points += 1
		score += 250
		_combo_event("SOLVED")
		message = "CORRECT  +250"
	else:
		combo = 0
		message = "WRONG  KEEP RUNNING"
	message_time = 1.6
	flash = 0.25

func _quiz_choice_at(pos: Vector2) -> int:
	for i in range(3):
		var rect := Rect2(210.0 + i * 290.0, 440.0, 250.0, 100.0)
		if rect.has_point(pos):
			return i
	return -1

func _check_obstacles() -> void:
	var body := Rect2(player, PLAYER_SIZE)
	for obstacle in obstacles:
		var rect: Rect2 = obstacle.rect
		if rect.position.x > player.x + 300.0 or rect.end.x < player.x - 100.0:
			continue
		if body.intersects(rect):
			if dash_left > 0.0:
				score += 40
				_spawn_burst(rect.position + rect.size * 0.5, Color("#ff698f"), 14)
				obstacle.rect = Rect2(-10000, -10000, 0, 0)
			else:
				_crash("HIT THE BEAT WALL")
			return

func _collect_stars() -> void:
	for i in range(stars.size() - 1, -1, -1):
		if stars[i].distance_to(player + PLAYER_SIZE * 0.5) < 48.0:
			score += 75
			_combo_event("STAR")
			_spawn_burst(stars[i], Color("#f5e27e"), 10)
			stars.remove_at(i)

func _crash(reason: String) -> void:
	combo = 0
	flash = 0.35
	message = reason
	message_time = 1.2
	player = Vector2(150.0 + checkpoints[checkpoint_index], FLOOR_Y - PLAYER_SIZE.y)
	velocity = Vector2.ZERO
	dash_left = 0.0
	next_quiz = 0
	for gate in [2200.0, 4700.0, 7200.0]:
		if gate <= player.x:
			next_quiz += 1

func _finish() -> void:
	finished = true
	message = "RUN COMPLETE"
	message_time = 99.0
	_spawn_burst(player + PLAYER_SIZE * 0.5, Color("#7cf5ff"), 50)

func _is_grounded() -> bool:
	return player.y + PLAYER_SIZE.y >= FLOOR_Y - 1.0

func _combo_event(label: String) -> void:
	var beat_error := min(beat_clock, BEAT - beat_clock)
	var perfect: bool = beat_error < 0.075
	combo += 1
	best_combo = max(best_combo, combo)
	score += (50 if perfect else 20) + combo * 2
	message = ("PERFECT " if perfect else "GOOD ") + label
	message_time = 0.55
	if perfect:
		_spawn_burst(player + PLAYER_SIZE * 0.5, Color("#7cf5ff"), 5)

func _spawn_burst(origin: Vector2, color: Color, count: int) -> void:
	for i in count:
		particles.append({"p": origin, "v": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(40.0, 220.0), "life": rng.randf_range(0.25, 0.7), "color": color})

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i].p += particles[i].v * delta
		particles[i].v *= 0.94
		particles[i].life -= delta
		if particles[i].life <= 0.0:
			particles.remove_at(i)

func _fill_music(delta: float) -> void:
	if music_playback == null or not audio_enabled:
		return
	var frames := music_playback.get_frames_available()
	var pitch := 0.26 if quiz_active else 1.0
	var frames_to_make := min(frames, int(44100.0 * delta * 1.5) + 128)
	for i in frames_to_make:
		var t := music_sample_clock / 44100.0
		var beat_position := t * BPM / 60.0 * pitch
		var beat_fraction := fmod(beat_position, 1.0)
		var beat_index := int(floor(beat_position)) % 8
		var kick := exp(-beat_fraction * 22.0) * (0.35 if beat_index % 2 == 0 else 0.0)
		var hat := exp(-beat_fraction * 55.0) * (0.11 if beat_index % 2 == 1 else 0.04)
		var note: float = float([55.0, 55.0, 65.41, 73.42, 82.41, 73.42, 65.41, 49.0][beat_index])
		var bass := sin(TAU * note * t) * 0.13
		var arp := sin(TAU * note * 4.0 * t) * 0.045
		var sample := clamp(kick + hat + bass + arp, -0.8, 0.8)
		music_playback.push_frame(Vector2(sample, sample * 0.96))
		music_sample_clock += 1.0

func _draw() -> void:
	_draw_background()
	_draw_world()
	_draw_hud()
	if not started:
		_draw_title()
	if quiz_active:
		_draw_quiz()
	if finished:
		_draw_finish()
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(1.0, 0.35, 0.5, flash * 0.35))

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#0b102b"))
	for band in range(9):
		var c := Color("#111a3d").lerp(Color("#281b55"), float(band) / 9.0)
		draw_rect(Rect2(0, band * 80, VIEW.x, 82), c)
	for x in range(-100, 1500, 100):
		var sx := fmod(x - camera_x * 0.15, 1500.0)
		draw_line(Vector2(sx, 0), Vector2(sx - 260, VIEW.y), Color(0.3, 0.5, 0.9, 0.08), 1.0)
	for y in range(80, 600, 80):
		draw_line(Vector2(0, y), Vector2(VIEW.x, y), Color(0.3, 0.5, 0.9, 0.09), 1.0)
	var pulse := 0.5 + 0.5 * cos((run_time / BEAT) * TAU)
	draw_circle(Vector2(1040, 170), 110.0 + pulse * 20.0, Color(0.2, 0.8, 1.0, 0.04))

func _draw_world() -> void:
	var floor_screen := FLOOR_Y
	draw_rect(Rect2(0, floor_screen, VIEW.x, VIEW.y - floor_screen), Color("#151b3d"))
	for x in range(-100, 1500, 80):
		var sx := fmod(x - camera_x, 1600.0)
		draw_line(Vector2(sx, floor_screen), Vector2(sx - 70, VIEW.y), Color("#28346a"), 2.0)
	for star in stars:
		var p := star - Vector2(camera_x, 0)
		if p.x > -30 and p.x < VIEW.x + 30:
			var glow := 0.5 + 0.5 * sin(run_time * 7.0 + star.x)
			draw_circle(p, 13.0 + glow * 4.0, Color(0.96, 0.86, 0.35, 0.15))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -13), p + Vector2(7, 0), p + Vector2(0, 13), p + Vector2(-7, 0)]), Color("#f5e27e"))
	for obstacle in obstacles:
		var rect: Rect2 = obstacle.rect
		var screen := Rect2(rect.position - Vector2(camera_x, 0), rect.size)
		if screen.end.x < 0 or screen.position.x > VIEW.x:
			continue
		var color := Color("#ff638c") if obstacle.kind == "spike" else Color("#b06cff")
		draw_rect(screen, Color(color, 0.18))
		draw_rect(screen, color, false, 3.0)
		if obstacle.kind == "spike":
			for spike_x in range(int(screen.position.x) + 4, int(screen.end.x) - 4, 12):
				draw_colored_polygon(PackedVector2Array([Vector2(spike_x, floor_screen), Vector2(spike_x + 6, screen.position.y), Vector2(spike_x + 12, floor_screen)]), color)
	for particle in particles:
		draw_circle(particle.p - Vector2(camera_x, 0), 3.0 + particle.life * 4.0, Color(particle.color, particle.life))
	var pp := player - Vector2(camera_x, 0)
	var center := pp + PLAYER_SIZE * 0.5
	draw_set_transform(center, run_time * 2.0 if dash_left > 0.0 else 0.0, Vector2.ONE)
	draw_rect(Rect2(-23, -23, 46, 46), Color("#75f1ff"))
	draw_rect(Rect2(-16, -16, 32, 32), Color("#182450"))
	draw_rect(Rect2(-8, -8, 16, 16), Color("#f5e27e"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hud() -> void:
	draw_rect(Rect2(24, 20, 360, 80), Color(0.04, 0.06, 0.16, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(44, 52), "NEON TWICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#7cf5ff"))
	draw_string(ThemeDB.fallback_font, Vector2(44, 80), "SCORE %06d    COMBO x%d" % [score, combo], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 260, 46), "120 BPM  •  %s" % ("SLOWED" if quiz_active else "ON BEAT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#cbbaff"))
	draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 260, 76), "DISTANCE %04d m" % int(player.x / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#8fa8df"))
	if message_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(VIEW.x / 2 - 150, 145), message, HORIZONTAL_ALIGNMENT_CENTER, 300, 22, Color("#ffffff"))
	if not quiz_active and started and not finished:
		draw_string(ThemeDB.fallback_font, Vector2(34, VIEW.y - 30), "SPACE / TAP  JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 1.0, 0.65))
		draw_string(ThemeDB.fallback_font, Vector2(VIEW.x - 260, VIEW.y - 30), "X / TAP  DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 1.0, 0.65))

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.78))
	draw_string(ThemeDB.fallback_font, Vector2(0, 245), "NEON TWICE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 64, Color("#7cf5ff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 300), "JUMP. DASH. SOLVE THE BEAT.", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 370), "PRESS SPACE / A BUTTON / TAP TO START", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 430), "Jump over hazards • Dash through pink walls • Answer the 2× quiz", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 16, Color("#a9b8ef"))

func _draw_quiz() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.03, 0.02, 0.12, 0.60))
	draw_rect(Rect2(140, 155, 1000, 390), Color("#11183e"))
	draw_rect(Rect2(140, 155, 1000, 390), Color("#7cf5ff"), false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(0, 205), "TIME SHIFT", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, Color("#7cf5ff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 285), "2 × %d = ?" % quiz_number, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 58, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 335), "Choose fast to keep your combo alive", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 17, Color("#a9b8ef"))
	for i in range(3):
		var rect := Rect2(210.0 + i * 290.0, 440.0, 250.0, 100.0)
		draw_rect(rect, Color("#26336e"))
		draw_rect(rect, Color("#b06cff") if i != quiz_correct_index else Color("#7cf5ff"), false, 3.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 64), "%d   %d" % [i + 1, quiz_choices[i]], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 590), "TIME  %.1f" % max(0.0, quiz_time), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#ff9ab4"))

func _draw_finish() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.03, 0.10, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(0, 245), "RUN COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 54, Color("#7cf5ff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 320), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 28, Color("#f5e27e"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 365), "BEST COMBO x%d    QUIZZES %d/3" % [best_combo, quiz_points], HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 450), "PRESS SPACE TO RUN AGAIN", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color("#a9b8ef"))
