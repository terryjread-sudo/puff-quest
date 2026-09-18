import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../', import.meta.url);
const read = file => fs.readFileSync(new URL(file, root), 'utf8');
const project = read('project.godot');
const scene = read('main.tscn');
const game = read('main.gd');

assert.match(project, /config\/name="Neon Twice"/);
assert.match(project, /run\/main_scene="res:\/\/main\.tscn"/);
assert.match(scene, /script = ExtResource/);
assert.match(game, /const BPM := 120\.0/);
assert.match(game, /func _start_quiz/);
assert.match(game, /func _answer_quiz/);
assert.match(game, /quiz_choices/);
assert.match(game, /InputEventScreenTouch/);
assert.match(game, /func _fill_music/);
assert.match(game, /0\.26 if quiz_active else 1\.0/);
assert.doesNotMatch(game, /Puff Quest|Puffo|Meadow/);

console.log('Neon Twice static checks passed.');

