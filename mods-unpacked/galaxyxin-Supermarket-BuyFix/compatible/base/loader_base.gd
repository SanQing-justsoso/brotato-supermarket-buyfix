extends "./base.gd"

func _init(mod:Node):
	name = "Loader"
	mod.add_child(self)


func install_script_extension(child_script_path:String):
	pass


func add_translation(resource_path:String):
	pass


func has_mod(mod_name:String)->bool:
	return false


func set_manifest_name(mod_name:String, text:String)->void:
	pass


func set_manifest_description(mod_name:String, text:String)->void:
	pass
