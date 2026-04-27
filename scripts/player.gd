extends Node2D

################################################################################
# Data
################################################################################

var card_scene = preload("res://scenes/card.tscn")

var player_id: int = -1
var player_name: String = ""

################################################################################
# Implementation
################################################################################

func init(_player_id: int, _name: String):
	self.player_id = _player_id
	self.player_name = _name
	if self.player_id == Network.peer_id:
		$Label.text = "* %s" % _name
	else:
		$Label.text = _name


# Returns -1 if player doesnt have a card
func get_card_value() -> int:
	var card_node = get_card_node()
	if card_node != null:
		return card_node.value
	else:
		return -1 


# Returns null if player doesnt have a card
func get_card_node() -> Node:
	for child in get_children():
		if child.is_in_group("card"):
			return child
	return null


# Returns true if was removed
func remove_card() -> bool:
	for child in get_children():
		if child.is_in_group("card"):
			child.queue_free()
			return true
	return false


func set_card(value: int):
	remove_card()
	var card_node = card_scene.instantiate()
	card_node.init(value, self.player_id != Network.peer_id)
	add_child(card_node)

# Swap card with target player
func swap_cards(target_player_node: Node):
	assert(self.player_id != -1, "Player node not initialized")

	# Get card values
	var my_card_value = get_card_value()
	var target_card_value = target_player_node.get_card_value()
	
	# Remove current cards
	remove_card()
	target_player_node.remove_card()
	
	# Set player cards
	set_card(target_card_value)
	target_player_node.set_card(my_card_value)
