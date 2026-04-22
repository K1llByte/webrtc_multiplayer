extends Node2D

@export var value: int = 1
@export var down: bool = false

func init(value: int):
	self.value = value
	$Label.text = str(value)
