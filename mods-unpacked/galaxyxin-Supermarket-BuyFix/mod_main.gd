extends Node
# JAghI70bfEvHbE4ZxOJRz7yEjINYbbS3
# ekJg5ZS1
# 随机字符，防止名称与其他mod重复

var dir:String = ""
#const Loader = preload("./compatible/base/loader_base.gd")
#var loader:Loader = null
#const Game = preload("./compatible/base/game_base.gd")
#var game:Game = null
var loader = null
var game = null

func _init():
	dir = get_script().resource_path.get_base_dir() + "/"
	# 由于一些功能需要当前节点在节点树上，所以初始化函数不做任何添加扩展的行为


func _ready():
	# 兼容ModLoader版本
	var loader_path:String = dir + "compatible/"
	if has_node("/root/ModLoaderStore"):
		loader_path += "loader_v6.gd"
	else:
		loader_path += "loader_v5.gd"
	loader = ResourceLoader.load(loader_path).new(self)
	
	# 兼容游戏版本
	var game_path:String = dir + "compatible/"
	var version_str = ProgressData.VERSION.split(".")
	var version:PoolIntArray = []
	for number_str in version_str:
		version.push_back(int(number_str))
	if version[0] >= 1:
		if version[1] >= 1:
			game_path += "game_1.1.5.gd"
		else:
			game_path += "game_1.0.gd"
	else:
		game_path += "game_0.8.gd"
	game = ResourceLoader.load(game_path).new(self)
	
	# 初始化
	mod_init()
	game.exclusive_init()
	
	# 添加mod内的公用资源
	var mod_tool = ResourceLoader.load(dir + "other/other.gd").new(self)


func mod_init()->void:
	var ext_dir = dir + "extensions/"
	var trans_dir = dir + "translations/"
	
	# 加载翻译
	loader.add_translation(trans_dir + "ekJg5ZS1_ui.en.translation")
	loader.add_translation(trans_dir + "ekJg5ZS1_ui.zh_Hans_CN.translation")
	
	# 生成mod描述
	mod_description()
	
	# shop.gd中的一个变量，需要RunData.effects内的某个键值，但这需要RunData完成初始化
#	yield(get_node("/root/RunData"), "ready")
#	yield(get_node("/root/ItemService"), "ready")
	loader.install_script_extension(ext_dir + "ui/menus/shop/shop.gd")
	loader.install_script_extension(ext_dir + "ui/menus/shop/coop_shop.gd")
	loader.install_script_extension(ext_dir + "ui/menus/pages/menu_options.gd")


func mod_description()->void:
	var LOG = name
	# 设置mod描述，防止使用本地默认语言，需要等待ProgressData完成初始化
	if ProgressData.settings.empty():
		yield(get_node("/root/ProgressData"), "ready")
	var text:String = "%s"
	var font_path:String = "res://resources/fonts/actual/base/font_small_title.tres"
	var text_color:String = "[color=%s]%s[/color]"
	var title:String = "[color=%s][font=%s]%s[/font][/color]" % ["%s", font_path, "%s"]
	var rainbow:String = "[rainbow freq=0.3 sat=10 val=20]%s[/rainbow]"
	var wave:String = "[wave amp=50 freq=2]%s[/wave]"
	var description:String = ""
	description += rainbow % wave % "Supermarket" + "\n"
	description += title % ["yellow", "Introduction / 简介"] + "\n"
	description += text % "Show more items in the store." + "\n"
	description += text % "在商店中显示更多物品" + "\n"
	description += title % ["yellow", "Usage / 用法"] + "\n"
	description += text % "In the shop, click on the top button." + "\n"
	description += text % "商店界面点击上方的超市按钮" + "\n"
	description += title % ["red", "Warning / 警告"] + "\n"
	description += text % "This mod will almost completely eliminate the randomness of the game and make the difficulty of the game extremely low." + "\n"
	description += text % "这个mod会使游戏的随机性几乎完全消失，以及游戏难度变得极低。" + "\n"
	description += " \n"
	description += text_color % ["yellow", "Fixed by Virtuoso"] + "\n"
	loader.set_manifest_description(LOG, description)
