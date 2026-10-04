extends PanelContainer

signal data_changed(key, value)
signal close(node_self, key)

onready var _label = $VBoxContainer/Label
onready var _icon = $VBoxContainer/HBoxContainer/Icon
onready var _increase_button = $VBoxContainer/HBoxContainer/increase
onready var _reduce_button = $VBoxContainer/HBoxContainer/reduce
onready var _not_button = $VBoxContainer/HBoxContainer/NOT
onready var _cancel_button = $VBoxContainer/HBoxContainer/cancel

var stat_key:String

# 位1：增加
# 位2：减少
var filter_stat_value:int = 0

func set_stat(key:String, title:String, value:int = 3):
	_label.text = title
	if title == "CURRENT_LEVEL":
		_icon.texture = load("res://items/upgrades/upgrade_icon.png")
	else:
		_icon.texture = ItemService.get_stat_small_icon(Keys.generate_hash(key.to_lower()))
	stat_key = key
	filter_stat_value = value
	set_button(value)


func set_button(value:int):
	_increase_button.set_pressed_no_signal(bool(value & 1))
	_reduce_button.set_pressed_no_signal(bool(value & 2))




func _on_increase_toggled(button_pressed):
	if button_pressed:
		filter_stat_value |= 1
	else:
		filter_stat_value &= 2
	emit_signal("data_changed", stat_key, filter_stat_value)


func _on_reduce_toggled(button_pressed):
	if button_pressed:
		filter_stat_value |= 2
	else:
		filter_stat_value &= 1
	emit_signal("data_changed", stat_key, filter_stat_value)


func _on_cancel_pressed():
	emit_signal("close", self, stat_key)


func _on_NOT_pressed():
	filter_stat_value = ~filter_stat_value
	filter_stat_value &= 3
	set_button(filter_stat_value)
	
	emit_signal("data_changed", stat_key, filter_stat_value)


func _on_NOT_mouse_entered():
	_not_button.grab_focus()


func _on_cancel_mouse_entered():
	_cancel_button.grab_focus()
