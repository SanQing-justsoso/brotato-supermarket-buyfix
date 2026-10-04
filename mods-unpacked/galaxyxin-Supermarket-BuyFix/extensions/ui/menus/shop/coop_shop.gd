extends "res://ui/menus/shop/coop_shop_player_container.gd"

onready var _hbox1 = $MarginContainer/Carousel/Content/VBoxContainer/HBoxContainer
onready var _headings = $MarginContainer/Carousel/MarginContainer/HBoxContainer/Headings
onready var _content = $MarginContainer/Carousel/Content/VBoxContainer/PanelContainer
onready var _shop_items_container = $MarginContainer/Carousel/Content/VBoxContainer/PanelContainer/ShopItemsContainer

var _supermarket_button
var _supermarket
var _othershopitem
var _filter
var _filter_manager
var _invisible_canvas:Control
var _fifth_shopitem:ShopItem

var _element_hovered:InventoryElement = null
var _element_focused:InventoryElement = null
var _element_pressed:InventoryElement = null

var _curse_button
var _curse_label
var _mod_tool:Node = null
var _ekjg_refocus_element = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# 合作商店场景固定包含4个玩家容器，未参战玩家的容器跳过mod初始化，避免 players_data 越界闪退
	if player_index >= RunData.get_player_count():
		return
	if not self.visible:
		return
	_mod_tool = get_node("/root/ModLoader/galaxyxin-Supermarket-BuyFix/工具")
	
	# 按钮，用于打开自选界面
	_supermarket_button = CheckButton.new()
	_supermarket_button.name = "supermarket_button"
	_hbox1.add_child(_supermarket_button)
	_supermarket_button.connect("toggled", self, "on_supermarket_button_toggled")
	_hbox1.move_child(_supermarket_button,_hbox1.get_node("GoldUI").get_index() + 1)
	var _supermarket_label = Label.new()
	_supermarket_label.name = "supermarket_label"
	_supermarket_label.text = tr("ekJg5ZS1_MARKET")
	_supermarket_label.valign = Label.VALIGN_CENTER
	_hbox1.add_child(_supermarket_label)
	_hbox1.move_child(_supermarket_label, _hbox1.get_node("GoldUI").get_index() + 1)
	# curse switch (abyssal DLC only, visible while supermarket is open)
	if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		_curse_button = CheckButton.new()
		_curse_button.name = "curse_button"
		_hbox1.add_child(_curse_button)
		_curse_button.pressed = _mod_tool.supermarket_curse
		_curse_button.connect("toggled", self, "on_curse_button_toggled")
		_hbox1.move_child(_curse_button, _supermarket_button.get_index() + 1)
		_curse_label = Label.new()
		_curse_label.name = "curse_label"
		_curse_label.text = "诅咒" if TranslationServer.get_locale().begins_with("zh") else "Curse"
		_curse_label.valign = Label.VALIGN_CENTER
		_hbox1.add_child(_curse_label)
		_hbox1.move_child(_curse_label, _supermarket_button.get_index() + 1)
		_curse_button.hide()
		_curse_label.hide()
	
	# 购买界面
	# 焦点邻居：超市开关 <-> 诅咒开关 <-> 刷新按钮
	_supermarket_button.focus_neighbour_left = NodePath(".")
	if _curse_button != null:
		_supermarket_button.focus_neighbour_right = _supermarket_button.get_path_to(_curse_button)
		_curse_button.focus_neighbour_left = _curse_button.get_path_to(_supermarket_button)
		_curse_button.focus_neighbour_right = _curse_button.get_path_to(reroll_button)
		reroll_button.focus_neighbour_left = reroll_button.get_path_to(_curse_button)
	else:
		_supermarket_button.focus_neighbour_right = _supermarket_button.get_path_to(reroll_button)
		reroll_button.focus_neighbour_left = reroll_button.get_path_to(_supermarket_button)

	_othershopitem = load(_mod_tool.mod_dir + "other/othershopitem/other_shop_item.tscn").instance()
	_othershopitem.initialization(self)
	add_child(_othershopitem)
	_othershopitem._shopitem.player_index = player_index
	_othershopitem.connect("mouse_hovered_category", _shop_items_container, "on_mouse_hovered_category")
	_othershopitem.connect("mouse_exited_category", _shop_items_container, "on_mouse_exited_category")
	_othershopitem.connect("buy_button_pressed", self, "on_othershopitem_buybutton_pressed")
	_othershopitem.connect("lockbutton_toggled", self, "on_othershopitem_lockbutton_toggled")
	_othershopitem.connect("cancel_button_pressed", self, "on_othershopitem_cancel_pressed")
	# 超市 F/X 详情开关与原生弹窗开关状态双向同步
	item_popup.connect("popup_toggled", self, "ekjg_on_native_popup_toggled")
	_othershopitem._ekjg_info_hidden = item_popup._hide_popup
	pass
	
	# 物品界面
	_supermarket = load(_mod_tool.mod_dir + "other/supermarket/supermarket.tscn").instance()
	_supermarket.hide()
	_content.add_child(_supermarket)
	_supermarket.player_index = player_index
	_supermarket.connect("element_pressed", self, "on_supermarket_element_pressed")
	_supermarket.connect("element_focused", self, "on_supermarket_element_focused")
	_supermarket.connect("element_unfocused", self, "on_supermarket_element_unfocused")
	_supermarket.connect("element_hovered", self, "on_supermarket_element_hovered")
	_supermarket.connect("element_unhovered", self, "on_supermarket_element_unhovered")
	_supermarket.connect("moving", self, "on_supermarket_moving")
	_supermarket.set_go_button(go_button)
	# task2: 合作模式行首左跳改为道具栏(公牛无武器栏也不受影响)
	_supermarket.set_weapon_bar(player_gear_container.items_container._elements)
	_supermarket.set_weapons_bar(player_gear_container.weapons_container._elements)
	
	# 筛选器
	_filter = load(_mod_tool.mod_dir + "other/filter/filter.tscn").instance()
	_filter.hide()
	add_child(_filter)
	
	# 筛选管理节点
	_filter_manager = load(_mod_tool.mod_dir + "other/filter_manager/filter_manager.tscn").instance()
	add_child(_filter_manager)
	_filter_manager.connect("supermarket_changed", self, "on_filter_manager_supermarket_changed")
	_filter_manager.init_link_node(_supermarket, _filter, primary_stats_container)
	_mod_tool.stat_container_init(secondary_stats_container, _filter_manager, "on_stats_button_pressed")
	
	# 添加一个shopitem，调用其他mod扩展
	_invisible_canvas = Control.new()
	_invisible_canvas.hide()
	add_child(_invisible_canvas)
	_fifth_shopitem = load("res://ui/menus/shop/shop_item.tscn").instance()
	_fifth_shopitem.player_index = player_index
	_fifth_shopitem.connect("buy_button_pressed", _shop_items_container, "on_shop_item_buy_button_pressed")
	_fifth_shopitem.connect("shop_item_deactivated", _shop_items_container, "on_shop_item_deactivated")
	_fifth_shopitem.connect("shop_item_focused", _shop_items_container, "on_shop_item_focused")
	_fifth_shopitem.connect("shop_item_unfocused", _shop_items_container, "on_shop_item_unfocused")
	_fifth_shopitem.connect("mouse_hovered_category", _shop_items_container, "on_mouse_hovered_category")
	_fifth_shopitem.connect("mouse_exited_category", _shop_items_container, "on_mouse_exited_category")
	_fifth_shopitem.hide()
	_invisible_canvas.add_child(_fifth_shopitem)
	
	self.connect("visibility_changed", self, "on_visibility_changed")

	# ekJg5ZS1: merge cursed duplicates in the owned items display
	var ekjg_inv = player_gear_container.items_container._elements
	ekjg_inv.connect("elements_changed", self, "ekjg_on_items_elements_changed", [ekjg_inv])
	ekjg_on_items_elements_changed(ekjg_inv)

func supermarket_open():
	# 调整ui大小
	# 打开超市时刷新一次剩余数量，同步原版商店里的购买
	_supermarket.refresh_remaining_quantities()
	_supermarket.show()
	_shop_items_container.hide()
	_supermarket.rect_min_size = _shop_items_container.rect_size
	if _curse_button != null:
		_curse_button.show()
		_curse_label.show()


func supermarket_close():
	_supermarket.hide()
	_shop_items_container.show()
	if _curse_button != null:
		_curse_button.hide()
		_curse_label.hide()

func general_buy(item_data:ItemParentData):
	_fifth_shopitem.set_shop_item(item_data)
	_fifth_shopitem._on_BuyButton_pressed()

func on_supermarket_button_toggled(button_pressed:bool):
	if button_pressed:
		supermarket_open()
	else:
		supermarket_close()

func on_supermarket_element_pressed(element:InventoryElement):
	if _element_pressed != null:
		return
	_element_pressed = element
	# skip rebuilding the card if it already shows this item (prevents flicker)
	if _othershopitem._last_element_item != element.item or not _othershopitem._shopitem.visible:
		_othershopitem.set_shopitem(element)
	_othershopitem.pressed_element()


func on_supermarket_element_focused(element:InventoryElement):
	if _element_pressed != null:
		return
	_othershopitem.set_shopitem(element)
	_othershopitem.show()
	_element_focused = element

func on_supermarket_element_unfocused(element:InventoryElement):
	if _element_pressed != null:
		return
	_othershopitem.hide()


func on_supermarket_element_hovered(element:InventoryElement):
	if _element_pressed != null:
		return
	element.grab_focus()
	_element_hovered = element


func on_supermarket_element_unhovered(element:InventoryElement):
	if _element_pressed != null:
		return 
	element.release_focus()
	_othershopitem.hide()


func on_supermarket_moving():
	if _element_pressed != null:
		_othershopitem._on_Cancel_pressed()
	else:
		_othershopitem.hide()

func on_othershopitem_buybutton_pressed(shop_item:ShopItem, number:int):
	var item_number_is_max:bool = false
	# yield 期间 shop_item 卡片节点可能被释放，先取出数据引用（Resource 不随节点释放）
	var item_data:ItemParentData = shop_item.item_data
	var item_value:int = shop_item.value
	if item_data.get_category() == Category.WEAPON:
		for i in number:
			if i > 0:
				# 武器处理需要时间
				yield(get_tree().create_timer(0.1), "timeout")
#			buy_weapon(item_data, 0)
			general_buy(item_data)
	elif item_data.get_category() == Category.ITEM:
#		if number > 1 and item_data.max_nb != 1:
#			var return_value = buy_item(item_data, number)
#			while return_value is GDScriptFunctionState:
#				yield(get_tree().create_timer(0.01), "timeout")
#				return_value = return_value.resume()
#			if return_value == false:
#				return
#		else:
#			if RunData.get_player_currency(0) < item_value:
#				return
#			else:
#				general_buy(item_data)
		for i in range(number):
			if item_data.max_nb != -1:
				var nb_owned:int = 0
				for owned in RunData.get_player_items(player_index):
					if owned.my_id == item_data.my_id:
						nb_owned += 1
				if nb_owned >= item_data.max_nb:
					break
			if i > 0:
				# 武器处理需要时间
				yield(get_tree().create_timer(0.1), "timeout")
				if not is_instance_valid(shop_item) or not is_instance_valid(_fifth_shopitem) or not is_instance_valid(_othershopitem):
					return
			general_buy(item_data)
			
		# yield 后商店可能已关闭/刷新，节点已释放则直接退出
		if not is_instance_valid(_supermarket) or not is_instance_valid(_othershopitem):
			return
		# 判断道具是否达到上限
		if item_data.max_nb != -1:
			var current_number = 0
			for item in RunData.get_player_items(player_index):
				if item.my_id == item_data.my_id:
					current_number += 1
			if current_number >= item_data.max_nb:
				item_number_is_max = true
			# 感觉怪怪的，以后再说
			if _element_pressed != null and is_instance_valid(_element_pressed) and is_instance_valid(_supermarket):
				_supermarket.show_remaining_quantity(_element_pressed, current_number)
	
	# 从道具池移除到达数量上限的道具，将就用，凑合吧
#	if item_number_is_max:
#		var elements = _filter_manager.elements
#		for i in elements:
#			if i[1].has(item_data):
#				i[1].erase(item_data)
#				break
	
#	if _filter_manager._show_allow_buy:
#
#		var display_number = _filter_manager.display_elements.size()
#		var position = _supermarket.get_v_scroll()
#		_filter_manager.update()
#		yield(get_tree().create_timer(0.01), "timeout")
##		_supermarket.set_v_scroll(position)
#
#		_element_pressed = _supermarket.find_element(item_data)
#		if _element_pressed != null:
#			if position > _element_pressed.rect_position.y:
#				_supermarket.set_v_scroll(_element_pressed.rect_position.y)
#			if position + _supermarket.rect_size.y < _element_pressed.rect_position.y:
#				_supermarket.set_v_scroll(
#						_element_pressed.rect_position.y +
#						_supermarket.rect_size.y - _element_pressed.rect_size.y)
			
			
		
		if not item_number_is_max and RunData.get_player_currency(player_index) < item_value:
			_othershopitem._on_Cancel_pressed()
			return
		
		
	# yield 后统一校验节点有效性
	if not is_instance_valid(_supermarket) or not is_instance_valid(_othershopitem):
		return
	if item_number_is_max:
		_element_focused = null
		_element_hovered = null
		_element_pressed = null
		# task3: 移除前先记录新焦点(补位的下一个, 若是最后一个则取前一个)
		_ekjg_refocus_element = _supermarket.ekjg_get_refocus_after_remove(item_data)
		# 统一走刷新逻辑：更新剩余数量并立即移除已购满的道具（与原版商店购买路径一致）
		_supermarket.refresh_remaining_quantities()
		_deactivate_native_cards(item_data)
		# 等待移除元素
		yield(get_tree().create_timer(0.01), "timeout")
		if is_instance_valid(_othershopitem):
			_othershopitem._on_Cancel_pressed()
	else:
		# 关闭购买窗口（超市卡片无锁定功能，is_locked 恒为 false，死分支已清理）
		_othershopitem._on_Cancel_pressed()


func on_othershopitem_lockbutton_toggled(button_pressed:bool):
	_mod_tool.supermarket_locked = button_pressed


func on_othershopitem_cancel_pressed():
	if _element_pressed != null and is_instance_valid(_element_pressed):
		_focus_player(_element_pressed)
		# 如果有物品移除，需要等待位置刷新
		yield(get_tree().create_timer(0.01), "timeout")
		if _element_pressed != null and is_instance_valid(_element_pressed) and is_instance_valid(_othershopitem):
			_othershopitem.set_shopitem(_element_pressed)
	else:
		# task3: 限购道具被移除后, 焦点落到补位/上一个道具
		if _ekjg_refocus_element != null and is_instance_valid(_ekjg_refocus_element) and _ekjg_refocus_element.is_visible_in_tree():
			_focus_player(_ekjg_refocus_element)
		else:
			_focus_player(_supermarket_button)
	_ekjg_refocus_element = null
	_element_pressed = null


func on_filter_manager_supermarket_changed():
	_element_pressed = null
	_element_focused = null
	_element_hovered = null
	call_deferred("_coop_refocus_check")


func on_visibility_changed():
	# panel hidden: silently close supermarket UI and reset state (no grab_focus here)
	if is_visible_in_tree():
		return
	_element_pressed = null
	_element_focused = null
	_element_hovered = null
	if _othershopitem != null:
		_othershopitem.force_close()
	if _supermarket_button != null and _supermarket_button.pressed:
		_supermarket_button.pressed = false


func _focus_player(control):
	if control == null or not is_instance_valid(control):
		return
	if RunData.is_coop_run:
		var em = Utils.get_focus_emulator(player_index)
		if em != null:
			Utils.focus_player_control(control, player_index, em)
		return
	control.grab_focus()


func _coop_refocus_check():
	# after the list rebuild, an emulated focus may point to a freed element
	if not RunData.is_coop_run:
		return
	var em = Utils.get_focus_emulator(player_index)
	if em == null:
		return
	var fc = em.focused_control
	if fc == null or not is_instance_valid(fc) or not fc.is_visible_in_tree():
		if _supermarket_button != null and is_instance_valid(_supermarket_button):
			Utils.focus_player_control(_supermarket_button, player_index, em)


func on_curse_button_toggled(button_pressed:bool):
	_mod_tool.supermarket_curse = button_pressed
	if _filter_manager != null:
		_filter_manager.update()


func ekjg_on_items_elements_changed(inv):
	if inv.has_meta("ekjg_merge_queued") and inv.get_meta("ekjg_merge_queued"):
		return
	inv.set_meta("ekjg_merge_queued", true)
	call_deferred("ekjg_merge_cursed_elements", inv)


func ekjg_merge_cursed_elements(inv):
	if inv == null or not is_instance_valid(inv):
		return
	inv.set_meta("ekjg_merge_queued", false)
	var seen = {}
	var removed = false
	for child in inv.get_children():
		if child.is_queued_for_deletion():
			continue
		if not (child is InventoryElement) or child.is_special:
			continue
		if child.item == null or not child.item.is_cursed:
			continue
		var key = str(child.item.serialize())
		if seen.has(key):
			seen[key].add_to_number(child.current_number)
			inv.order_of_addition.erase(child)
			inv.remove_child(child)
			child.queue_free()
			removed = true
		else:
			seen[key] = child
	if removed:
		inv.queue_set_focus_neighbours()


# 超市买满后：同步下架原生商店中同款且仍激活的卡片（与原版购买行为一致）
func _deactivate_native_cards(item_data:ItemParentData) -> void :
	if not is_instance_valid(_shop_items_container):
		return
	for card in _shop_items_container._shop_items:
		if is_instance_valid(card) and card.active and card.item_data != null and card.item_data.my_id == item_data.my_id:
			card.deactivate()

# 超市 F/X 开关 -> 原生: 更新 item_popup 状态并触发提示文本刷新
func ekjg_on_supermarket_info_toggled(hidden:bool) -> void :
	if item_popup == null or not is_instance_valid(item_popup):
		return
	if item_popup._hide_popup != hidden:
		item_popup._hide_popup = hidden
		item_popup.emit_signal("popup_toggled", hidden, player_index)


# 原生 F/X 开关 -> 超市: 同步卡片隐藏状态
func ekjg_on_native_popup_toggled(hide_popup, _pidx) -> void :
	if _othershopitem == null or not is_instance_valid(_othershopitem):
		return
	_othershopitem._ekjg_info_hidden = hide_popup
	if _othershopitem._ekjg_preview_active and not _othershopitem._cancel_button.visible:
		_othershopitem._shopitem.visible = not hide_popup
