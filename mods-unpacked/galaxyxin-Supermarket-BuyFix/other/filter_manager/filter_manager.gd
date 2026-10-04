extends Node

signal supermarket_changed()

var _supermarket
var _filter

var _mod_tool:Node = null
var elements = []



func _ready():
	_mod_tool = get_node("/root/ModLoader/galaxyxin-Supermarket-BuyFix/工具")

func init_link_node(supermarket_node, filter_node, stats_container):
	# 超市
	_supermarket = supermarket_node
	# 过滤器
	_filter = filter_node
	_filter.connect("filter_data_changed", self, "on_filter_filter_data_changed")
	# 右侧属性面板，链接点击信号
	if stats_container != null:
		_mod_tool.stat_container_init(stats_container, self, "on_stats_button_pressed")
	
	# 初始化，设置超市物品
	elements = _mod_tool.get_pool_all_item(RunData.current_wave, _supermarket.player_index)
	_filter.reset(true)


func update(param = 0):
	on_filter_filter_data_changed(_filter.data, param)


func on_stats_button_pressed(_stats,stats_text,_value):
	if _filter.is_visible():
		_filter.add_stat(_stats.key)


func on_filter_filter_data_changed(filter_data, _param = 0):
	
	var elements_final:Array = []
	
	var filter_mod_name:String = filter_data["mod"]
	var filter_weapon_or_item:int = filter_data["weapon or item"]
	var filter_weapon_type:int = filter_data["weapon type"]
	var filter_weapon_class:String = filter_data["weapon class"]
	var filter_weapon_scaling_stat:String = filter_data["weapon scaling stat"]
	var filter_item_number_limit:int = filter_data["item number limit"]
	var filter_item_effects:Dictionary = filter_data["item effect"]
	var filter_item_special_effect:int = filter_data["item special effect"]
	
	# 信号发送至shop.gd
	emit_signal("supermarket_changed")
	
	
	var elements_0:Array = []
	if not filter_mod_name.empty():
		var _contentloader_mod_node = get_node_or_null("/root/ModLoader/Darkly77-ContentLoader/ContentLoader")
		if _contentloader_mod_node != null:
			var mod_name:String = filter_mod_name
			if mod_name == "base":
				mod_name = "CL_Notice-NotFound"
			for w_i in elements:
				var weapons:Array = []
				var items:Array = []
				for weapon in w_i[0]:
					if _contentloader_mod_node.lookup_modid_by_itemdata(weapon) == mod_name:
						weapons.push_back(weapon)
				for item in w_i[1]:
					if _contentloader_mod_node.lookup_modid_by_itemdata(item) == mod_name:
						items.push_back(item)
				elements_0.push_back([weapons, items])
		else:
			elements_0 = elements.duplicate()
	else:
		elements_0 = elements.duplicate()
	
	match filter_weapon_or_item:
		0:
			# 显示全部
			if elements_0.size() > 0:
				for weapons_and_items in elements_0:
					if not weapons_and_items[0].empty():
						elements_final.append_array(weapons_and_items[0])
					if not weapons_and_items[1].empty():
						elements_final.append_array(weapons_and_items[1])
		
		1:
			# 显示武器
			var weapon_elements:Array = []
			for i in elements_0:
				weapon_elements.append_array(i[0])
			
			elements_final = weapon_filter(
					weapon_elements,
					filter_weapon_type,
					filter_weapon_class,
					filter_weapon_scaling_stat)
			
		2:
			# 显示道具
			var item_elements:Array = []
			for i in elements_0:
				item_elements.append_array(i[1])
			
			elements_final = item_filter(
					item_elements,
					filter_item_number_limit,
					filter_item_effects,
					filter_item_special_effect)
		


	var out:Array = elements_final
	
	# 剔除已达数量上限的道具
	var out_final:Array = []
	var _pidx:int = _supermarket.player_index
	var _owned_items:Array = []
	if _pidx >= 0 and _pidx < RunData.players_data.size():
		_owned_items = RunData.players_data[_pidx].items
	for item in out:
		var item_maxed:bool = false
		if item.get_category() == Category.ITEM and item.max_nb > 0:
			var nb_owned:int = 0
			for owned in _owned_items:
				if owned.my_id == item.my_id:
					nb_owned += 1
			if nb_owned >= item.max_nb:
				item_maxed = true
		if not item_maxed:
			out_final.push_back(item)
	_supermarket.set_elements(out_final, false, true, _mod_tool.supermarket_curse)





func weapon_filter(weapon_elements:Array, type:int, weapon_class:String, weapon_scaling_stat:String)->Array:
	var weapon_elements_out:Array = []
			
	# 近战或远战
	match type:
		0:
			# 显示全部武器
			weapon_elements_out = weapon_elements
		1:
			# 显示近战武器
			for weapon in weapon_elements:
				if weapon.type == WeaponType.MELEE:
					weapon_elements_out.push_back(weapon)
		2:
			# 显示远程武器
			for weapon in weapon_elements:
				if weapon.type == WeaponType.RANGED:
					weapon_elements_out.push_back(weapon)
	
	# 筛选词条
	if not weapon_class.empty():
		var remove_weapons:Array = []
		for weapon in weapon_elements_out:
			var has_set:bool = false
			for set in weapon.sets:
				if set.my_id == weapon_class:
					has_set = true
					break
			if not has_set:
				remove_weapons.push_back(weapon)
		for weapon in remove_weapons:
			weapon_elements_out.erase(weapon)
	
	# 筛选伤害影响
	if not weapon_scaling_stat.empty():
		var remove_weapons:Array = []
		for weapon in weapon_elements_out:
			var has_set:bool = false
			for scaling_stat in weapon.stats.scaling_stats:
				if scaling_stat[0] == weapon_scaling_stat:
					has_set = true
					break
			if not has_set:
				remove_weapons.push_back(weapon)
		for weapon in remove_weapons:
			weapon_elements_out.erase(weapon)
	
	return weapon_elements_out


func item_filter(item_elements:Array, number_limit:int, effects:Dictionary, special_effect:int)->Array:
	var item_elements_out:Array = []
			
	match number_limit:
		0:
			# 全部
			item_elements_out = item_elements
		1:
			# 独特的
			for item in item_elements:
				if item.max_nb == 1:
					item_elements_out.push_back(item)
		2:
			# 限制
			for item in item_elements:
				if item.max_nb > 1:
					item_elements_out.push_back(item)
		3:
			# 道具
			for item in item_elements:
				if item.max_nb == -1:
					item_elements_out.push_back(item)
	
	# 检查是否符合排除条件
	if not effects.empty():
		var remove_items = []
		for item in item_elements_out:
			var remove_flag:bool = false
			for effect in item.effects:
				var effect_key:String = effect.key.to_upper()
				if effects.has(effect_key):
					var state = effects[effect_key]
					# 剔除不应增加但增加
					if not bool(state & 1) and effect.value > 0:
						remove_flag = true
						break
					# 剔除不应减少但减少
					if not bool(state & 2) and effect.value < 0:
						remove_flag = true
						break
			if remove_flag:
				remove_items.push_back(item)
		
		for item in remove_items:
			item_elements_out.erase(item)
		# 检查剩余项是否符合筛选条件
		for effect_key in effects:
			var state = effects[effect_key]
			if state == 0:
				continue
			remove_items.clear()
			for item in item_elements_out:
				var remove_flag:bool = false
				var has_effect:bool = false
				for effect in item.effects:
					if effect_key == effect.key.to_upper():
						has_effect = true
						break
				if not has_effect:
					remove_flag = true
				if remove_flag:
					remove_items.push_back(item)
			for item in remove_items:
				item_elements_out.erase(item)
	
	# 处理特殊效果
	var ordinary_effects = _mod_tool.get_ordinary_effects()
	if special_effect != 0:
		var remove_items:Array = []
		var text:String = "res://items/global/effect.gd"
		for item in item_elements_out:
			var has_effect:bool = false
			for effect in item.effects:
				# 特殊效果不直接使用基础effect.gd
				if effect.get_script().get_path() != text:
					has_effect = true
					break
				# 特殊效果key不在普通的16+20之内
				elif not ordinary_effects.has(effect.key):
					has_effect = true
					break
				# 特殊效果custom_key不为空
				elif not effect.custom_key.empty():
					has_effect = true
					break
			# 选择包含，剔除没有
			if special_effect == 1 and not has_effect:
				remove_items.push_back(item)
			# 选择排除，剔除有
			if special_effect == 2 and has_effect:
				remove_items.push_back(item)
		for item in remove_items:
			item_elements_out.erase(item)
	
	return item_elements_out
