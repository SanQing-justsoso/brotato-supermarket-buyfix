extends "./base/game_base.gd"


func _init(mod:Node).(mod):
	version = "1.0"


func exclusive_init():
	# 防止其他mod的bug影响，导致没有王者之剑认为是本mod错误
	# 如果国王通关但王者之剑未解锁，强制解锁王者之剑
	if ChallengeService.stat_challenges.empty():
		yield(get_node("/root/ChallengeService"), "ready")
	var chal_id:String = "chal_king"
	if ProgressData.challenges_completed.has(chal_id):
		if not ProgressData.weapons_unlocked.has("weapon_excalibur_4"):
			var chal_data = null
			for chal in ChallengeService.challenges:
				if chal.my_id == chal_id:
					chal_data = chal
					break
			ChallengeService.unlock_reward(chal_data)
			ItemService.init_unlocked_pool()


func get_item_value(item:ItemParentData)->int:
	return ItemService.get_value(RunData.current_wave, item.value, true, item is WeaponData, item.my_id)



