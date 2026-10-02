# GMornBeat

## 概要

鳴っている曲の位置から拍を刻み、UIを拍で拍動させるGodotアドオン。

拍を経過時間で数えると、曲と絵が少しずつ離れていく。この部品は再生位置を毎回読んで何拍目かを求めるので、長く鳴らしても離れない。曲の繰り返しも跨いで数え続ける。

## 動作環境

- Godot 4.x（4.7で確認）
- 拍の元にする `AudioStreamPlayer` が1つ

画面のない実行（`--headless`）では拍動しない。見えないものを動かす意味が無く、音声も鳴っていないことが多いため。

## 何ができるか

- **曲の位置から拍を数える**。経過時間ではないので、長く鳴らしても曲と離れない。
- **出力の遅れを差し引く**。耳に届いている音は再生位置より遅れの分だけ前の音である。差し引かないと絵が音より先に動いて見える。
- **こま送りのずれを散らす**。こま単位でしか見られないため、境目を跨いだ気付きは必ず後になる。半こま先を見て判断し、遅れと早まりを半分ずつに分ける。実測では、そのまま出すと毎回 +7〜+18ms 遅れていたものが平均 -0.6ms になった。
- **繰り返しを跨いで数え続ける**。位置が戻ったら曲の長さを足す。足さないと繰り返すたびに拍の番号が戻り、そこで拍動が飛ぶ。
- **付けるだけで拍動する部品**。`gmorn_beat_scaler.gd` を Control へ付ける。軸は自分の中心へ自動で合う。

## 使い方

### 1. 取り込む

アドオン一式をリポジトリ直下へ置いてある。取り込む側の `addons/gmorn_beat` へそのまま submodule として足せる。

```
git submodule add https://github.com/TsukumiStudio/GMornBeat.git addons/gmorn_beat
```

Godotのエディタで「プロジェクト設定 → プラグイン」から `GMornBeat` を有効にする。自動読み込みへ `GMornBeat` が登録される。

**リポジトリ直下に `project.godot` は置かない。** 置くとGodotがそこを別のプロジェクトと見なし、**そのフォルダを丸ごとスキャンから外す**。submoduleとして取り込んだ場合、エディタでは動くのに書き出した実行ファイルにだけアドオンが入らない。気づきにくいので置かないこと。

### 2. 拍の元を教える

```gdscript
func _ready() -> void:
    var beat := get_node_or_null("/root/GMornBeat")
    if beat == null:
        return
    beat.set_source(bgm_player)     # 鳴らしている再生ノード
    beat.set_tempo(90.0, 8)         # BPM と 1小節の分割数
```

**再生ノードを作った後で渡す。** まだ `null` の変数を渡すと、拍は曲の位置ではなく経過時間で刻まれる。速さは合ったままなので拍動は動いて見え、**位相だけが黙ってずれる**。実際に、再生ノードを組み立てる前に `set_source()` を呼んでいて0.20秒ぶん先行した例がある。渡し忘れたときは `push_error` で声を上げる。つないだ先は `beat.source()` で外から確かめられる。

曲を差し替えたら、速さを教え直して数え直す。

```gdscript
beat.set_tempo(140.0, 16)
beat.reset()
```

### 3. 拍動させる

拍動させたい Control へ `gmorn_beat_scaler.gd` を付ける。それだけでよい。

自前で描く釦のように、スクリプトを付け替えられないものは、群れへ入れて `pulse()` を実装する。

```gdscript
func _ready() -> void:
    add_to_group(&"gmorn_beat_scaler")

func pulse() -> void:
    scale = Vector2(1.1, 1.1)   # 戻す処理は自分で持つ
```

**他のUIを抱えたものへ付けてはいけない。** 層ごと拡大されるので、中の配置がまとめて動く。画面いっぱいの入れ物へ付けて、ロゴも釦も画面の中心を軸に動いてしまった例がある。1枚の絵や1つの釦へ付ける。

### 4. 打つ間隔を決める

`ticks_per_pulse` で決める。刻み何つぶんで1回打つか。

```gdscript
beat.ticks_per_pulse = 4    # 1小節8分割なら半小節ごと
```

1拍ごとに打つと、曲によっては忙しく見える。半小節ごと（`ticks_per_pulse` が分割数の半分）が落ち着く。

### その他の口

| 呼び出し | 何をするか |
| --- | --- |
| `beat`（シグナル） | 拍を打つたびに出る。引数は数え始めからの通し番号 |
| `clock()` | 数え始めからの経過（秒）。繰り返しを跨いでも増え続ける |
| `index()` | いま何回目の拍か |
| `tick_duration()` | 刻み1つの長さ（秒） |
| `pulse_duration()` | 打つ間隔（秒） |

## Authored beat override API

An external beat source can temporarily take ownership of UI pulse timing while
GMornBeat continues to maintain its normal music clock and `beat` signal. This is
useful when a score, sequencer, or other authored timeline has pulse positions
that do not follow the regular tempo grid.

Register each source for its active lifetime and keep the returned token:

```gdscript
var override_token := 0

func begin_authored_pulses() -> void:
    override_token = GMornBeat.register_override_beat()

func publish_authored_pulse(source_tick: int) -> void:
    if override_token != 0:
        GMornBeat.notify_override_beat(override_token, source_tick)

func end_authored_pulses() -> void:
    if override_token != 0:
        GMornBeat.unregister_override_beat(override_token)
        override_token = 0
```

| API | Contract |
| --- | --- |
| `register_override_beat() -> int` | Returns a positive owner token. Tokens are never reused during the node's lifetime. Multiple owners may be active together. |
| `unregister_override_beat(token) -> bool` | Cancels that owner. Returns `false` for an unknown or already-cancelled token. Regular UI pulses resume after the final owner cancels. |
| `notify_override_beat(token, source_tick) -> bool` | Emits `override_beat(source_tick)` and requests one UI pulse. Returns `false` for a stale token or a negative tick. |
| `is_overriding_beat() -> bool` | Reports whether at least one owner is registered. |
| `override_beat(source_tick)` | Signal emitted for an accepted authored pulse. It is emitted even when UI pulses are disabled in project settings. |

While any owner is registered, regular clock updates and the regular `beat`
signal continue unchanged; only the regular UI-group `pulse()` call is
suppressed. Accepted authored notifications use that same UI pulse route. The
`gmorn_beat/ui_pulse_enabled` setting controls both regular and authored UI
pulses, but it does not suppress either signal and does not change `clock()` or
`index()`.

Always unregister when the source stops or is replaced. A cancelled token stays
invalid, so a callback retained by an earlier source lifetime cannot publish in
a later one. Each owner must cancel its own token; cancelling one owner does not
affect other active owners.

`tests/test_override_beat.gd` is a standalone pure-logic contract test for this
API. It covers multiple owners, cancellation, stale tokens, regular signal
continuity, UI-only switching, and unchanged music-clock state without starting
audio or rendering.

### 手を入れる

`verify.sh` で、拍の計算と拍動の割り当てが通ることを確かめられる。一時の置き場へ最小のプロジェクトを作り、この部品を写して回す。

```
./verify.sh
```

## ライセンス

Unlicense（パブリックドメイン）。

## UI拍動のON/OFF

「プロジェクト設定 → GMorn Beat → UI Pulse Enabled」で一括切り替えする。
保存キーは `gmorn_beat/ui_pulse_enabled`。アドオンの既定値はON（未設定時もON）。
OFFにしても時計の更新と `beat` シグナルは続き、UIグループへの `pulse()` だけを停止する。
個別UIのscalerや `beat_scale_enabled` は有効のまま使う。
設定変更後、次のゲーム実行に反映される。実行中に `ProjectSettings.set_setting()` で変更した場合も次の拍から反映する。
既に拡大しているUIは通常の補間で元のサイズへ戻る。
