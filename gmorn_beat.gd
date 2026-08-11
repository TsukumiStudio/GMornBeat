extends Node

## 鳴っている曲の位置から拍を刻み、登録されたものを拍で拍動させる。
##
## 拍を「経過時間」で数えてはいけない。曲と絵が少しずつ離れていく。鳴っている
## 曲の再生位置を毎回読んで、そこから何拍目かを求める。
##
## 出力の遅れも差し引く。耳に届いている音は、再生位置より遅れの分だけ前の音で
## ある。差し引かないと、絵が音より先に動いて見える。
##
## 使い方は README.md を参照。おおよそ次の3つで足りる。
##
##   GMornBeat.set_source(bgm_player)         鳴らしている再生ノードを教える
##   GMornBeat.set_tempo(90.0, 8)             BPMと1小節の分割数を教える
##   GMornBeat.reset()                        曲を差し替えたら呼ぶ
##
## 拍動させたいものには `gmorn_beat_scaler.gd` を付ける。釦のように自前で
## 描くものは、`GMornBeat.GROUP` へ入れて `pulse()` を実装すれば同じ扱いになる。

const SCALE := preload("gmorn_beat_scale.gd")
## 拍動するものが入る群れ。
const GROUP := SCALE.GROUP

## 拍を打ったときに出る。`index` は数え始めからの通し番号。
signal beat(index: int)

## 1小節の分割数。譜面の刻みの細かさに合わせる。
var measure_tick := 8
## 曲の速さ。
var bpm := 90.0
## 何刻みごとに打つか。1小節8分割で4なら、半小節ごとに打つ。
var ticks_per_pulse := 4

var _player: AudioStreamPlayer
var _clock := 0.0
var _last_position := 0.0
var _elapsed_loops := 0.0
var _index := 0

func _process(delta: float) -> void:
	# 画面の無い動かし方では拍動させない。見えないものを動かす意味が無く、
	# 音声も鳴っていないことが多い。
	if DisplayServer.get_name() == "headless":
		return
	_advance(delta)
	# こま単位でしか見られないので、境目を跨いだことに気付くのは必ず後になる。
	# そのまま出すと毎回こま1枚ぶん遅れる（実測で +7〜+18ms）。半こま先を見て
	# 判断し、遅れと早まりを半分ずつに散らす。
	var next_index := floori((_clock + delta * 0.5) / pulse_duration())
	if next_index == _index:
		return
	_index = next_index
	beat.emit(next_index)
	for scaler: Node in get_tree().get_nodes_in_group(GROUP):
		if scaler.has_method("pulse"):
			scaler.call("pulse")

## 鳴らしている再生ノードを教える。曲を差し替えたら `reset()` も呼ぶ。
func set_source(player: AudioStreamPlayer) -> void:
	_player = player
	reset()

## 速さと分割数を教える。曲が変わるたびに呼ぶ。
func set_tempo(new_bpm: float, new_measure_tick: int) -> void:
	bpm = maxf(1.0, new_bpm)
	measure_tick = maxi(1, new_measure_tick)

## 数え直す。曲を差し替えたときに呼ぶ。
##
## 通し番号は -1 ではなく 0 から始める。-1 にすると、差し替えた直後の最初の
## こまで必ず1回打つ。拍の境目とは関係のない時刻なので、そこだけ拍がずれて
## 聞こえる（実測では曲の1.280秒、格子から-53msの位置で打っていた）。
func reset() -> void:
	_clock = 0.0
	_last_position = 0.0
	_elapsed_loops = 0.0
	_index = 0

## 刻み1つの長さ（秒）。
func tick_duration() -> float:
	return 60.0 / bpm * 4.0 / float(measure_tick)

## 打つ間隔（秒）。
func pulse_duration() -> float:
	return float(ticks_per_pulse) * tick_duration()

## 数え始めからの経過（秒）。曲の繰り返しを跨いでも増え続ける。
func clock() -> float:
	return _clock

## いま何回目の拍か。
func index() -> int:
	return _index

## 曲の位置から時計を進める。鳴っていなければ経過時間で進める。
##
## 繰り返しで位置が戻ったときは、曲の長さを足して数え続ける。足さないと、
## 繰り返すたびに拍の番号が戻り、そこで拍動が飛ぶ。
func _advance(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.playing:
		_clock += delta
		return
	var position := _audio_position()
	if position + 0.1 < _last_position:
		_elapsed_loops += _loop_length(_last_position)
	_last_position = position
	_clock = _elapsed_loops + position

## いま耳に届いている音の位置。
##
## 再生位置は前回の混ぜ込み時点の値なので、そこからの経過を足す。出力の遅れは
## 差し引く。差し引かないと絵が音より先に動く。
func _audio_position() -> float:
	var position := _player.get_playback_position()
	position += AudioServer.get_time_since_last_mix()
	position -= AudioServer.get_output_latency()
	return maxf(0.0, position)

func _loop_length(last_position: float) -> float:
	if _player.stream == null:
		return last_position
	var length := _player.stream.get_length()
	return length if length > 0.0 else last_position
