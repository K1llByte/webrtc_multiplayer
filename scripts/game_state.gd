extends Node

################################################################################
# Data
################################################################################

# Peer ids of connected players
var players: Array[int] = []
# Key is peer id and value is player name
var players_data: Dictionary[int, String] = {}
const MIN_NUM_PLAYERS: int = 2

################################################################################
# Implementation
################################################################################

func add_player(player_id: int, player_name: String):
	self.players.append(player_id)
	self.players_data[player_id] = player_name


func _ready():
	multiplayer.peer_connected.connect(Game.on_player_connected)
	multiplayer.peer_disconnected.connect(Game.on_player_disconnected)


func on_player_connected(peer_id: int):
	Game.players.append(peer_id)
	Game.players_data[peer_id] = "username%d" % peer_id


func on_player_disconnected(peer_id: int):
	Game.players.erase(peer_id)
	Game.players_data.erase(peer_id)


func back_to_lobby():
	var tree: SceneTree = get_tree()
	tree.change_scene_to_file("res://scenes/menu.tscn")
	await tree.scene_changed
	tree.current_scene.load_lobby()
