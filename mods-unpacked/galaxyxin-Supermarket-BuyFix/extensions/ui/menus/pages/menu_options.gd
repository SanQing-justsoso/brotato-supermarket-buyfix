extends "res://ui/menus/pages/menu_options.gd"


# 原版bug修复: 合作模式且当前场景没有 FocusEmulator1 (如波次内的 main 场景)时,
# 原版 init() L118 对 Utils.get_focus_emulator(0) 返回的 null 取 player_index 导致崩溃。
# 方案: init 前临时挂一个兜底 FocusEmulator1, init 结束后立即移除。
func init() -> void :
	var ekjg_dummy: FocusEmulator = null
	if RunData.is_coop_run and Utils.get_focus_emulator(0) == null:
		ekjg_dummy = FocusEmulator.new()
		ekjg_dummy.name = "FocusEmulator1"
		ekjg_dummy.focus_base_data = []
		Utils.get_scene_node().add_child(ekjg_dummy)
		ekjg_dummy.player_index = 0
	.init()
	if ekjg_dummy != null:
		Utils.get_scene_node().remove_child(ekjg_dummy)
		ekjg_dummy.queue_free()


# 兜底场景下 focus_before_created 可能为 null/不可见, 原版直接 grab_focus 会再崩一次
func _on_BackButton_pressed() -> void :
	if focus_before_created == null or not is_instance_valid(focus_before_created) or not focus_before_created.is_visible_in_tree():
		emit_signal("back_button_pressed")
		return
	._on_BackButton_pressed()
