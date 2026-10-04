extends "res://ui/menus/shop/shop.gd"

onready var _hbox1 = $Content/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer
onready var _hbox2 = $Content/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer2
onready var _hbox3 = $Content/MarginContainer/HBoxContainer/VBoxContainer/BottomContainer/GearContainer
onready var _shop_items_container = $Content/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer2/ShopItemsContainer

var _supermarket_button
var _curse_button
var _curse_label
var _supermarket
var _othershopitem
var _filter
var _filter_manager
var _invisible_canvas:Control
var _fifth_shopitem:ShopItem

var _element_hovered:InventoryElement = null
var _element_focused:InventoryElement = null
var _element_pressed:InventoryElement = null

var _mod_tool:Node = null
# 打开超市前保存的原生焦点邻居，关闭时恢复
var _saved_reroll_bottom = null
var _saved_go_top = null


func _ready()->void :
	ModLoaderLog.info("ekjg buy-fix active: supermarket purchases call the container handler directly", "Supermarket")
	_mod_tool = get_node("/root/ModLoader/galaxyxin-Supermarket-BuyFix/工具")
	
	# 按钮，用于打开自选界面
	_supermarket_button = CheckButton.new()
	_supermarket_button.name = "supermarket_button"
	_hbox1.add_child(_supermarket_button)
	_supermarket_button.connect("toggled", self, "on_supermarket_button_toggled")
	_hbox1.move_child(_supermarket_button,_hbox1.get_node("Title").get_index() + 1)
	var _supermarket_label = Label.new()
	_supermarket_label.name = "supermarket_label"
	_supermarket_label.text = tr("ekJg5ZS1_MARKET")
	_supermarket_label.valign = Label.VALIGN_CENTER
	_supermarket_label.set("custom_fonts/font", _hbox1.get_node("Title").get("custom_fonts/font"))
	_hbox1.add_child(_supermarket_label)
	_hbox1.move_child(_supermarket_label, _hbox1.get_node("Title").get_index() + 1)
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
		_curse_label.set("custom_fonts/font", _hbox1.get_node("Title").get("custom_fonts/font"))
		_hbox1.add_child(_curse_label)
		_hbox1.move_child(_curse_label, _supermarket_button.get_index() + 1)
		_curse_button.hide()
		_curse_label.hide()
	
	# 焦点连线：超市开关 <-> 诅咒开关 <-> 刷新按钮，左右互相选取（诅咒隐藏时自动跳过）
	var _reroll = _hbox1.get_node("RerollButton")
	_supermarket_button.focus_neighbour_left = NodePath(".")
	if _curse_button != null:
		_supermarket_button.focus_neighbour_right = _supermarket_button.get_path_to(_curse_button)
		_curse_button.focus_neighbour_left = _curse_button.get_path_to(_supermarket_button)
		_curse_button.focus_neighbour_right = _curse_button.get_path_to(_reroll)
		_reroll.focus_neighbour_left = _reroll.get_path_to(_curse_button)
	else:
		_supermarket_button.focus_neighbour_right = _supermarket_button.get_path_to(_reroll)
		_reroll.focus_neighbour_left = _reroll.get_path_to(_supermarket_button)
	
	# 筛选可买物品按钮
	
	# 购买界面
	_othershopitem = load(_mod_tool.mod_dir + "other/othershopitem/other_shop_item.tscn").instance()
	_othershopitem.initialization(self)
	add_child(_othershopitem)
	_othershopitem.connect("mouse_hovered_category", _shop_items_container, "on_mouse_hovered_category")
	_othershopitem.connect("mouse_exited_category", _shop_items_container, "on_mouse_exited_category")
	_othershopitem.connect("buy_button_pressed", self, "on_othershopitem_buybutton_pressed")
	_othershopitem.connect("lockbutton_toggled", self, "on_othershopitem_lockbutton_toggled")
	_othershopitem.connect("cancel_button_pressed", self, "on_othershopitem_cancel_pressed")
	pass
	
	# 物品界面
	_supermarket = load(_mod_tool.mod_dir + "other/supermarket/supermarket.tscn").instance()
	_supermarket.hide()
	_hbox2.add_child(_supermarket)
	_supermarket.connect("element_pressed", self, "on_supermarket_element_pressed")
	_supermarket.connect("element_focused", self, "on_supermarket_element_focused")
	_supermarket.connect("element_unfocused", self, "on_supermarket_element_unfocused")
	_supermarket.set_go_button($Content/MarginContainer/HBoxContainer/VBoxContainer2/GoButton)
	# 道具栏 Elements 原生 focus_mode=NONE，焦点模拟器会拒绝该目标并几何搜索到 GoButton；补为可聚焦并接上聚焦转发
	var _ekjg_items_bar = $Content/MarginContainer/HBoxContainer/VBoxContainer/BottomContainer/GearContainer/ItemsContainer/ScrollSizeContainer/ScrollContainer/Elements
	_ekjg_items_bar.focus_mode = Control.FOCUS_ALL
	if not _ekjg_items_bar.is_connected("focus_entered", _ekjg_items_bar, "on_focus_entered"):
		_ekjg_items_bar.connect("focus_entered", _ekjg_items_bar, "on_focus_entered")
	# 道具栏右跳武器栏: 用原生机制 set_neighbour_right + 容器级邻居继承(__set_focus_neighbours 每次重建都会应用)，避免几何搜索跳进超市列表
	var _ekjg_weap_bar = $Content/MarginContainer/HBoxContainer/VBoxContainer/BottomContainer/GearContainer/WeaponsContainer/ScrollSizeContainer/ScrollContainer/Elements
	_ekjg_items_bar.set_neighbour_right = true
	_ekjg_items_bar.focus_neighbour_right = _ekjg_items_bar.get_path_to(_ekjg_weap_bar)
	_ekjg_items_bar.queue_set_focus_neighbours()
	_supermarket.set_weapon_bar($Content/MarginContainer/HBoxContainer/VBoxContainer/BottomContainer/GearContainer/ItemsContainer/ScrollSizeContainer/ScrollContainer/Elements)
	_supermarket.connect("element_hovered", self, "on_supermarket_element_hovered")
	_supermarket.connect("element_unhovered", self, "on_supermarket_element_unhovered")
	_supermarket.connect("moving", self, "on_supermarket_moving")
	
	# 筛选器
	_filter = load(_mod_tool.mod_dir + "other/filter/filter.tscn").instance()
	_filter.hide()
	_hbox2.add_child(_filter)
	
	# 筛选管理节点
	_filter_manager = load(_mod_tool.mod_dir + "other/filter_manager/filter_manager.tscn").instance()
	add_child(_filter_manager)
	_filter_manager.connect("supermarket_changed", self, "on_filter_manager_supermarket_changed")
	_filter_manager.init_link_node(_supermarket, _filter, _stats_container)
	# 单人模式：货架行尾向右改为跳到筛选器（联机模式保持跳开始按钮）
	_supermarket.set_go_button(_filter._option_category)
	_supermarket.set_weapon_bar($Content/MarginContainer/HBoxContainer/VBoxContainer/BottomContainer/GearContainer/ItemsContainer/ScrollSizeContainer/ScrollContainer/Elements)
	
	
	
	
	# 添加一个shopitem，调用其他mod扩展
	_invisible_canvas = Control.new()
	_invisible_canvas.hide()
	add_child(_invisible_canvas)
	_fifth_shopitem = load("res://ui/menus/shop/shop_item.tscn").instance()
	_fifth_shopitem.connect("buy_button_pressed", _shop_items_container, "on_shop_item_buy_button_pressed")
	_fifth_shopitem.connect("shop_item_deactivated", _shop_items_container, "on_shop_item_deactivated")
	_fifth_shopitem.connect("shop_item_focused", _shop_items_container, "on_shop_item_focused")
	_fifth_shopitem.connect("shop_item_unfocused", _shop_items_container, "on_shop_item_unfocused")
	_fifth_shopitem.connect("mouse_hovered_category", _shop_items_container, "on_mouse_hovered_category")
	_fifth_shopitem.connect("mouse_exited_category", _shop_items_container, "on_mouse_exited_category")
	_fifth_shopitem.hide()
	_invisible_canvas.add_child(_fifth_shopitem)

	# ekJg5ZS1: merge cursed duplicates in the owned items display
	var ekjg_inv = _get_gear_container(0).items_container._elements
	ekjg_inv.connect("elements_changed", self, "ekjg_on_items_elements_changed", [ekjg_inv])
	ekjg_on_items_elements_changed(ekjg_inv)
	
#	check_bug()
#
#
#func _on_GoButton_pressed():
#	check_bug()
#	._on_GoButton_pressed()
#
#
#func check_bug():
#	# 未查明bug修复
#	if RunData.effects.has("harvesting_growth") and RunData.current_wave < 20:
#		# 收获增长未生效
#		if RunData.effects["harvesting_growth"] < 5:
#			RunData.effects["harvesting_growth"] = 5
#		# 王冠未生效
#		for item in RunData.items:
#			if item.max_nb == 1:
#				if item.my_id == "item_crown":
#					if RunData.effects["harvesting_growth"] < 13:
#						RunData.effects["harvesting_growth"] = 13

func supermarket_open():
	# 调整ui大小
	
	# 打开超市时刷新一次剩余数量，同步原版商店里的购买
	_supermarket.refresh_remaining_quantities()
	_supermarket.show()
	_filter.show()
	if _curse_button != null:
		_curse_button.show()
		_curse_label.show()
	_shop_items_container.hide()
	_hbox2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hbox3.size_flags_vertical = Control.SIZE_FILL
	var xxx = _shop_items_container.rect_size.x - _filter.rect_size.x - 4
	_supermarket.rect_min_size.x = xxx
	_supermarket.rect_min_size.y = _shop_items_container.rect_size.y


func supermarket_close():
	_supermarket.hide()
	_filter.hide()
	if _curse_button != null:
		_curse_button.hide()
		_curse_label.hide()
	_shop_items_container.show()
	_hbox2.size_flags_vertical = Control.SIZE_FILL
	_hbox3.size_flags_vertical = Control.SIZE_EXPAND_FILL


func general_buy(item_data:ItemParentData):
	_fifth_shopitem.set_shop_item(item_data)
	# ekjg buy-fix (local): call the ShopItemsContainer purchase handler directly
	# instead of simulating a press on the hidden card's BuyButton. Calling
	# ShopItem._on_BuyButton_pressed() on a pooled/hidden card re-enters the card's
	# own button wiring on some game builds (observed as infinite recursion ->
	# stack overflow -> hard crash on buy). The container handler below is the
	# exact entry point the vanilla shelf buy uses (its signal target), so the
	# purchase semantics are unchanged.
	if is_instance_valid(_shop_items_container):
		_shop_items_container.on_shop_item_buy_button_pressed(_fifth_shopitem)


#func buy_item(shop_item:ShopItem, number:int = 1)->bool:
#	var real_number:int = number
#	# 判断是否有数量限制
#	if shop_item.item_data.max_nb != -1:
#		var current_number = 0
#		for item in RunData.items:
#			if item.my_id == shop_item.item_data.my_id:
#				current_number += 1
#		var allow_number = shop_item.item_data.max_nb - current_number
#		if number > allow_number:
#			real_number = allow_number
#
#	# 钱不够
#	if RunData.get_currency() < shop_item.value * real_number:
#		return false
#
#	# 需要更快速大量购买，可能导致其他mod效果失效
#
#	# 扣钱
#	RunData.remove_currency(shop_item.value * real_number)
#
#	# 更新优惠券的已优惠数据
#	var nb_coupons = RunData.get_nb_item("item_coupon")
#	if nb_coupons > 0:
#		var coupon_value = get_coupon_value()
#		var coupon_effect = nb_coupons * (coupon_value / 100.0)
#		var base_value = ItemService.get_value(shop_item.wave_value, shop_item.item_data.value, false, shop_item.item_data is WeaponData)
#		RunData.tracked_item_effects["item_coupon"] += (base_value * coupon_effect * real_number) as int
#
#	# 兼容“原版信号补充”mod中的购买信号
#	var has_signalApi:bool = false
#	if _mod_tool.has_mod("Lasonbrah-signalApi"):
#		emit_signal("onShopItemBoughtStart",shop_item)
#		has_signalApi = true
#
#	# 向数据中添加道具，来自RunData.add_item()函数
#	_othershopitem.show_progressbar()
#	RunData.add_item(shop_item.item_data)
#	if real_number > 1:
#		for i in range(1, real_number - 1):
#			if i % 256 == 0:
#				# 抽空更新进度条
#				_othershopitem.set_progressbar_value(i * 100 / number)
#				yield()
#			RunData.items.push_back(shop_item.item_data)
#			RunData.apply_item_effects(shop_item.item_data)
#			RunData.add_item_displayed(shop_item.item_data)
#		RunData.add_item(shop_item.item_data)
#	_othershopitem.hide_progressbar()
#
#	# 兼容“原版信号补充”mod中的购买信号
#	if has_signalApi:
#		emit_signal("onShopItemBought",shop_item)
#
#	# 属性栏更新
#	_stats_container.update_stats()
#
#	# 原代码是发送信号，更新道具栏，这里跳过中间信号回调，直接修改
#	# emit_signal("item_bought", shop_item.item_data)
#	var e_s = _items_container._elements
#	# 先查找是否是已有道具
#	var children = e_s.get_children()
#	var element_already_exists = false
#	for child in children:
#		if child.item != null and child.item.my_id == shop_item.item_data.my_id:
#			child.add_to_number(real_number)
#			element_already_exists = true
#	if not element_already_exists:
#		# 没拿过道具就先添加
#		e_s.spawn_element(shop_item.item_data)
#		if real_number > 1:
#			var children_ = e_s.get_children()
#			for child in children_:
#				if child.item != null and child.item.my_id == shop_item.item_data.my_id:
#					child.add_to_number(real_number - 1)
#
#	# 购买免费刷新道具需要更新数据
#	var has_new_rerolls = false
#	if RunData.effects["free_rerolls"] > _initial_free_rerolls:
#		var new_rerolls = RunData.effects["free_rerolls"] - _initial_free_rerolls
#		_initial_free_rerolls = RunData.effects["free_rerolls"]
#		_free_rerolls += new_rerolls
#		has_new_rerolls = true
#
#	# 刷新按钮更新
#	if has_new_rerolls:
#		set_reroll_button_price()
#	else :
#		_reroll_button.set_color_from_currency(RunData.gold)
#
#	# 商品购买按钮更新
#	shop_item.update_color()
#	_hbox2.get_node("ShopItemsContainer").update_buttons_color()
#
#	return true


#func buy_weapon(shop_item:ShopItem)->bool:
#	# 钱不够
#	if RunData.get_currency() < shop_item.value:
#		return false
#
#	# 针对武器，判断玩家是否可以购买武器
#	var player_has_weapon = false
#	# 判断玩家是否有该武器
#	for weapon in RunData.weapons:
#		if weapon.my_id == shop_item.item_data.my_id:
#			player_has_weapon = true
#			break
#
#	# 在没有武器空槽时，玩家没有该武器，武器为顶级，武器升级超过稀有度限制
#	if (shop_item.item_data.get_category() == Category.WEAPON
#		 and not RunData.has_weapon_slot_available(shop_item.item_data.type)
#		 and (
#			 not player_has_weapon
#			 or shop_item.item_data.upgrades_into == null
#			 or (RunData.effects["max_weapon_tier"] < shop_item.item_data.upgrades_into.tier)
#			)
#		):
#		return false
#	# 处理禁止近战或远程，稀有度限制
#	if (shop_item.item_data.get_category() == Category.WEAPON
#		 and (
#			(shop_item.item_data.type == WeaponType.MELEE and RunData.effects["no_melee_weapons"])
#			 or 
#			(shop_item.item_data.type == WeaponType.RANGED and RunData.effects["no_ranged_weapons"])
#			 or 
#			(RunData.effects["min_weapon_tier"] > shop_item.item_data.tier)
#			 or 
#			(RunData.effects["max_weapon_tier"] < shop_item.item_data.tier)
#		)):
#			return false
#
#	general_buy(shop_item.item_data)
#	return true


func on_supermarket_button_toggled(button_pressed:bool):
	var reroll_button = $Content/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/RerollButton
	var go_button = $Content/MarginContainer/HBoxContainer/VBoxContainer2/GoButton
	if button_pressed:
		supermarket_open()
		# 保存打开前的原生焦点邻居（只保存一次），关闭时恢复，避免硬编码场景路径
		if _saved_reroll_bottom == null:
			_saved_reroll_bottom = reroll_button.focus_neighbour_bottom
		if _saved_go_top == null:
			_saved_go_top = go_button.focus_neighbour_top
		# 设置部分按钮的键盘焦点移动：刷新按钮向下跳到筛选器
		reroll_button.set_focus_neighbour(MARGIN_BOTTOM,
				reroll_button.get_path_to(_filter._option_category))
		go_button.set_focus_neighbour(MARGIN_TOP,NodePath(""))
	else:
		supermarket_close()
		# 恢复打开前保存的焦点邻居
		if _saved_reroll_bottom != null:
			reroll_button.set_focus_neighbour(MARGIN_BOTTOM, _saved_reroll_bottom)
		if _saved_go_top != null:
			go_button.set_focus_neighbour(MARGIN_TOP, _saved_go_top)


func on_othershopitem_buybutton_pressed(shop_item:ShopItem, number:int):
	var item_number_is_max:bool = false
	# yield 期间 shop_item 卡片节点可能被释放，先取出数据引用（Resource 不随节点释放）
	var item_data:ItemParentData = shop_item.item_data
	if item_data.get_category() == Category.WEAPON:
		for i in number:
			if i > 0:
				# 武器处理需要时间
				yield(get_tree().create_timer(0.1), "timeout")
			general_buy(item_data)
	elif item_data.get_category() == Category.ITEM:
		for i in range(number):
			if item_data.max_nb != -1:
				var nb_owned:int = 0
				for owned in RunData.get_player_items(0):
					if owned.my_id == item_data.my_id:
						nb_owned += 1
				if nb_owned >= item_data.max_nb:
					break
			if i > 0:
				# 武器处理需要时间
				yield(get_tree().create_timer(0.1), "timeout")
			general_buy(item_data)
			
		# yield 后商店可能已关闭/刷新，节点已释放则直接退出
		if not is_instance_valid(_supermarket) or not is_instance_valid(_othershopitem):
			return
		# 判断道具是否达到上限
		if item_data.max_nb != -1:
			var current_number = 0
			for item in RunData.get_player_items(0):
				if item.my_id == item_data.my_id:
					current_number += 1
			if current_number >= item_data.max_nb:
				item_number_is_max = true
			# 感觉怪怪的，以后再说
			_supermarket.show_remaining_quantity(_element_pressed, current_number)
	
	# 从道具池移除到达数量上限的道具，将就用，凑合吧
	# yield 后统一校验节点有效性
	if not is_instance_valid(_supermarket) or not is_instance_valid(_othershopitem) or not is_instance_valid(_filter_manager):
		return
	if item_number_is_max:
		var elements = _filter_manager.elements
		for i in elements:
			if i[1].has(item_data):
				i[1].erase(item_data)
				break
	
	if item_number_is_max:
		_element_focused = null
		_element_hovered = null
		_element_pressed = null
		# 统一走刷新逻辑：更新剩余数量并立即移除已购满的道具（与原版商店购买路径一致，remove_child 立即生效）
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
	if _element_pressed != null and is_instance_valid(_element_pressed) and _element_pressed.is_visible_in_tree():
		_element_pressed.grab_focus()
		# 如果有物品移除，需要等待位置刷新
		yield(get_tree().create_timer(0.01), "timeout")
		if _element_pressed != null and is_instance_valid(_element_pressed) and is_instance_valid(_othershopitem):
			_othershopitem.set_shopitem(_element_pressed)
	else:
#		_go_button.grab_focus()
		# 超市可能已在收到取消前关闭（竞态），隐藏控件不能接焦点
		if is_instance_valid(_filter) and _filter._option_category.is_visible_in_tree():
			_filter._option_category.grab_focus()
		elif is_instance_valid(_supermarket_button) and _supermarket_button.is_visible_in_tree():
			_supermarket_button.grab_focus()
	_element_pressed = null


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
	# 防止右侧属性栏禁用键盘焦点
	_stats_container.enable_focus()


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


func on_filter_manager_supermarket_changed():
	_element_pressed = null
	_element_focused = null
	_element_hovered = null


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
