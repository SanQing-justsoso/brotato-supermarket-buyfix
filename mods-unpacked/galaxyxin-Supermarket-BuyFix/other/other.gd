extends Node

var mod_dir = "res://mods-unpacked/galaxyxin-Supermarket-BuyFix/"
var loader_node:Node = null
var mod_node:Node = null

var ordinary_effects:PoolStringArray = []

var supermarket_locked:bool = false
var supermarket_curse:bool = false

func _init(mod:Node):
	mod.add_child(self)
	mod_dir = mod.dir
	name = "工具"
	loader_node = mod.loader
	mod_node = mod.game
	yield(get_node("/root/RunData"), "ready")
	yield(get_node("/root/ItemService"), "ready")

# compatible 兼容
# =============================================================================

func has_mod(mod_name:String)->bool:
	return loader_node.has_mod(mod_name)


func get_item_value(item:ItemParentData)->int:
	return mod_node.get_item_value(item)


func get_item_value_for(item:ItemParentData, player_index:int)->int:
	if player_index > 0:
		return mod_node.get_item_value(item, player_index)
	return mod_node.get_item_value(item)


# tool 工具
# =============================================================================


func get_pool_all_item(wave:int, player_index: int)->Array:
	var pool:Array = []
	
	var player_character = RunData.get_player_character(player_index)
	var max_weapon_tier: int = RunData.get_player_effect(Keys.generate_hash("max_weapon_tier"), player_index)
	var min_weapon_tier: int = RunData.get_player_effect(Keys.generate_hash("min_weapon_tier"), player_index)
	var no_melee_weapons: bool = RunData.get_player_effect_bool(Keys.generate_hash("no_melee_weapons"), player_index)
	var no_ranged_weapons: bool = RunData.get_player_effect_bool(Keys.generate_hash("no_ranged_weapons"), player_index)
	var no_duplicate_weapons: bool = RunData.get_player_effect_bool(Keys.generate_hash("no_duplicate_weapons"), player_index)
	var no_structures: bool = RunData.get_player_effect(Keys.generate_hash("remove_shop_items"), player_index).has("structure")
	var unique_weapon_ids: Dictionary = RunData.get_unique_weapon_ids(player_index)
	var remove_item_tags: Array = RunData.get_player_effect(Keys.generate_hash("remove_shop_items"), player_index)
	
	var max_tier_from_wave = get_max_tier_from_wave(wave)
	for tier in range(max_tier_from_wave, -1, -1):
		var weapon_pool:Array = []
		# 判断是否需要武器
		if RunData.get_player_effect_bool(Keys.generate_hash("weapon_slot"), player_index):
			if tier <= max_weapon_tier:
				if tier < min_weapon_tier and weapon_pool.size() != 0:
					pass
				else:
					var correct_tier = tier
					if tier < min_weapon_tier and weapon_pool.size() == 0:
						correct_tier = min_weapon_tier
					weapon_pool = ItemService.get_pool(correct_tier, ItemService.TierData.WEAPONS)
					var weapon_to_remove = []
					for item in weapon_pool:
						if no_melee_weapons and item.type == WeaponType.MELEE:
							weapon_to_remove.push_back(item)
						if no_ranged_weapons and item.type == WeaponType.RANGED:
							weapon_to_remove.push_back(item)
						if no_duplicate_weapons:
							for weapon in unique_weapon_ids.values():
								if item.weapon_id == weapon.weapon_id and item.tier < weapon.tier:
									weapon_to_remove.push_back(item)
									break
								elif item.my_id == weapon.my_id and weapon.upgrades_into == null:
									weapon_to_remove.push_back(item)
									break
						if no_structures and EntityService.is_weapon_spawning_structure(item):
							weapon_to_remove.push_back(item)
							
					# 剔除武器
					for weapon in weapon_to_remove:
						weapon_pool.erase(weapon)
						
		var item_pool:Array = []
		item_pool = ItemService.get_pool(tier, ItemService.TierData.ITEMS)
				
		var items_to_remove:Array = []
		for tag_to_remove in remove_item_tags:
			for item in item_pool:
				if tag_to_remove in item.tags:
					items_to_remove.append(item)
		if player_character.banned_item_groups.size() > 0:
			for banned_item_group in player_character.banned_item_groups:
				if not banned_item_group in ItemService.item_groups:
					continue

				for item in item_pool:
					if ItemService.item_groups[banned_item_group].has(item.my_id):
						items_to_remove.append(item)
		if player_character.banned_items.size() > 0:
			for item in item_pool:
				if player_character.banned_items.has(item.my_id):
					items_to_remove.append(item)
		# 剔除达到上限的
		var limited_items = ItemService.get_limited_items(RunData.get_player_items(player_index))
		for key in limited_items:
			if limited_items[key][1] >= limited_items[key][0].max_nb:
				items_to_remove.push_back(limited_items[key][0])
		for item in items_to_remove:
			item_pool.erase(item)
		
		pool.push_back([weapon_pool,item_pool])
	
	# 兼容 1.0.0.0版本 角色"渔夫"效果：商店必有一个"诱饵(+8%伤害)"
	if  RunData.get_player_effect(Keys.generate_hash("guaranteed_shop_items"), player_index):
		
		var to_be_added_guaranteed_items = []
		# 该效果结构是[key, value] 参考文件"res://items/global/effect.gd"
		var effect_guaranteed_items:Array = RunData.get_player_effect(Keys.generate_hash("guaranteed_shop_items"), player_index).duplicate()
		if effect_guaranteed_items.size() > 0:
			for effect_key_value in effect_guaranteed_items:
				var item = ItemService.get_element(ItemService.items, effect_key_value[0])
				var pool_has:bool = false
				for weapons_and_items in pool:
					if weapons_and_items[1].has(item):
						pool_has = true
						break
				if not pool_has:
					to_be_added_guaranteed_items.push_back(item)
		if to_be_added_guaranteed_items.size() > 0:
			pool.push_front([[],to_be_added_guaranteed_items])
	
	return pool


func get_max_tier_from_wave(wave:int)->int:
	# 原函数是 get_tier_from_wave(wave:int)->int
	# 除了能传入波次，还能传入角色等级
	# 第2波结束，解锁蓝色稀有度
	# 第4波结束，解锁紫色稀有度
	# 第8波结束，解锁红色稀有度
	var out = 0
#	var luck = Utils.get_stat("stat_luck", player_index) / 100.0
	var luck = 100
	for tier in range(ItemService._tiers_data.size() - 1, - 1, - 1):
		var wave_base_chance = max(
				0.0,
				((wave - 1) - ItemService._tiers_data[tier][ItemService.TierData.MIN_WAVE]) *
				ItemService._tiers_data[tier][ItemService.TierData.WAVE_BONUS_CHANCE]
		)
		
		var wave_chance = 0.0
		# 幸运不会使概率变为零
		# 因为我要获取当前允许最大稀有度，所以幸运在这里并无作用
		if luck >= 0:
			wave_chance = wave_base_chance * (1 + luck)
		else :
			wave_chance = wave_base_chance / (1 + abs(luck))
		
		var chance = ItemService._tiers_data[tier][ItemService.TierData.BASE_CHANCE] + wave_chance
		var max_chance = ItemService._tiers_data[tier][ItemService.TierData.MAX_CHANCE]
		
		if min(chance, max_chance) > 0:
			out = tier
			break
	return out

# 返回一组同属性不同稀有度的升级项目，参数1属性key大写，参数2等级
# 数组中的每个元素下有两个值，[0]升级项目，[1]当前可用
# 返回值，稀有度由低到高
func get_upgrade_group_data(stat_text,level:int)->Array:
	var _stat_text = stat_text.to_lower()
	var max_tier_from_level
	var limited_tier:bool
	if level % 5 == 0:
		limited_tier = true
		if level == 5:
			max_tier_from_level = Tier.UNCOMMON
		elif level == 10 or level == 15 or level == 20:
			max_tier_from_level = Tier.RARE
		elif level % 5 == 0:
			max_tier_from_level = Tier.LEGENDARY
	else:
		limited_tier = false
		max_tier_from_level = get_max_tier_from_wave(level)
		
	
	var upgrade_group:Array = []
	for tier in ItemService._tiers_data.size():
		for upgrade_data in ItemService._tiers_data[tier][ItemService.TierData.UPGRADES]:
			if upgrade_data.effects[0].key == _stat_text:
				# 由于存在mod在某个属性有两组升级，需要排除一个
				# 敌人增加在本mod中是利好
				if _stat_text == "number_of_enemies":
					if upgrade_data.effects[0].value < 0:
						continue
				
				var flag:bool
				if limited_tier:
					flag = (tier == max_tier_from_level)
				else:
					flag = (tier <= max_tier_from_level)
				upgrade_group.push_back([upgrade_data,flag])
				break
	
	return upgrade_group


func init_ordinary_effects():
	ordinary_effects.push_back("STAT_MAX_HP".to_lower())
	ordinary_effects.push_back("STAT_HP_REGENERATION".to_lower())
	ordinary_effects.push_back("STAT_LIFESTEAL".to_lower())
	ordinary_effects.push_back("STAT_PERCENT_DAMAGE".to_lower())
	ordinary_effects.push_back("STAT_MELEE_DAMAGE".to_lower())
	ordinary_effects.push_back("STAT_RANGED_DAMAGE".to_lower())
	ordinary_effects.push_back("STAT_ELEMENTAL_DAMAGE".to_lower())
	ordinary_effects.push_back("STAT_ATTACK_SPEED".to_lower())
	ordinary_effects.push_back("STAT_CRIT_CHANCE".to_lower())
	ordinary_effects.push_back("STAT_ENGINEERING".to_lower())
	ordinary_effects.push_back("STAT_RANGE".to_lower())
	ordinary_effects.push_back("STAT_ARMOR".to_lower())
	ordinary_effects.push_back("STAT_DODGE".to_lower())
	ordinary_effects.push_back("STAT_SPEED".to_lower())
	ordinary_effects.push_back("STAT_LUCK".to_lower())
	ordinary_effects.push_back("STAT_HARVESTING".to_lower())
	
	ordinary_effects.push_back("CONSUMABLE_HEAL".to_lower())
	ordinary_effects.push_back("heal_when_pickup_gold".to_lower())
	ordinary_effects.push_back("XP_GAIN".to_lower())
	ordinary_effects.push_back("PICKUP_RANGE".to_lower())
	ordinary_effects.push_back("ITEMS_PRICE".to_lower())
	ordinary_effects.push_back("EXPLOSION_DAMAGE".to_lower())
	ordinary_effects.push_back("EXPLOSION_SIZE".to_lower())
	ordinary_effects.push_back("BOUNCE".to_lower())
	ordinary_effects.push_back("PIERCING".to_lower())
	ordinary_effects.push_back("PIERCING_DAMAGE".to_lower())
	ordinary_effects.push_back("DAMAGE_AGAINST_BOSSES".to_lower())
	ordinary_effects.push_back("BURNING_COOLDOWN_REDUCTION".to_lower())
	ordinary_effects.push_back("BURNING_SPREAD".to_lower())
	ordinary_effects.push_back("KNOCKBACK".to_lower())
	ordinary_effects.push_back("CHANCE_DOUBLE_GOLD".to_lower())
	ordinary_effects.push_back("ITEM_BOX_GOLD".to_lower())
	ordinary_effects.push_back("FREE_REROLLS".to_lower())
	ordinary_effects.push_back("TREES".to_lower())
	ordinary_effects.push_back("NUMBER_OF_ENEMIES".to_lower())
	ordinary_effects.push_back("ENEMY_SPEED".to_lower())


func get_ordinary_effects()->PoolStringArray:
	if ordinary_effects.empty():
		init_ordinary_effects()
	return ordinary_effects


func stat_container_init(stats_container:StatsContainer, target:Object, method:String):
	var general_stats = stats_container._general_stats
	var primary_stats = stats_container._primary_stats
	var secondary_stats = stats_container._secondary_stats
	var button:Button = null
	for stat in general_stats.get_children():
		button = stat.get_node("HBoxContainer/Label")
		button.connect("pressed", target, method, [stat, button.text, 0])
		button.set_focus_mode(Control.FOCUS_ALL)
	for stat in primary_stats.get_children():
		button = stat.get_node("HBoxContainer/Label")
		button.connect("pressed", target, method, [stat, button.text, 0])
		button.set_focus_mode(Control.FOCUS_ALL)
	for stat in secondary_stats.get_children():
		button = stat.get_node("HBoxContainer/Label")
		button.connect("pressed", target, method, [stat, button.text, 0])
		button.set_focus_mode(Control.FOCUS_ALL)
	pass
