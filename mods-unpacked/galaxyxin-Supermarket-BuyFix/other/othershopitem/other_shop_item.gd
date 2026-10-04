extends Node

signal mouse_hovered_category(shop_item)
signal mouse_exited_category(shop_item)
signal buy_button_pressed(shop_item, number)
signal lockbutton_toggled(button_pressed)
signal cancel_button_pressed()

var _armed:bool = false
var _press_token:int = 0
var _mouse_or_key_down:bool = false
var _emulating:bool = false
var _ws_dir:int = 0
var _ws_hold:float = 0.0
var _ws_accum:float = 0.0
var _ws_real:bool = false
var _ws_minus:Button = null
var _ws_plus:Button = null
var _ws_toggle:Button = null
var _ws_count:int = 1
var _ws_count_label:Label = null
var _ws_side_left:bool = false
var _ws_action:String = ""
var _e_was_down:bool = false
var _ws_reveal_token:int = 0
var _ekjg_info_hidden:bool = false
var _ekjg_preview_active:bool = false

var _shop_node:CanvasItem

onready var _cover = $Cover
onready var _shopitem = $ShopItem
onready var _shopitem_lock = $ShopItem/TopButtonsContainer/LockButton
onready var _shopitem_buybutton = $ShopItem/PanelContainer/MarginContainer/VBoxContainer/BuyButton
onready var _wholesale = $Wholesale
onready var _wholesale_lineedit = $Wholesale/MarginContainer/HBoxContainer/VBoxContainer/LineEdit
onready var _wholesale_closebutton = $Wholesale/MarginContainer/HBoxContainer/CloseWholesale
onready var _cancel_button = $CancelHolder/Cancel
onready var _timer = $Timer
onready var _progressbar = $ProgressBar
onready var _cover2 = $Cover2
onready var _tip = $Tip
onready var _tip_close = $Tip/MarginContainer/VBoxContainer/HBoxContainer/TipClose

var _last_element_item = null
var _last_element_position:Vector2 = Vector2.ZERO
var _last_element_tier = Tier.COMMON

var _buybutton_click_count:int = 0
const BUY_TIP_MIN_CLICK_COUNT:int = 100

var _setting_up_item:bool = false

func initialization(shop_node:CanvasItem):
	_shop_node = shop_node
	_ekjg_update_close_icon()


func _ready():
	if _shopitem_lock.is_connected("toggled", _shopitem, "_on_LockButton_toggled"):
		_shopitem_lock.disconnect("toggled", _shopitem, "_on_LockButton_toggled")
	_shopitem_lock.toggle_mode = false
	_shopitem_lock.pressed = false
	_shopitem_lock.focus_mode = Control.FOCUS_ALL
	_shopitem_lock.text = "关闭" if TranslationServer.get_locale().begins_with("zh") else "Close"
	_shopitem_lock.connect("pressed", self, "_on_Cancel_pressed")
	# 关闭按钮图标: 按玩家实际输入设备显示(键盘E/手柄对应键), 合作模式按各自玩家的设备
	call_deferred("_ekjg_update_close_icon")
	if _shopitem_buybutton.is_connected("pressed",_shopitem,"_on_BuyButton_pressed"):
		_shopitem_buybutton.disconnect("pressed",_shopitem,"_on_BuyButton_pressed")
	_shopitem_buybutton.connect("button_down",self,"on_shopitem_buybutton_button_down")
	_shopitem_buybutton.connect("button_up",self,"on_shopitem_buybutton_button_up")
	_shopitem_buybutton.connect("pressed",self,"on_shopitem_buybutton_pressed_emulated")
	set_process(false)
	_ws_minus = Button.new()
	_ws_minus.text = " - "
	_ws_plus = Button.new()
	_ws_plus.text = " + "
	var _ws_hbox = _wholesale.get_node("MarginContainer/HBoxContainer")
	_ws_hbox.add_child(_ws_minus)
	_ws_hbox.move_child(_ws_minus, 0)
	_ws_hbox.add_child(_ws_plus)
	_ws_hbox.move_child(_ws_plus, _ws_hbox.get_child_count() - 2)
	_ws_minus.connect("button_down", self, "_on_ws_minus_down")
	_ws_minus.connect("button_up", self, "_on_ws_button_up")
	_ws_plus.connect("button_down", self, "_on_ws_plus_down")
	_ws_plus.connect("button_up", self, "_on_ws_button_up")
	_ws_minus.connect("pressed", self, "_on_ws_pressed_emulated", [-1])
	_ws_plus.connect("pressed", self, "_on_ws_pressed_emulated", [1])
	_ws_toggle = Button.new()
	_ws_toggle.text = tr("ekJg5ZS1_WHOLESALE")
	var _ws_top = _shopitem.get_node("TopButtonsContainer")
	_ws_top.add_child(_ws_toggle)
	_ws_top.move_child(_ws_toggle, 0)
	_ws_toggle.connect("pressed", self, "_on_ws_toggle_pressed")
	_wholesale_lineedit.hide()
	_ws_count_label = Label.new()
	_ws_count_label.set_text("1")
	_ws_count_label.align = Label.ALIGN_CENTER
	_ws_count_label.valign = Label.VALIGN_CENTER
	_ws_count_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _ws_vbox = _wholesale.get_node("MarginContainer/HBoxContainer/VBoxContainer")
	_ws_count_label.add_font_override("font", _ws_vbox.get_node("Label").get_font("font"))
	_ws_vbox.add_child(_ws_count_label)
	# wholesale focus chain: minus <-> plus <-> close, down -> buy button
	_ws_minus.set_focus_neighbour(MARGIN_LEFT, NodePath("."))
	_ws_minus.set_focus_neighbour(MARGIN_TOP, NodePath("."))
	_ws_minus.set_focus_neighbour(MARGIN_RIGHT, _ws_minus.get_path_to(_ws_plus))
	_ws_minus.set_focus_neighbour(MARGIN_BOTTOM, _ws_minus.get_path_to(_shopitem_buybutton))
	_ws_plus.set_focus_neighbour(MARGIN_LEFT, _ws_plus.get_path_to(_ws_minus))
	_ws_plus.set_focus_neighbour(MARGIN_TOP, NodePath("."))
	_ws_plus.set_focus_neighbour(MARGIN_RIGHT, _ws_plus.get_path_to(_wholesale_closebutton))
	_ws_plus.set_focus_neighbour(MARGIN_BOTTOM, _ws_plus.get_path_to(_shopitem_buybutton))
	_wholesale_closebutton.set_focus_neighbour(MARGIN_LEFT, _wholesale_closebutton.get_path_to(_ws_plus))
	_wholesale_closebutton.set_focus_neighbour(MARGIN_TOP, NodePath("."))
	_wholesale_closebutton.set_focus_neighbour(MARGIN_RIGHT, NodePath("."))
	_wholesale_closebutton.set_focus_neighbour(MARGIN_BOTTOM, _wholesale_closebutton.get_path_to(_shopitem_buybutton))
	# trap focus inside the card so selection cannot escape onto the list
	_shopitem_buybutton.set_focus_neighbour(MARGIN_LEFT, _shopitem_buybutton.get_path_to(_ws_toggle))
	_shopitem_buybutton.set_focus_neighbour(MARGIN_RIGHT, _shopitem_buybutton.get_path_to(_shopitem_lock))
	_shopitem_buybutton.set_focus_neighbour(MARGIN_BOTTOM, _shopitem_buybutton.get_path_to(_ws_toggle))
	_ws_toggle.set_focus_neighbour(MARGIN_LEFT, NodePath("."))
	_ws_toggle.set_focus_neighbour(MARGIN_TOP, _ws_toggle.get_path_to(_shopitem_buybutton))
	_ws_toggle.set_focus_neighbour(MARGIN_RIGHT, _ws_toggle.get_path_to(_shopitem_lock))
	_ws_toggle.set_focus_neighbour(MARGIN_BOTTOM, NodePath("."))
	_shopitem_lock.set_focus_neighbour(MARGIN_LEFT, _shopitem_lock.get_path_to(_ws_toggle))
	_shopitem_lock.set_focus_neighbour(MARGIN_TOP, _shopitem_lock.get_path_to(_shopitem_buybutton))
	_shopitem_lock.set_focus_neighbour(MARGIN_RIGHT, NodePath("."))
	_shopitem_lock.set_focus_neighbour(MARGIN_BOTTOM, NodePath("."))


func _input(event):
	var flag = false
	if event is InputEventJoypadButton && event.pressed && event.button_index == JOY_XBOX_B :
		flag = true
	if event is InputEventKey && event.pressed && event.scancode == KEY_ESCAPE:
		flag = true
	if event is InputEventKey && event.pressed && event.scancode == KEY_E:
		flag = true
	# 与图标一致的关闭键: ui_select(键盘E/手柄X), 合作模式按玩家自己设备的动作
	if _shop_node != null and ("player_index" in _shop_node) and Utils.is_player_action_pressed(event, _shop_node.player_index, "ui_select"):
		flag = true
	
	if flag and _cancel_button.is_visible():
		_on_Cancel_pressed()
		get_tree().set_input_as_handled()

	# 原版 F(键盘)/X(手柄) ui_info 开关详细信息: 超市卡片同步适配, 合作模式按各自玩家设备
	var ekjg_pidx:int = 0
	if _shop_node != null and ("player_index" in _shop_node):
		ekjg_pidx = _shop_node.player_index
	if _ekjg_preview_active and not _cancel_button.visible and Utils.is_player_info_pressed(event, ekjg_pidx):
		_ekjg_info_hidden = not _ekjg_info_hidden
		_shopitem.visible = not _ekjg_info_hidden
		# 同步原生开关提示(合作模式 TogglePopupHint / 原生 item_popup 状态)
		if _shop_node != null and _shop_node.has_method("ekjg_on_supermarket_info_toggled"):
			_shop_node.ekjg_on_supermarket_info_toggled(_ekjg_info_hidden)


func show():
	_ekjg_preview_active = true
	# F/X 已切换为隐藏详情时, 预览保持隐藏
	_shopitem.visible = not _ekjg_info_hidden


func hide():
	_ekjg_preview_active = false
	_shopitem.hide()


func set_shopitem(element):
	if element == null or not is_instance_valid(element):
		return
	_setting_up_item = true
	# 本帧只定位不渲染，下一帧再显示
	_shopitem.modulate.a = 0.0
	_ws_reveal_token += 1
	var _my_token = _ws_reveal_token
	var item = element.item
	_shopitem.set_shop_item(item)
	_shopitem_lock.text = "关闭" if TranslationServer.get_locale().begins_with("zh") else "Close"
	if not _shopitem._lock_button.is_visible():
		# 防止可能有mod隐藏锁定按钮
		_shopitem._lock_button.show()
	if _shopitem._lock_button.disabled:
		# 沙漏等不可锁定物品：原版会置灰锁定按钮，mod 已将其用作“关闭”，需重新启用
		_shopitem._lock_button.activate()
	_shopitem_buybutton.rect_min_size = _shopitem_buybutton.get_node("HBoxContainer").get_combined_minimum_size()
	# 同帧先定位一次；布局刷新完成后（本帧绘制前）再按真实尺寸校正一次
	_ws_position_card(element)
	call_deferred("_ws_position_card", element)

	if item.tier != _last_element_tier and is_locked():
		# 将就用，否则锁定时，移动至其他商品上购买框颜色不会变
		_shopitem.unlock_visually()
		_shopitem.lock_visually()

	_last_element_tier = item.tier

	# 提示相关
	if not _last_element_item == item:
		_last_element_item = item
		_buybutton_click_count = 0

	_setting_up_item = false

	if _cancel_button.visible:
		_grab(_shopitem_buybutton)
	# 位置已最终确定，下一帧显示
	if get_tree() == null:
		return
	yield(get_tree(), "idle_frame")
	if _my_token == _ws_reveal_token and is_instance_valid(_shopitem):
		_shopitem.modulate.a = 1.0


func _ws_position_card(element):
	if element == null or not is_instance_valid(element):
		return
	if _shopitem == null or not is_instance_valid(_shopitem):
		return
	# 重算尺寸；卡片过长则整体缩放到屏幕内（含底部批发/关闭按钮）
	_shopitem.rect_scale = Vector2(1, 1)
	_shopitem.rect_size = Vector2(0, 0)
	var ws_vp:Vector2 = _shop_node.get_viewport_rect().size
	if _shopitem.rect_size.y > ws_vp.y:
		var ws_s:float = ws_vp.y / _shopitem.rect_size.y
		_shopitem.rect_scale = Vector2(ws_s, ws_s)
	var ws_card:Vector2 = _shopitem.rect_size * _shopitem.rect_scale
	var element_position:Vector2 = element.get_global_position()
	var element_size:Vector2 = element.get_size()
	# 记忆显示方向；同列（上下移动）时沿用上次方向，并按当前真实宽度重新对齐
	var ws_left:bool = _ws_side_left
	if element_position.x > _last_element_position.x:
		ws_left = true
	elif element_position.x < _last_element_position.x:
		ws_left = false
	_ws_side_left = ws_left
	if ws_left:
		# 在物品左侧显示
		_shopitem.rect_global_position.x = element_position.x - ws_card.x - 5
		if _shopitem.rect_global_position.x < 0:
			# 空间不足则在右侧显示
			_shopitem.rect_global_position.x = element_position.x + element_size.x + 5
	else:
		# 在物品右侧显示
		_shopitem.rect_global_position.x = element_position.x + element_size.x + 5
	if _shopitem.rect_global_position.x + ws_card.x > ws_vp.x:
		_shopitem.rect_global_position.x = ws_vp.x - ws_card.x
	if _shopitem.rect_global_position.x < 0:
		_shopitem.rect_global_position.x = 0
	_shopitem.rect_global_position.y = element_position.y + element_size.y + 5
	if _shopitem.rect_global_position.y + ws_card.y > ws_vp.y:
		_shopitem.rect_global_position.y = ws_vp.y - ws_card.y
	if _shopitem.rect_global_position.y < 0:
		_shopitem.rect_global_position.y = 0
	_last_element_position = element_position
	# 取消按钮盖在货架物品上
	_cancel_button.rect_global_position = element_position
	_cancel_button.rect_size = element_size



func is_locked()->bool:
	return false


func _on_shopitem_LockButton_toggled(button_pressed:bool):
	if button_pressed:
		_shopitem.lock_visually()
	else:
		_shopitem.unlock_visually()
	emit_signal("lockbutton_toggled", button_pressed)


func on_shopitem_buybutton_button_down():
	if not _emulating:
		_mouse_or_key_down = true
	_armed = true


func on_shopitem_buybutton_button_up():
	call_deferred("_reset_mouse_flag")
	if not _armed:
		return
	_armed = false
	_timer.stop()
	if _wholesale.is_visible():
		var number = _ws_count
		if number > 0:
			emit_signal("buy_button_pressed", _shopitem, number)
			# 购买后重置
			_ws_reset_count()
			_shopitem_buybutton.set_value(_shopitem.value, _ws_gold())
	else:
		if _setting_up_item:
			return
		emit_signal("buy_button_pressed", _shopitem, 1)
		_buybutton_click_count += 1
		# 点击超过100次，显示提示
		if false: # tip disabled: long-press wholesale removed, use the wholesale button
			_cover2.show()
			_tip.show()
			_grab(_tip_close)
			_buybutton_click_count = 0


func _on_LineEdit_text_changed(new_text):
	var number = int(new_text)
	var length = new_text.length()
	var position = _wholesale_lineedit.get_cursor_position()
	if number > 0:
		var number_text = String(number)
		_wholesale_lineedit.set_text(number_text)
		if length > number_text.length():
			_wholesale_lineedit.set_cursor_position(position - 1)
		else:
			_wholesale_lineedit.set_cursor_position(position)
	else:
		_ws_reset_count()
	# 设置按钮上显示的价格
	_shopitem_buybutton.set_value(_shopitem.value * number, _ws_gold())
	


func _on_Timer_timeout():
	# 打开批发界面
	_wholesale.show()
	var a = (_shopitem.rect_size.x * _shopitem.rect_scale.x - _wholesale.rect_size.x) / 2
	_wholesale.rect_position.x = _shopitem.rect_position.x + a
	var b = _shopitem_buybutton.rect_global_position.y
	_wholesale.rect_global_position.y = b - _wholesale.rect_size.y - 5
	# 批发面板不允许超出屏幕；上方放不下则放到购买按钮下方
	var ws_vp2:Vector2 = _shop_node.get_viewport_rect().size
	if _wholesale.rect_global_position.x + _wholesale.rect_size.x > ws_vp2.x:
		_wholesale.rect_global_position.x = ws_vp2.x - _wholesale.rect_size.x
	if _wholesale.rect_global_position.x < 0:
		_wholesale.rect_global_position.x = 0
	if _wholesale.rect_global_position.y < 0:
		_wholesale.rect_global_position.y = b + _shopitem_buybutton.rect_size.y * _shopitem.rect_scale.y + 5
	
	# 修改购买按钮相邻焦点，向上为编辑框
	_shopitem_buybutton.set_focus_neighbour(MARGIN_TOP,
			_shopitem_buybutton.get_path_to(_ws_plus))
	_ws_reset_count()
	_shopitem_buybutton.set_value(_shopitem.value, _ws_gold())
	_grab(_ws_plus)
	
	_buybutton_click_count = 0


func _on_CloseWholesale_pressed():
	# 关闭批发界面
	_wholesale.hide()
	_ws_reset_count()
	_shopitem_buybutton.set_value(_shopitem.value, _ws_gold())
	_ws_toggle.set_focus_neighbour(MARGIN_TOP, _ws_toggle.get_path_to(_shopitem_buybutton))
	_grab(_ws_toggle)
	
	# 修改购买按钮相邻焦点，向上为取消按钮
	_shopitem_buybutton.set_focus_neighbour(MARGIN_TOP,
			_shopitem_buybutton.get_path_to(_cancel_button))


func _on_LineEdit_text_entered(_new_text):
	_armed = true
	# 按回车购买
	on_shopitem_buybutton_button_up()


func pressed_element():
	# 按下进入交互态: 即使 F/X 已隐藏详情也强制显示卡片, 否则无法操作
	_shopitem.visible = true
	_armed = false
	_press_token += 1
	var my_token:int = _press_token
	_shopitem.show()
	_cover.show()
	_cancel_button.show()
	_e_was_down = Input.is_key_pressed(KEY_E)
	set_process(true)
	yield(get_tree().create_timer(0.01), "timeout")
	# 按下即打开卡片并跳转到购买；松开时购买按钮没收到过 button_down，_armed 守卫会忽略这次松开
	if my_token != _press_token:
		return
	if not _shopitem.visible or not _cancel_button.visible:
		return
	_grab(_shopitem_buybutton)


func _on_Cancel_pressed():
	_armed = false
	_press_token += 1
	_cancel_button.hide()
	_on_CloseWholesale_pressed()
	_shopitem.hide()
	_cover.hide()
	emit_signal("cancel_button_pressed")


func show_progressbar():
	_progressbar.show()


func hide_progressbar():
	_progressbar.hide()


func set_progressbar_value(value:float):
	_progressbar.set_value(value)


func _on_TipClose_pressed():
	_cover2.hide()
	_grab(_shopitem_buybutton)
	_tip.hide()


func _on_ShopItem_mouse_hovered_category(shop_item):
	emit_signal("mouse_hovered_category", shop_item)


func _on_ShopItem_mouse_exited_category(shop_item):
	emit_signal("mouse_exited_category", shop_item)


func _is_accept_held()->bool:
	if Input.is_mouse_button_pressed(BUTTON_LEFT):
		return true
	if Input.is_action_pressed("ui_accept"):
		return true
	for d in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(d, JOY_XBOX_A):
			return true
	return false


func _reset_mouse_flag():
	_mouse_or_key_down = false


func on_shopitem_buybutton_pressed_emulated():
	# real mouse/keyboard input is handled by button_down/button_up above
	if _mouse_or_key_down:
		return
	# coop FocusEmulator only emits "pressed": emulate down/up with hold detection
	if _emulating:
		return
	_emulating = true
	on_shopitem_buybutton_button_down()
	var action:String = _get_player_accept_action()
	if action == "" or not InputMap.has_action(action):
		_emulating = false
		on_shopitem_buybutton_button_up()
		return
	var frames:int = 0
	while Input.is_action_pressed(action) and frames < 3600:
		frames += 1
		if get_tree() == null:
			_emulating = false
			return
		yield(get_tree(), "idle_frame")
	on_shopitem_buybutton_button_up()
	_emulating = false


func _get_player_accept_action()->String:
	if not RunData.is_coop_run:
		return ""
	if _shop_node == null or not ("player_index" in _shop_node):
		return ""
	var device:int = CoopService.get_remapped_player_device(_shop_node.player_index)
	if device < 0:
		return ""
	return "ui_accept_%s" % device


func force_close():
	# close everything silently: no signals, no focus changes
	_timer.stop()
	_armed = false
	_ws_dir = 0
	_ws_action = ""
	_e_was_down = false
	set_process(false)
	_wholesale.hide()
	_ws_reset_count()
	_cancel_button.hide()
	_cover.hide()
	_cover2.hide()
	_tip.hide()
	_progressbar.hide()
	_shopitem.hide()


func _on_ws_minus_down():
	_ws_real = true
	_ws_start(-1)


func _on_ws_plus_down():
	_ws_real = true
	_ws_start(1)


func _ws_start(dir:int):
	_ws_apply(dir)
	_ws_dir = dir
	_ws_hold = 0.0
	_ws_accum = 0.0
	set_process(true)


func _on_ws_button_up():
	_ws_dir = 0
	_ws_action = ""
	call_deferred("_ws_reset_real")


func _ws_reset_real():
	_ws_real = false


func _on_ws_pressed_emulated(dir:int):
	# coop FocusEmulator 只发 "pressed", 没有 button_down/up
	if _ws_real:
		return
	_ws_apply(dir)
	# task4: 按住连发: 轮询该玩家的 accept 动作(手柄A / 键盘回车、空格), 松开前持续加减
	var ekjg_action:String = _get_player_accept_action()
	if ekjg_action == "" or not InputMap.has_action(ekjg_action):
		# 键盘适配: 非合作或取不到设备专属动作时, 回退到通用 ui_accept
		ekjg_action = "ui_accept"
	if not InputMap.has_action(ekjg_action) or not Input.is_action_pressed(ekjg_action):
		return
	_ws_action = ekjg_action
	_ws_dir = dir
	_ws_hold = 0.0
	_ws_accum = 0.0
	set_process(true)


func _process(delta):
	# task1: coop 下 FocusEmulator 会吞掉原始按键事件, _input 收不到 E, 改为轮询关闭卡片
	if _cancel_button != null and _cancel_button.is_visible():
		if Input.is_key_pressed(KEY_E):
			if not _e_was_down:
				_e_was_down = true
				_on_Cancel_pressed()
				return
		else:
			_e_was_down = false
	else:
		_e_was_down = false
	if _ws_dir == 0:
		if _cancel_button == null or not _cancel_button.is_visible():
			set_process(false)
		return
	# task4: 合作模拟按压没有 button_up, 轮询 accept 动作判断松开停止连发
	if _ws_action != "" and not Input.is_action_pressed(_ws_action):
		_ws_dir = 0
		_ws_action = ""
		return
	_ws_hold += delta
	# speed grows with hold time: ~3/s at start, capped at 60/s
	var rate:float = 3.0 + min(_ws_hold * _ws_hold * 12.0, 57.0)
	_ws_accum += delta * rate
	var steps:int = int(_ws_accum)
	if steps > 0:
		_ws_accum -= steps
		_ws_apply(_ws_dir * steps)


func _ws_gold()->int:
	if _shop_node != null and ("player_index" in _shop_node):
		return RunData.get_player_currency(_shop_node.player_index)
	return RunData.get_player_currency(0)


func _ws_max()->int:
	var money_max:int = 9999
	var v:int = int(_shopitem.value)
	if v > 0:
		money_max = int(floor(float(_ws_gold()) / float(v)))
	# 限制道具：批发上限不超过剩余可购数量
	var data = _shopitem.item_data
	if data != null and data.get_category() == Category.ITEM and data.max_nb != -1:
		var idx:int = 0
		if _shop_node != null and ("player_index" in _shop_node):
			idx = _shop_node.player_index
		var owned:int = 0
		for item in RunData.get_player_items(idx):
			if item.my_id == data.my_id:
				owned += 1
		var remain:int = data.max_nb - owned
		if remain < 1:
			remain = 1
		if remain < money_max:
			money_max = remain
	# task5: weapon wholesale capped by free weapon slots
	if data != null and data.get_category() == Category.WEAPON:
		var widx:int = 0
		if _shop_node != null and ("player_index" in _shop_node):
			widx = _shop_node.player_index
		var free_slots:int = RunData.get_free_weapon_slots(widx)
		if free_slots < 1:
			free_slots = 1
		if free_slots < money_max:
			money_max = free_slots
	return money_max


func _ws_apply(step:int):
	if not _wholesale.is_visible():
		return
	_ws_count = int(clamp(_ws_count + step, 1, max(_ws_max(), 1)))
	_ws_count_label.set_text(String(_ws_count))
	_shopitem_buybutton.set_value(_shopitem.value * _ws_count, _ws_gold())


func _ws_reset_count():
	_ws_count = 1
	if _ws_count_label != null:
		_ws_count_label.set_text("1")


func _on_ws_toggle_pressed():
	# dedicated wholesale button next to the lock button
	if _wholesale.is_visible():
		_on_CloseWholesale_pressed()
	else:
		_timer.stop()
		_on_Timer_timeout()


func _grab(control:Control):
	# in coop, native focus is useless for gamepad players: route through FocusEmulator
	if control == null or not is_instance_valid(control):
		return
	if RunData.is_coop_run and _shop_node != null and ("player_index" in _shop_node):
		var em = Utils.get_focus_emulator(_shop_node.player_index)
		if em != null:
			Utils.focus_player_control(control, _shop_node.player_index, em)
		return
	control.grab_focus()



func _ekjg_update_close_icon():
	if _shopitem_lock == null or not is_instance_valid(_shopitem_lock):
		return
	var ekjg_icon = _shopitem_lock.get_node_or_null("AdditionalIcon")
	if ekjg_icon == null:
		return
	if RunData.is_coop_run and _shop_node != null and ("player_index" in _shop_node):
		ekjg_icon.player_index = _shop_node.player_index
	if ekjg_icon.has_method("_change_controller"):
		ekjg_icon._change_controller()
	ekjg_icon.show()
