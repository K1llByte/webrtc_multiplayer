extends Node2D

################################################################################
# Types
################################################################################

enum GameState {
	# State where host is waiting for all peers to load the game scene
	WAITING_PLAYERS_READY,
	# State where host and clients are waiting for all peers to receive the deck
	WAITING_DECK,
	IN_PROGRESS,
}

enum PlayerAction {
	KEEP_CARD,
	DRAW_NEW_CARD,
	SWAP_CARD,
}

################################################################################
# Data
################################################################################

var card_scene: PackedScene = preload("res://scenes/card.tscn")
var player_scene: PackedScene = preload("res://scenes/player.tscn")
var menu_scene: PackedScene = preload("res://scenes/menu.tscn")

# Current turn by player index (can be indexed from Game.players).
# This value starts at -1 so when set_next_player_turn is called for the first
# time the firstplayer will be the host.
var current_turn_player_idx: int = -1
# Key is player id, value is instanced player scene node.
var player_id_to_node: Dictionary =  {}
var num_rounds: int = 5
var deck: Array[int] = []
var state: GameState
# Data for WAITING_PLAYERS_READY
# By default host is always ready and this data should be ignored by other
# players.
var ready_players_count := 1
var game_round := 0

@export var spawner_ellipse_width: float = 400.0
@export var spawner_ellipse_height: float = 225.0

################################################################################
# Implementation
################################################################################

func _ready():
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	$ActionButtons.hide()
	if !Network.is_host():
		self.state = GameState.WAITING_DECK
		#start_game()
		set_player_ready.rpc()
	else:
		self.state = GameState.WAITING_PLAYERS_READY


@rpc("any_peer", "call_remote")
func set_player_ready():
	self.ready_players_count += 1


# Only host calls this function
func setup_game():
	spawn_players()
	create_deck(num_rounds * Game.players.size())
	var player_id_to_card_value = draw_cards_all()
	set_next_player_turn()
	sync_game_setup.rpc(self.deck, player_id_to_card_value)
	update_deck_label()
	self.state = GameState.IN_PROGRESS


@rpc("authority")
func sync_game_setup(new_deck: Array[int], player_id_to_card_value: Dictionary[int, int]):
	spawn_players()
	self.deck = new_deck
	# Set player cards
	for player_id in player_id_to_card_value.keys():
		var player_node = self.player_id_to_node[player_id]
		player_node.set_card(player_id_to_card_value[player_id])
	
	set_next_player_turn()
	update_deck_label()
	self.state = GameState.IN_PROGRESS


func update_deck_label():
	var label: Label = $Deck.find_child("Label")
	assert(label != null)
	label.text = "%d/%d" % [self.deck.size(), (num_rounds * Game.players.size())]


func _process(_delta: float):
	match self.state:
		GameState.WAITING_PLAYERS_READY:
			if self.ready_players_count == Game.players.size():
				setup_game()
				self.state = GameState.IN_PROGRESS
			
		GameState.IN_PROGRESS:
			# If is my turn
			if Game.players[current_turn_player_idx] == Network.peer_id:
				$ActionButtons.show()
			else:
				$ActionButtons.hide()
			
		GameState.WAITING_DECK:
			if !self.deck.is_empty():
				setup_game() 


# Host creates deck and then send it to all player peers
func create_deck(num_cards: int):
	self.deck.clear()
	for i in range(1, num_cards + 1):
		self.deck.append(i)
	self.deck.shuffle()


# Both host and peers distribute player nodes across the table in the their own
# preference.
func spawn_players():
	var num_players = Game.players.size()
	var local_plr_idx = Game.players.find(Network.peer_id)
	assert(local_plr_idx != -1)
	
	for i in range(num_players):
		var player_i: int = (i + local_plr_idx) % num_players
		var t = 2 * PI * i / num_players
		var x = spawner_ellipse_width * sin(t)
		var y = spawner_ellipse_height * cos(t)
		
		var plr_position = $SpawnPoint.global_position + Vector2(x, y)
		spawn_player(
			plr_position,
			Game.players[player_i],
			Game.players_data.values()[player_i]
		)


func spawn_player(plr_position: Vector2, peer_id: int, plr_name: String):
	var player_node: Node2D = player_scene.instantiate()
	player_node.init(peer_id, plr_name)
	player_node.position = plr_position
	self.player_id_to_node[peer_id] = player_node
	$Players.add_child(player_node)


func create_card_node_from_value(card_value: int, down: bool = false) -> Node:
	var card = card_scene.instantiate()
	card.init(card_value, down)
	return card


func fetch_card_from_deck() -> Node:
	if deck.is_empty():
		return null
	
	var card = card_scene.instantiate()
	card.init(self.deck.pop_back())
	return card


func draw_cards_all() -> Dictionary[int, int]:
	var player_id_to_card_value: Dictionary[int, int] = {}
	for player_id in Game.players:
		var card_value: int = self.deck.pop_back()
		var card_node = create_card_node_from_value(card_value, player_id != Network.peer_id)
		self.player_id_to_node[player_id].add_child(card_node)
		player_id_to_card_value[player_id] = card_value
	return player_id_to_card_value


@rpc("any_peer", "call_local")
func draw_card_current():
	var current_peer_id = Game.players[self.current_turn_player_idx]
	var player_node = self.player_id_to_node[current_peer_id]
	for child in player_node.get_children():
		# NOTE: Suboptimal str check but fine for now
		if child.is_in_group("card"):
			child.queue_free()
	var card_node = fetch_card_from_deck()
	card_node.set_down(current_peer_id != Network.peer_id)
	player_node.add_child(card_node)
	update_deck_label()
	set_next_player_turn()


@rpc("any_peer", "call_local")
func set_next_player_turn():
	self.current_turn_player_idx = (self.current_turn_player_idx + 1) % Game.players.size()
	if self.current_turn_player_idx == 0:
		self.game_round += 1
		$RoundLabel.text = "Round %d" % self.game_round


@rpc("any_peer", "call_local")
func swap_current_player_card(target_player_id):
	var current_player_id = Game.players[self.current_turn_player_idx]
	var player_a_node = self.player_id_to_node[current_player_id]
	var player_b_node = self.player_id_to_node[target_player_id]
	# Swap card values
	player_a_node.swap_cards(player_b_node)
	# Set next player turn
	set_next_player_turn()


# Setup all area signal handlers
func enable_player_selection():
	for player_id in self.player_id_to_node.keys():
		# Don't allow selecting itself
		if player_id == Game.players[self.current_turn_player_idx]:
			continue
		var player_node = self.player_id_to_node[player_id]
		var card_node = player_node.get_card_node()
		var card_area_node = card_node.find_child("Area2D")
		card_area_node.input_event.connect(_on_card_area2d_input_event.bind(player_id, card_node))
		card_area_node.mouse_entered.connect(set_card_border.bind(card_node, true))
		card_area_node.mouse_exited.connect(set_card_border.bind(card_node, false))


func disable_player_selection():
	for player_id in self.player_id_to_node.keys():
		# Don't allow selecting itself
		if player_id == Game.players[self.current_turn_player_idx]:
			continue
		var player_node = self.player_id_to_node[player_id]
		var card_node = player_node.get_card_node()
		var card_area_node = card_node.find_child("Area2D")
		card_area_node.input_event.disconnect(_on_card_area2d_input_event.bind(player_id, card_node))
		card_area_node.mouse_entered.disconnect(set_card_border.bind(card_node, true))
		card_area_node.mouse_exited.disconnect(set_card_border.bind(card_node, false))


func set_card_border(card_node: Node, value: bool):
	card_node.find_child("Sprite2D").material.set_shader_parameter("enable_outline", value)


func _on_card_area2d_input_event(_viewport, event, _shape_idx, player_id, card_node):
	if event is InputEventMouseButton and event.pressed:
		# Force removal of selected card outline 
		set_card_border(card_node, false)
		disable_player_selection()
		swap_current_player_card.rpc(player_id)


func _on_swap_card_button_down():
	enable_player_selection()


func _on_draw_new_card_button_down():
	disable_player_selection()
	draw_card_current.rpc()


func _on_keep_card_button_down():
	disable_player_selection()
	set_next_player_turn.rpc()


# Redistribute player nodes across the table in the their own preference.
func respawn_players():
	var num_players = Game.players.size()
	var local_plr_idx = Game.players.find(Network.peer_id)
	assert(local_plr_idx != -1)
	
	for i in range(num_players):
		var player_i: int = (i + local_plr_idx) % num_players
		var t = 2 * PI * i / num_players
		var x = spawner_ellipse_width * sin(t)
		var y = spawner_ellipse_height * cos(t)
		
		var plr_position = $SpawnPoint.global_position + Vector2(x, y)
		
		
		self.player_id_to_node[Game.players[player_i]].position = plr_position


func _on_player_disconnected(peer_id: int):
	# If there are no longer enough players to continue game, go back to menu.
	if Game.players.size() < Game.MIN_NUM_PLAYERS:
		print("Gonna change scene")
		assert(menu_scene != null)
		# FIXME: For some reason Im not able to do here:
		# get_tree().change_scene_to_packed(menu_scene)
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	
	# Remove disconnected player node
	self.player_id_to_node.erase(peer_id)
	for player_node in $Players.get_children():
		if player_node.player_id == peer_id:
			player_node.queue_free()
	
	respawn_players()
	
	# Update game state to continue without the disconnected player
	# NOTE: No need for rpc since every peer receives player disconnected event
	self.current_turn_player_idx = self.current_turn_player_idx % Game.players.size()
