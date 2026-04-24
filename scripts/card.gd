extends Node2D

@export var value: int = 1
@export var down: bool = false

func init(card_value: int):
	self.value = card_value
	$Label.text = str(self.value)
