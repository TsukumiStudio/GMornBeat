extends SceneTree
## Standalone logic contract for authored beat overrides. This test does not
## start audio, advance the process clock, create a renderer, or require a GPU.

const Beat = preload("res://addons/gmorn_beat/gmorn_beat.gd")

var checks := 0
var failures: Array[String] = []
var regular_beats: Array[int] = []
var authored_beats: Array[int] = []


class PulseProbe extends Node:
	var pulse_count := 0

	func pulse() -> void:
		pulse_count += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var beat: Node = Beat.new()
	var probe := PulseProbe.new()
	root.add_child(beat)
	root.add_child(probe)
	beat.set_process(false)
	probe.add_to_group(beat.GROUP)
	beat.beat.connect(func(index: int) -> void: regular_beats.append(index))
	beat.override_beat.connect(func(source_tick: int) -> void:
		authored_beats.append(source_tick))
	var setting_existed := ProjectSettings.has_setting(beat.UI_PULSE_SETTING)
	var saved_setting: Variant = ProjectSettings.get_setting(beat.UI_PULSE_SETTING, true)
	ProjectSettings.set_setting(beat.UI_PULSE_SETTING, true)
	var clock_before: float = beat.clock()
	var index_before: int = beat.index()

	beat._notify_regular_beat(1)
	_check(regular_beats == [1], "regular beat signal is emitted without an override")
	_check(probe.pulse_count == 1, "regular beat pulses the UI without an override")

	var first: int = beat.register_override_beat()
	var second: int = beat.register_override_beat()
	_check(first > 0 and second > first, "registrations return positive non-reused tokens")
	_check(beat.is_overriding_beat(), "multiple active registrations enable override mode")
	beat._notify_regular_beat(2)
	_check(regular_beats == [1, 2], "override mode preserves the regular beat signal")
	_check(probe.pulse_count == 1, "override mode suppresses only regular UI pulses")

	_check(beat.notify_override_beat(first, 12), "the first owner can publish an authored beat")
	_check(authored_beats == [12] and probe.pulse_count == 2,
		"an authored beat emits its signal and one UI pulse")
	_check(beat.unregister_override_beat(first), "the first owner can cancel its registration")
	_check(beat.is_overriding_beat(), "one remaining owner keeps override mode active")
	_check(not beat.unregister_override_beat(first)
		and not beat.notify_override_beat(first, 24),
		"a cancelled token cannot cancel or publish again")
	_check(not beat.notify_override_beat(second, -1),
		"a negative source tick is rejected without publishing")

	ProjectSettings.set_setting(beat.UI_PULSE_SETTING, false)
	_check(beat.notify_override_beat(second, 36),
		"the UI preference does not disable the authored beat signal")
	_check(authored_beats == [12, 36] and probe.pulse_count == 2,
		"disabled UI pulses leave the authored signal intact")
	_check(beat.unregister_override_beat(second) and not beat.is_overriding_beat(),
		"cancelling the final owner restores regular pulse eligibility")

	ProjectSettings.set_setting(beat.UI_PULSE_SETTING, true)
	beat._notify_regular_beat(3)
	_check(regular_beats == [1, 2, 3] and probe.pulse_count == 3,
		"regular UI pulses resume after the final cancellation")
	_check(beat.clock() == clock_before and beat.index() == index_before,
		"register, publish, and cancel never mutate the music clock or index")

	var next_visit: int = beat.register_override_beat()
	_check(next_visit > second and not beat.notify_override_beat(second, 48),
		"a later registration never revives a stale token")
	_check(beat.notify_override_beat(next_visit, 48)
		and authored_beats == [12, 36, 48],
		"the current registration remains usable after stale-token rejection")
	_check(beat.unregister_override_beat(next_visit) and not beat.is_overriding_beat(),
		"the later owner can cancel cleanly")
	_check(beat.clock() == clock_before and beat.index() == index_before,
		"the complete override lifecycle leaves music-clock state unchanged")

	if setting_existed:
		ProjectSettings.set_setting(beat.UI_PULSE_SETTING, saved_setting)
	else:
		ProjectSettings.clear(beat.UI_PULSE_SETTING)
	probe.free()
	beat.free()
	var report: Dictionary = {
		"suite":"gmorn_beat_override_public_api",
		"passed":failures.is_empty(),
		"checks":checks,
		"failures":failures,
		"standalone_logic":true,
		"audio_verified":false,
		"render_verified":false,
		"gpu_verified":false,
	}
	print(JSON.stringify(report))
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
