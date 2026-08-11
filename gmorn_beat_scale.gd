extends RefCounted

## 拍動の拡大量を決める。
##
## 短辺を基準に比率を補正し、縦横で同じ画素だけ広がるようにする。補正しないと、
## 横長のものは横だけが大きく伸びて形が崩れる。例えば 440x200 の釦なら短辺200が
## 基準になり、横は控えめに、縦は指定どおり広がる。

## 拍動するものが入る群れ。
const GROUP := &"gmorn_beat_scaler"
## 打った瞬間の大きさ。
const AIM_SCALE := 1.1
## 元へ戻る速さ。
const LERP_SPEED := 10.0

static func adjusted_aim(size: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(AIM_SCALE, AIM_SCALE)
	var min_side := minf(size.x, size.y)
	var growth := AIM_SCALE - 1.0
	return Vector2(1.0 + growth * min_side / size.x, 1.0 + growth * min_side / size.y)

static func lerp_back(current: Vector2, delta: float) -> Vector2:
	return current.lerp(Vector2.ONE, minf(1.0, delta * LERP_SPEED))
