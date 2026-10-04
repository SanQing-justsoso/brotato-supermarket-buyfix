extends PanelContainer

signal option_selected(index)

onready var option:OptionButton = $VBoxContainer/ScrollContainer/OptionButton
onready var _label:Label = $VBoxContainer/Label
onready var _scroll:ScrollContainer = $VBoxContainer/ScrollContainer


export(String) var title
export(DynamicFont) var title_font = null
export(Vector2) var min_size = Vector2(0, 0)
export(Array, Array, String) var items

func _ready():
	set_title(title)
	if title_font != null:
		_label.add_font_override("font", title_font)
	option.set_custom_minimum_size(min_size)
	for item in items:
		add_item(item[0], item[1])


func add_item(name:String, key)->void:
	option.add_item(name)
	var idx = option.get_item_count() - 1
	option.set_item_metadata(idx, key)


func get_selected_metadata():
	return option.get_selected_metadata()


func get_selected_id()->int:
	return option.get_selected_id()


func set_title(text:String)->void:
	_label.set_text(text)


func select(index:int)->void:
	option.select(index)


func _on_OptionButton_item_selected(index):
	emit_signal("option_selected", index)
