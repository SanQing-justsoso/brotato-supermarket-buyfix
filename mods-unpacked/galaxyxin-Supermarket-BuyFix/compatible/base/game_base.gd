extends "./base.gd"

func _init(mod:Node):
	name = "Game"
	mod.add_child(self)


func exclusive_init():
	pass



# 兼容
# =============================================================================

func get_item_value(item:ItemParentData)->int:
	return 0
