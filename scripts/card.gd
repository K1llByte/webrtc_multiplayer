extends Node2D

################################################################################
# Data
################################################################################

@export var value: int = 1
@export var down: bool = false

################################################################################
# Implementation
################################################################################

func init(card_value: int, is_down: bool = false):
	self.value = card_value
	set_down(is_down)


func set_down(is_down: bool):
	self.down = is_down
	if is_down:
		$Label.text = ""
		$Sprite2D.region_rect.position.x = 0
	else:
		$Label.text = str(self.value)
		$Sprite2D.region_rect.position.x = 26
