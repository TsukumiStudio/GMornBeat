@tool
extends EditorPlugin

## GMornBeat を組み込むための入口。
##
## 拍を数えるものは常駐させたいので、自動読み込みに登録する。

const AUTOLOAD_NAME := "GMornBeat"
const BEAT := preload("gmorn_beat.gd")

## 置き場所を決め打ちにしない。submodule で好きな名前の場所へ入れられるように、
## 自分の居場所から辿る。
func _autoload_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("gmorn_beat.gd")

func _enter_tree() -> void:
	if not ProjectSettings.has_setting(BEAT.UI_PULSE_SETTING):
		ProjectSettings.set_setting(BEAT.UI_PULSE_SETTING, true)
	ProjectSettings.set_initial_value(BEAT.UI_PULSE_SETTING, true)
	ProjectSettings.add_property_info({"name": BEAT.UI_PULSE_SETTING, "type": TYPE_BOOL})
	ProjectSettings.set_as_basic(BEAT.UI_PULSE_SETTING, true)
	# 既に登録済みなら足さない。毎回足すとエディタの起動ごとに「自動読み込みを追加」の
	# 履歴が（アドオンの数だけ）並ぶ。project.godot に書いてあれば、それで動く。
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, _autoload_path())

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
