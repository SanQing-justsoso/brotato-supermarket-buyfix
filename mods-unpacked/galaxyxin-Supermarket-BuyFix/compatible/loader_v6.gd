extends "./base/loader_base.gd"


func _init(mod:Node).(mod):
	version = "6"


func install_script_extension(child_script_path:String):
	ModLoaderMod.install_script_extension(child_script_path)


func add_translation(resource_path:String):
	ModLoaderMod.add_translation(resource_path)


func has_mod(mod_name:String)->bool:
	return ModLoaderStore.mod_data.has(mod_name)


func set_manifest_name(mod_name:String, text:String)->void:
	ModLoaderStore.mod_data[mod_name].manifest.name = text


func set_manifest_description(mod_name:String, text:String)->void:
	ModLoaderStore.mod_data[mod_name].manifest.description = text
