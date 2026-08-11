extends Control

## 拍に合わせて一瞬だけ拡大し、元の大きさへ戻す部品。
##
## 拍動させたい Control へ付けるだけでよい。軸は自分の中心へ自動で合う。
##
## **他のUIを抱えたものへ付けてはいけない。** 層ごと拡大されるので、中の配置が
## まとめて動く。画面いっぱいの入れ物へ付けて、ロゴも釦も画面の中心を軸に
## 動いてしまった例がある。1枚の絵や1つの釦へ付ける。

const SCALE := preload("gmorn_beat_scale.gd")

var beat_scale := Vector2.ONE

func _ready() -> void:
	add_to_group(SCALE.GROUP)
	_update_pivot()
	resized.connect(_update_pivot)

## 拍が来たときに呼ばれる。
func pulse() -> void:
	beat_scale = SCALE.adjusted_aim(size)
	scale = beat_scale

func _process(delta: float) -> void:
	if beat_scale.is_equal_approx(Vector2.ONE):
		return
	beat_scale = SCALE.lerp_back(beat_scale, delta)
	scale = beat_scale

func _update_pivot() -> void:
	pivot_offset = size / 2.0
