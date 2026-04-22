extends Node2D

var card_scene = preload("res://scenes/card.tscn")
var player_scene = preload("res://scenes/player.tscn")

@export var spawner_ellipse_width: float = 400.0
@export var spawner_ellipse_height: float = 225.0

func _ready():
	#var card = card_scene.instantiate()
	#card.init(2)
	#$SpawnPoint.add_child(card)
	
	spawn_players(Game.players)


func spawn_players(players: Dictionary):
	var num_players = players.size()
	for i in range(num_players):
		var t = 2 * PI * i / num_players
		var x = spawner_ellipse_width * sin(t)
		var y = spawner_ellipse_height * cos(t)
		
		var position = $SpawnPoint.global_position + Vector2(x, y)
		
		spawn_player(position, players.values()[i])


# Mock function to show random player names
func spawn_player(position: Vector2, name: String):
	var player: Node2D = player_scene.instantiate()
	player.get_node("Label").text = name
	player.position = position
	add_child(player)
