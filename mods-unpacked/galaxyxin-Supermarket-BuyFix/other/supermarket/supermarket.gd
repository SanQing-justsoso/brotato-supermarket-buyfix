extends ScrollContainer
# 抄"res://ui/menus/shop/inventory.gd"

signal element_pressed(element)
signal element_hovered(element)
signal element_unhovered(element)
signal element_focused(element)
signal element_unfocused(element)
signal moving()
signal supermarket_visibility_changed(visibility)

onready var _container = $HFlowContainer
onready var _v = get_v_scrollbar()
onready var _h = get_h_scrollbar()

export (PackedScene) var element_scene = null

var _reversed_order: = false

var _displacement:int = 0
var _moved:bool = false
var _moving:bool = false
var _mouse_displacement:int = 0
var _mouse_pressed:bool = false
var _v_old:int = 0
var _has_touch_slide_mod:bool = false
var mod_tool
var dlc

func _ready():
	mod_tool = get_node("/root/ModLoader/galaxyxin-Supermarket-BuyFix/工具")
	if mod_tool.has_mod("JAghI70bfEvHbE4ZxOJRz7yEjINYbbS3-ModName_Touch_slide_HEQxNuep"):
		if has_node("/root/MouseFilter"):
			_has_touch_slide_mod = true
	_v.rect_min_size.x += 20
	_v.connect("value_changed", self, "on_v_value_changed")
	if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		dlc = ProgressData.get_dlc_data("abyssal_terrors")


var player_index:int = 0
var _weapon_bar_path:NodePath = NodePath("")
var _go_button_path:NodePath = NodePath("")
var _weapons_bar_path:NodePath = NodePath("")


func set_elements(elements:Array, reverse_order:bool = false, replace:bool = true, curse_on:bool = false):
	# 是否重置
	if replace:
		clear_elements()
	# 是否倒序
	_reversed_order = reverse_order
	# 数组为空退出
	if elements == null or elements.size() == 0:
		return
	# player_index 越界防护：players_data 按实际参战人数分配，非法索引直接退出
	if player_index < 0 or player_index >= RunData.players_data.size():
		return
	# 兼容原存档，原存档无诅咒不能加
	var can_curse:bool = false
	if Keys.stat_curse_hash in RunData.get_player_effects(player_index) :
		can_curse = true
	
	var current_wave = min(RunData.current_wave, 1)
	
	for element in elements:
		if element.is_locked:
			continue
		
		if curse_on and can_curse and dlc:
			add_element(element, true, current_wave)
		else:
			add_element(element)

func clear_elements()->void :
	for n in _container.get_children():
		_container.remove_child(n)
		n.queue_free()


func add_element(element:ItemParentData, curse:bool=false, curse_level:float=0):
	var instance = element_scene.instance()
	_container.add_child(instance)
	if curse and dlc:
		element = dlc.curse_item(element, player_index, true, curse_level)
	instance.set_element(element)
	if element.get_category() == Category.ITEM:
		if element.max_nb != -1:
			var current_number = 0
			# player_index 越界防护
			var _owned_items:Array = []
			if player_index >= 0 and player_index < RunData.players_data.size():
				_owned_items = RunData.players_data[player_index].items
			for item in _owned_items:
				if item.my_id == element.my_id:
					current_number += 1
			show_remaining_quantity(instance, current_number)
	
	if _reversed_order:
		_container.move_child(instance, 0)
	
	var _error_hover = instance.connect("element_hovered", self, "on_element_hovered")
	var _error_unhover = instance.connect("element_unhovered", self, "on_element_unhovered")
	var _error_focus = instance.connect("element_focused", self, "on_element_focused")
	var _error_unfocus = instance.connect("element_unfocused", self, "on_element_unfocused")
	var _error_pressed = instance.connect("element_pressed", self, "on_element_pressed")
	
	instance.mouse_filter = Control.MOUSE_FILTER_PASS


func remove_element(element:ItemParentData)->InventoryElement:
	var children = _container.get_children()
	var index:int = 0
	var flag:bool = false
	var out = null
	for i in children.size():
		if not is_instance_valid(children[i]) or children[i].is_queued_for_deletion() or children[i].item == null:
			continue
		if children[i].item.my_id == element.my_id:
			index = i
#			if _elements[index].my_id ==  element.my_id:
#				_elements.remove(index)
#			else:
#				_elements.erase(element)
			flag = true
			break
	
	if not flag:
		return null
	# 选取最近的有效相邻元素作为新焦点，跳过无效/已排队释放的节点
	for j in range(index + 1, children.size()):
		if is_instance_valid(children[j]) and not children[j].is_queued_for_deletion():
			out = children[j]
			break
	if out == null:
		for j in range(index - 1, -1, -1):
			if is_instance_valid(children[j]) and not children[j].is_queued_for_deletion():
				out = children[j]
				break
	children[index].queue_free()
	
	return out


func find_element(item_data:ItemParentData)->InventoryElement:
	var children = _container.get_children()
	for i in children.size():
		if not is_instance_valid(children[i]) or children[i].is_queued_for_deletion() or children[i].item == null:
			continue
		if children[i].item.my_id == item_data.my_id:
			return children[i]
	return null
	


func show_remaining_quantity(element:InventoryElement, current_number):
	# 元素可能已被释放/置空（yield 后回调），防崩
	if element == null or not is_instance_valid(element) or element.item == null:
		return
	element._number_label.set_text("x" + String(int(max(element.item.max_nb - current_number, 0))))
	


func refresh_remaining_quantities()->void :
	# 启用超市时刷新限定道具剩余数量（原版商店购买后，add_element 时统计的持有数已过期）
	if player_index < 0 or player_index >= RunData.players_data.size():
		return
	var owned_items:Array = RunData.players_data[player_index].items
	for c in _container.get_children():
		if not is_instance_valid(c) or c.is_queued_for_deletion() or c.item == null:
			continue
		if c.item.get_category() != Category.ITEM or c.item.max_nb == -1:
			continue
		var current_number:int = 0
		for item in owned_items:
			if item.my_id == c.item.my_id:
				current_number += 1
		if current_number >= c.item.max_nb:
			# 已无剩余可购数量，直接从列表移除，而不是显示 x0
			_container.remove_child(c)
			c.queue_free()
		else:
			show_remaining_quantity(c, current_number)


func on_element_hovered(element:InventoryElement)->void :
	emit_signal("element_hovered", element)
	_moved = false


func on_element_unhovered(element:InventoryElement)->void :
	emit_signal("element_unhovered", element)


func on_element_focused(element:InventoryElement)->void :
	emit_signal("element_focused", element)


func on_element_unfocused(element:InventoryElement)->void :
	emit_signal("element_unfocused", element)


func on_element_pressed(element:InventoryElement)->void :
	if _moved:
		_moved = false
	else:
		emit_signal("element_pressed", element)


func on_v_value_changed(value):
	if _mouse_pressed:
		_moved = true
	emit_signal("moving")


func _gui_input(event):
	if _has_touch_slide_mod:
		if event is InputEventMouseButton:
			_mouse_pressed = event.pressed
		return
	if event is InputEventMouseButton:
		_mouse_pressed = event.pressed
		if _mouse_pressed:
			_displacement = 0
			_mouse_displacement = 0
		else:
			_moving = false
	if event is InputEventMouseMotion and _mouse_pressed:
		_mouse_displacement += event.relative.y
		if _moving:
			_v.value = _v_old - _mouse_displacement
		else:
			if abs(_mouse_displacement) > 10:
				_moving = true
				_mouse_displacement = 0
				_v_old = _v.value


func set_go_button(button:Control)->void :
	_go_button_path = get_path_to(button)
	if not _container.is_connected("sort_children", self, "_relink_go_button_deferred"):
		_container.connect("sort_children", self, "_relink_go_button_deferred")
	_relink_go_button_deferred()


func set_weapon_bar(control:Control)->void :
	_weapon_bar_path = get_path_to(control)
	if control is Container and not control.is_connected("sort_children", self, "_relink_go_button_deferred"):
		control.connect("sort_children", self, "_relink_go_button_deferred")
	_relink_go_button_deferred()


func set_weapons_bar(control:Control)->void :
	# task5: 真正的武器栏(末行下移目标); _weapon_bar_path 现指向道具栏(行首左跳目标)
	_weapons_bar_path = get_path_to(control)
	if control is Container and not control.is_connected("sort_children", self, "_relink_go_button_deferred"):
		control.connect("sort_children", self, "_relink_go_button_deferred")
	_relink_go_button_deferred()


func _ekjg_first_focusable(path:NodePath)->Control:
	if path.is_empty() or not has_node(path):
		return null
	var bar = get_node(path)
	if not (bar is Control) or not is_instance_valid(bar) or bar.is_queued_for_deletion():
		return null
	for ch in bar.get_children():
		if ch is Control and is_instance_valid(ch) and not ch.is_queued_for_deletion() and ch.visible and ch.focus_mode == Control.FOCUS_ALL:
			return ch
	return null


func _relink_go_button_deferred()->void :
	call_deferred("_relink_go_button")


func _relink_go_button()->void :
	if _go_button_path.is_empty() or not has_node(_go_button_path):
		return
	var go_button:Control = get_node(_go_button_path)
	var weapon_bar:Control = null
	if not _weapon_bar_path.is_empty() and has_node(_weapon_bar_path):
		weapon_bar = get_node(_weapon_bar_path)
		# 闪烁修复: 左跳直接指向栏内第一个可聚焦子元素，跳过容器中转(focus_entered->deferred grab_focus)的空帧
		for ekjg_wc in weapon_bar.get_children():
			if ekjg_wc is Control and is_instance_valid(ekjg_wc) and not ekjg_wc.is_queued_for_deletion() and ekjg_wc.visible and ekjg_wc.focus_mode == Control.FOCUS_ALL:
				weapon_bar = ekjg_wc
				break
	var children = _container.get_children()
	for i in children.size():
		var c = children[i]
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		# 行尾判断：最后一个元素，或下一个元素换行(x不再递增)
		var row_end:bool = true
		if i < children.size() - 1:
			var nxt = children[i + 1]
			if is_instance_valid(nxt) and nxt.rect_position.x > c.rect_position.x:
				row_end = false
		if row_end:
			c.focus_neighbour_right = c.get_path_to(go_button)
		else:
			c.focus_neighbour_right = NodePath("")
		var row_start:bool = true
		if i > 0:
			var prv = children[i - 1]
			if is_instance_valid(prv) and prv.rect_position.x < c.rect_position.x:
				row_start = false
		if row_start and weapon_bar != null:
			c.focus_neighbour_left = c.get_path_to(weapon_bar)
		else:
			c.focus_neighbour_left = NodePath("")

	# 行分组：下一行较短时，超出列数的元素下跳统一指向下一行最后一个元素
	var rows:Array = []
	var cur:Array = []
	var last_x:float = -1.0
	for i2 in children.size():
		var c2 = children[i2]
		if not is_instance_valid(c2) or c2.is_queued_for_deletion():
			continue
		if cur.size() > 0 and c2.rect_position.x <= last_x:
			rows.append(cur)
			cur = []
		cur.append(c2)
		last_x = c2.rect_position.x
	if cur.size() > 0:
		rows.append(cur)
	# task5: 末行向下的落焦目标: 武器栏第一个可聚焦元素, 无武器栏(如公牛)则跳过, 直接落焦道具栏
	var ekjg_bottom:Control = _ekjg_first_focusable(_weapons_bar_path)
	if ekjg_bottom == null:
		ekjg_bottom = _ekjg_first_focusable(_weapon_bar_path)
	if ekjg_bottom == null and not _weapon_bar_path.is_empty() and has_node(_weapon_bar_path):
		var ekjg_ib = get_node(_weapon_bar_path)
		if ekjg_ib is Control and is_instance_valid(ekjg_ib) and not ekjg_ib.is_queued_for_deletion() and ekjg_ib.visible:
			ekjg_bottom = ekjg_ib
	for r in rows.size():
		for j in rows[r].size():
			var e = rows[r][j]
			if r < rows.size() - 1:
				var below:Array = rows[r + 1]
				var k:int = j
				if k >= below.size():
					k = below.size() - 1
				e.focus_neighbour_bottom = e.get_path_to(below[k])
			elif ekjg_bottom != null:
				e.focus_neighbour_bottom = e.get_path_to(ekjg_bottom)
			else:
				# 兜底: 完全找不到目标时锁定到 go_button, 防止自动寻焦丢焦
				e.focus_neighbour_bottom = e.get_path_to(go_button)


# task3: 限购道具购满被移除前, 预先计算新焦点: 补位的下一个元素, 若是最后一个则取前一个
func ekjg_get_refocus_after_remove(item_data:ItemParentData)->InventoryElement:
	var children = _container.get_children()
	var index:int = -1
	for i in children.size():
		if not is_instance_valid(children[i]) or children[i].is_queued_for_deletion() or children[i].item == null:
			continue
		if children[i].item.my_id == item_data.my_id:
			index = i
			break
	if index == -1:
		return null
	for j in range(index + 1, children.size()):
		var c = children[j]
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c.item != null and c.item.my_id != item_data.my_id:
			return c
	for j2 in range(index - 1, -1, -1):
		var c2 = children[j2]
		if is_instance_valid(c2) and not c2.is_queued_for_deletion() and c2.item != null and c2.item.my_id != item_data.my_id:
			return c2
	return null
