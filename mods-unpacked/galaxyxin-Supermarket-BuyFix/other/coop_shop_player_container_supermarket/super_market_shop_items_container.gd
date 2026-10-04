extends ShopItemsContainer


var mod_tool
var dlc

# Called when the node enters the scene tree for the first time.
func _ready():
	mod_tool = get_node("/root/ModLoader/galaxyxin-Supermarket-BuyFix/工具")
	if mod_tool.has_mod("JAghI70bfEvHbE4ZxOJRz7yEjINYbbS3-ModName_Touch_slide_HEQxNuep"):
		if has_node("/root/MouseFilter"):
			_has_touch_slide_mod = true
	_v.rect_min_size.x += 20
	_v.connect("value_changed", self, "on_v_value_changed")
	if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		dlc = ProgressData.get_dlc_data("abyssal_terrors")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
