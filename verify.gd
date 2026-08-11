extends SceneTree

## 拍の計算と拍動の割り当てが通ることを確かめる。
##
## 音は鳴らさない。鳴らさなくても、速さと分割数から求まる長さと、群れへの
## 割り当ては確かめられる。

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var beat_script: GDScript = load("res://addons/gmorn_beat/gmorn_beat.gd")
	var beat: Node = beat_script.new()
	root.add_child(beat)
	await process_frame

	# 刻みと打つ間隔。90BPM・1小節8分割なら刻みは0.3333秒、4刻みで1.3333秒。
	beat.set_tempo(90.0, 8)
	beat.ticks_per_pulse = 4
	assert(is_equal_approx(beat.tick_duration(), 60.0 / 90.0 * 4.0 / 8.0),
		"刻みの長さが %.4f 秒" % beat.tick_duration())
	assert(absf(beat.pulse_duration() - 1.33333) < 0.001,
		"打つ間隔が %.4f 秒" % beat.pulse_duration())

	# 分割が細かくなれば刻みも短くなる。
	beat.set_tempo(140.0, 16)
	assert(absf(beat.tick_duration() - 60.0 / 140.0 * 4.0 / 16.0) < 0.0001,
		"分割16の刻みが %.4f 秒" % beat.tick_duration())

	# 数え直すと通し番号は0から。-1にすると差し替えた直後に1回余計に打つ。
	beat.reset()
	assert(beat.index() == 0, "数え直しても %d のまま" % beat.index())
	assert(is_zero_approx(beat.clock()), "時計が戻っていない")

	# 拍動するものは群れで拾う。付けるだけで入ること。
	var scaler_script: GDScript = load("res://addons/gmorn_beat/gmorn_beat_scaler.gd")
	var scaler: Control = scaler_script.new()
	scaler.size = Vector2(440.0, 200.0)
	root.add_child(scaler)
	await process_frame
	assert(scaler.is_in_group(beat.GROUP), "付けても群れに入らない")
	# 軸は自分の中心。ずれていると拡大しながら横へ滑る。
	assert(scaler.pivot_offset.is_equal_approx(scaler.size / 2.0),
		"軸が %s（中心は %s）" % [str(scaler.pivot_offset), str(scaler.size / 2.0)])

	# 短辺を基準に補正する。横長のものが横だけ伸びると形が崩れる。
	scaler.pulse()
	var grew := scaler.scale
	assert(grew.x > 1.0 and grew.y > 1.0, "拡大していない: %s" % str(grew))
	assert(grew.x < grew.y, "横長なのに横の方が大きく伸びている: %s" % str(grew))
	var scale_script: GDScript = load("res://addons/gmorn_beat/gmorn_beat_scale.gd")
	var expected: Vector2 = scale_script.adjusted_aim(scaler.size)
	assert(grew.is_equal_approx(expected), "拡大量が計算と合わない")

	# 放っておけば元へ戻る。
	for _step in 200:
		await process_frame
		if scaler.scale.is_equal_approx(Vector2.ONE):
			break
	assert(scaler.scale.distance_to(Vector2.ONE) < 0.01,
		"元へ戻らない: %s" % str(scaler.scale))

	print("刻み=%.4f秒 打つ間隔=%.4f秒" % [beat.tick_duration(), beat.pulse_duration()])
	print("GMORN BEAT VERIFY: PASS")
	quit(0)
