extends "./base/loader_base.gd"


func _init(mod:Node).(mod):
	version = "5"


func install_script_extension(child_script_path:String):
	ModLoader.install_script_extension(child_script_path)


func add_translation(resource_path:String):
	ModLoader.add_translation_from_resource(resource_path)


func has_mod(mod_name:String)->bool:
	return ModLoader.mod_data.has(mod_name)


func set_manifest_name(mod_name:String, text:String)->void:
	ModLoader.mod_data[mod_name].manifest.name = text


func set_manifest_description(mod_name:String, text:String)->void:
	ModLoader.mod_data[mod_name].manifest.description = text
