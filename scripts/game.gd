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

var card_scene = preload("res://scenes/card.tscn")
var player_scene = preload("res://scenes/player.tscn")

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
var round := 0

@export var spawner_ellipse_width: float = 400.0
@export var spawner_ellipse_height: float = 225.0

################################################################################
# Implementation
################################################################################

func _ready():
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
	self.state = GameState.IN_PROGRESS


@rpc("authority")
func sync_game_setup(new_deck: Array[int], player_id_to_card_value: Dictionary[int, int]):
	spawn_players()
	self.deck = new_deck
	set_player_cards(player_id_to_card_value)
	set_next_player_turn()
	self.state = GameState.IN_PROGRESS


func remove_card_from_player_node(player_id):
	for child in self.player_id_to_node[player_id].get_children():
		# NOTE: Suboptimal str check but fine for now
		if child.name == "card":
			child.queue_free()


func set_player_cards(player_id_to_card_value: Dictionary[int, int]):
	for player_id in player_id_to_card_value.keys():
		var card_node = create_card_node_from_value(player_id_to_card_value[player_id])
		remove_card_from_player_node(player_id)
		self.player_id_to_node[player_id].add_child(card_node)


#func start_game():
#	spawn_players()
#	
#	if Network.is_host():
#		# Create deck and then send it to all players
#		create_deck(num_rounds * Game.players.size())
#		sync_deck.rpc(self.deck)
#	
#	$ActionButtons.hide()


func _process(delta: float):
	match self.state:
		GameState.WAITING_PLAYERS_READY:
			if self.ready_players_count == Game.players.size():
				setup_game()
				#start_game()
				#self.state = GameState.WAITING_DECK
				self.state = GameState.IN_PROGRESS
			
		GameState.IN_PROGRESS:
			if is_my_turn():
				$ActionButtons.show()
			else:
				$ActionButtons.hide()
			
		GameState.WAITING_DECK:
			if !self.deck.is_empty():
				setup_game() 
				
				# FIXME: draw_cards_all and set_next_player_turn should be rpc
				# and syncd with players.
				#draw_cards_all()
				#set_next_player_turn()
				#state = GameState.IN_PROGRESS


# Create deck and then send it to all players
func create_deck(num_cards: int):
	self.deck.clear()
	for i in range(1, num_cards + 1):
		self.deck.append(i)
	self.deck.shuffle()


#@rpc("authority", "call_remote")
#func sync_deck(host_deck: Array[int]):
#	self.deck = host_deck
#	print_debug("RECEIVED DECK")


func spawn_players():
	# TODO: Spawn players sorted where local player is always down, but keep Game.players order
	var num_players = Game.players.size()
	var local_plr_idx = Game.players.find(Network.peer_id)
	assert(local_plr_idx != -1)
	
	for i in range(num_players):
		var player_i: int = (i + local_plr_idx) % num_players
		var t = 2 * PI * i / num_players
		var x = spawner_ellipse_width * sin(t)
		var y = spawner_ellipse_height * cos(t)
		
		var position = $SpawnPoint.global_position + Vector2(x, y)
		spawn_player(
			position,
			Game.players[player_i],
			Game.players_data.values()[player_i]
		)


# Mock function to show random player names
func spawn_player(position: Vector2, peer_id: int, name: String):
	var player_node: Node2D = player_scene.instantiate()
	if peer_id == Network.peer_id:
		player_node.get_node("Label").text = "* %s" % name
	else:
		player_node.get_node("Label").text = name
	player_node.position = position
	self.player_id_to_node[peer_id] = player_node
	$Players.add_child(player_node)


func create_card_node_from_value(card_value: int) -> Node:
	var card = card_scene.instantiate()
	card.name = "card"
	card.init(card_value)
	return card


func fetch_card_from_deck() -> Node:
	if deck.is_empty():
		return null
	
	var card = card_scene.instantiate()
	card.name = "card"
	card.init(self.deck.pop_back())
	return card


func draw_cards_all() -> Dictionary[int, int]:
	var player_id_to_card_value: Dictionary[int, int] = {}
	for player_id in Game.players:
		var card_value: int = self.deck.pop_back()
		var card_node = create_card_node_from_value(card_value)
		self.player_id_to_node[player_id].add_child(card_node)
		player_id_to_card_value[player_id] = card_value
	return player_id_to_card_value


@rpc("any_peer", "call_local")
func draw_card_current():
	var current_peer_id = Game.players[self.current_turn_player_idx]
	var player_node = self.player_id_to_node[current_peer_id]
	for child in player_node.get_children():
		# NOTE: Suboptimal str check but fine for now
		if child.name == "card":
			child.queue_free()
	player_node.add_child(fetch_card_from_deck())


@rpc("any_peer", "call_local")
func set_next_player_turn():
	self.current_turn_player_idx = (self.current_turn_player_idx + 1) % Game.players.size()
	print_debug("Current turn player id:", Game.players[self.current_turn_player_idx])
	if self.current_turn_player_idx == 0:
		self.round += 1
		$RoundLabel.text = "Round %d" % self.round
		


func is_my_turn() -> bool:
	return Game.players[current_turn_player_idx] == Network.peer_id


func _on_swap_card_button_down():
	print_debug("Feature still not implemented WIP")
	set_next_player_turn.rpc()


func _on_draw_new_card_button_down():
	draw_card_current.rpc()
	set_next_player_turn.rpc()


func _on_keep_card_button_down():
	set_next_player_turn.rpc()
