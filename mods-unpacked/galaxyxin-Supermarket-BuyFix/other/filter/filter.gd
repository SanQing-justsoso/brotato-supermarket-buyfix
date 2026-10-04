extends ScrollContainer

signal filter_data_changed(filter_data, param)

export (PackedScene) var filter_scene = null

onready var _option_mod = $Margin/VBox/Mod
onready var _option_category = $Margin/VBox/OptionCategory
onready var _option_curse = $Margin/VBox/Curse
onready var _option_weapon = $Margin/VBox/Weapon
onready var _option_weapon_type = $Margin/VBox/Weapon/WeaponType
onready var _option_weapon_class = $Margin/VBox/Weapon/WeaponClass
onready var _option_scaling_stat_icon = $Margin/VBox/Weapon/OptionScalingStat/Icon
onready var _option_scaling_stat_label = $Margin/VBox/Weapon/OptionScalingStat/Label
onready var _option_scaling_stat_cancel = $Margin/VBox/Weapon/OptionScalingStat/Cancel
onready var _option_item = $Margin/VBox/Item
onready var _stats_container = $Margin/VBox/Item/Stats

var _mod_tool:Node = null
var data:Dictionary = {}


func _ready():
	_mod_tool = get_node("/root/ModLoader/galaxyxin-Supermarket-BuyFix/工具")
	reset()
	var text = tr(_option_item.get_node("OptionItem").get_item_text(2))
	var _par = text.find("(")
	if _par != -1:
		text = text.substr(0, _par).strip_edges()
	_option_item.get_node("OptionItem").set_item_text(2, text)
	
	# curse filter removed; curse display handled by shop-level curse switch
	_option_curse.hide()
	
	var is_zh = TranslationServer.get_locale().begins_with("zh")
	var _title_font = load("res://resources/fonts/actual/base/font_26.tres")
	# 1) 武器/道具筛选添加标题（样式与其他标题一致）
	_wrap_with_title(_option_category, "类型" if is_zh else "Type", _title_font)
	# 2) 远近战标题改为定位
	_option_weapon_type.set_title("定位" if is_zh else "Role")
	# 3) 武器不再支持点击右侧属性筛选，隐藏提示行
	_option_scaling_stat_icon.get_parent().hide()
	# 5) 独特/限制/普通下拉添加标题（样式与其他标题一致）
	_wrap_with_title(_option_item.get_node("OptionItem"), "限制" if is_zh else "Limit", _title_font)
	# 4) 清空按钮移到最下方
	_option_item.move_child(_option_item.get_node("Clear"), _option_item.get_child_count() - 1)
	
	# 加载mod来源，依赖ContentLoader模组
	if _mod_tool.has_mod("Darkly77-ContentLoader"):
		var _contentloader_mod_node = get_node_or_null("/root/ModLoader/Darkly77-ContentLoader/ContentLoader")
		if _contentloader_mod_node != null:
			if not _contentloader_mod_node.lookup_data_bymod.empty():
				for mod_name in _contentloader_mod_node.lookup_data_bymod:
					_option_mod.add_item(mod_name, mod_name)
				_option_mod.show()
	
	# 词条
	for set in ItemService.sets:
		_option_weapon_class.add_item(set.name, set.my_id)
	
	# 加载上轮筛选，已放弃(不知道是前两位哪位放弃的 —Virtuoso)


func reset(send_signal:bool = false):
	data = {
		"mod": "", # mod名称
		"weapon or item": 0,# 武器或道具：0全部，1武器，2道具
		"weapon type": 0,# 武器类型：0全部，1近战，2远程
		"weapon class": "",# 武器词条
		"weapon scaling stat": "",# 武器伤害影响
		"item number limit": 0,# 选择道具数量限制 0全部，1独特的，2限制，3道具
		"item effect": {},# 效果筛选数据 [key:String]：0排除，1增加，2减少，3全部
		"item special effect": 0,
	}
	if send_signal:
		emit_signal("filter_data_changed", data, "")


func add_stat(title:String):
	var update_flag:bool = false
	var stat_key:String
	match title:
		"CURRENT_LEVEL":
			stat_key = "stat_levels"
		"CHANCE_HEAL_ON_GOLD":
			stat_key = "heal_when_pickup_gold".to_upper()
		"PCT_NUMBER_OF_ENEMIES":
			stat_key = "NUMBER_OF_ENEMIES"
		"PCT_ENEMY_SPEED":
			stat_key = "ENEMY_SPEED"
		_:
			stat_key = title
	# 如果没显示筛选道具，就显示
	if not _option_item.is_visible():
		# 选择武器时，终止
		if _option_weapon.is_visible():
			return
		# 点击右侧属性默认显示道具
		_option_category.select(2)
		data["weapon or item"] = 2
		_option_weapon.hide()
		_option_item.show()
		update_flag = true
	
	if data["item effect"].has(stat_key):
		if update_flag:
			emit_signal("filter_data_changed", data, "")
		return
	
	add_item_stat(stat_key, title)


func add_item_stat(key:String, title:String):
	var value = 3
	var instance = filter_scene.instance()
	_stats_container.add_child(instance)
	instance.set_stat(key, title, value)
	instance.connect("data_changed", self, "on_filter_stat_data_changed")
	instance.connect("close", self, "on_filter_stat_close")
	if data["item effect"].empty():
		_option_item.get_node("Label").hide()
	data["item effect"][key] = value
	emit_signal("filter_data_changed", data, key)


func select_scaling_stat(key:String, title:String):
	_option_scaling_stat_label.text = title
	if title == "CURRENT_LEVEL":
		_option_scaling_stat_icon.texture = load("res://items/upgrades/upgrade_icon.png")
	else:
		_option_scaling_stat_icon.texture = ItemService.get_stat_small_icon(Keys.generate_hash(key.to_lower()))
	_option_scaling_stat_cancel.show()
	data["weapon scaling stat"] = key.to_lower()
	emit_signal("filter_data_changed", data, "")


func on_filter_stat_data_changed(key:String, value:int):
	data["item effect"][key] = value
	emit_signal("filter_data_changed", data, key)


func on_filter_stat_close(filter_stat_node, key):
	if data["item effect"].has(key):
		data["item effect"].erase(key)
	_stats_container.remove_child(filter_stat_node)
	if data["item effect"].empty():
		_option_item.get_node("Label").show()
	emit_signal("filter_data_changed", data, key)


func _on_OptionCategory_item_selected(index):
	# 选择道具
	if index == 2:
		# 隐藏武器选择按钮
		_option_weapon.hide()
		_option_item.show()
	# 选择武器
	elif index == 1:
		# 隐藏道具选择按钮
		_option_item.hide()
		_option_weapon.show()
	# 选择全部
	else:
		_option_weapon.hide()
		_option_item.hide()
	
	data["weapon or item"] = index
	emit_signal("filter_data_changed", data, "")


func _on_OptionItem_item_selected(index):
	data["item number limit"] = index
	emit_signal("filter_data_changed", data, "")


func _on_Clear_pressed():
	_option_item.get_node("Special").select(0)
	for n in _stats_container.get_children():
		_stats_container.remove_child(n)
		n.queue_free()
	data["item effect"].clear()
	data["item special effect"] = 0
	_option_item.get_node("Label").show()
	emit_signal("filter_data_changed", data, "")


func _on_Cancel_pressed():
	_option_scaling_stat_label.text = "ekJg5ZS1_FILTER_UI_PROMPT_1"
	_option_scaling_stat_icon.texture = null
	_option_scaling_stat_cancel.hide()
	data["weapon scaling stat"] = ""
	emit_signal("filter_data_changed", data, "")


func _on_Mod_option_selected(index):
	data["mod"] = _option_mod.get_selected_metadata()
	emit_signal("filter_data_changed", data, "")


func _on_WeaponType_option_selected(index):
	data["weapon type"] = index
	emit_signal("filter_data_changed", data, "")


func _on_WeaponClass_option_selected(index):
	data["weapon class"] = _option_weapon_class.get_selected_metadata()
	emit_signal("filter_data_changed", data, "")


func _on_Special_option_selected(index):
	data["item special effect"] = index
	emit_signal("filter_data_changed", data, "")

func _on_Curse_option_selected(index):
	pass


func _wrap_with_title(option_node:Control, title_text:String, title_font)->void:
	var parent = option_node.get_parent()
	var idx = option_node.get_index()
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25098)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	var label = Label.new()
	label.text = title_text
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.autowrap = true
	label.add_font_override("font", title_font)
	vbox.add_child(label)
	parent.remove_child(option_node)
	vbox.add_child(option_node)
	parent.add_child(panel)
	parent.move_child(panel, idx)
