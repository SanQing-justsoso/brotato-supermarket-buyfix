extends "./base/game_base.gd"


func _init(mod:Node).(mod):
	version = "0.8"



func get_item_value(item:ItemParentData)->int:
	return ItemService.get_value(RunData.current_wave, item.value, true, item is WeaponData)

