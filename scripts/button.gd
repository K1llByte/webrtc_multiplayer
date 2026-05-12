extends Button

func _set_icon_y(y: int) -> void:
	var atlas := self.icon as AtlasTexture
	var region := atlas.region
	region.position.y = y
	atlas.region = region


func _on_mouse_entered() -> void:
	self.icon.region.position.y = 12
	pass
	#var tex = self.icon as AtlasTexture
	#print("Region ", tex.region)
	#_set_icon_y(12)


func _on_mouse_exited() -> void:
	self.icon.region.position.y = 0
	pass
	#var tex = self.icon as AtlasTexture
	#print("Region ", tex.region)
	#_set_icon_y(0)


func _on_button_down() -> void:
	self.icon.region.position.y = 24
	pass
	#var tex = self.icon as AtlasTexture
	#print("Region ", tex.region)
	#_set_icon_y(24)


func _on_button_up() -> void:
	self.icon.region.position.y = 0
	pass
	#svar tex = self.icon as AtlasTexture
	#print("Region ", tex.region)
	#_set_icon_y(0)
