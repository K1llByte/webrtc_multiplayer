extends Control

var players: Dictionary = {}

func fill_connected_peers():
	#print(multiplayer.get_peers())
	$Screen2/ItemList.clear()
	for pid in players.keys():
		var peer_id = int(pid)
		if Network.peer_id == peer_id:
			$Screen2/ItemList.add_item("* %s" % players[peer_id])
		else:
			$Screen2/ItemList.add_item(players[peer_id])


func player_name() -> String:
	if $Screen1/UsernameInput.text.is_empty():
		return "player%d" % Network.peer_id
	return $Screen1/UsernameInput.text


func _on_connected_peer(peer_id: int):
	if Network.is_host():
		players[peer_id] = "username%d" % peer_id
		sync_players.rpc(players)


func _on_disconnected_peer(peer_id: int):
	if Network.is_host():
		players.erase(peer_id)
		sync_players.rpc(players)


func _on_connected_to_host(peer_id: int):
	if peer_id == Network.HOST_ID:
		add_player.rpc(Network.peer_id, player_name())


# Server will send list of all players and fill connected player list
@rpc("authority", "call_local", "reliable")
func sync_players(new_players):
	players = new_players
	fill_connected_peers()


@rpc("any_peer", "reliable")
func add_player(peer_id: int, player_name: String):
	players[peer_id] = player_name
	print_debug("> %d IS SETTING NAME '%s' FOR %d" % [Network.peer_id, player_name, peer_id])
	if Network.is_host():
		sync_players.rpc(players)


func _on_create_game_button_down():
	var lobby_code = Network.create_lobby()
	add_player(Network.peer_id, player_name())
	
	$Screen1.hide()
	$Screen2.show()
	$Screen2/CodeValueLabel.text = lobby_code
	# Add self to list of players
	fill_connected_peers()
	
	multiplayer.peer_connected.connect(_on_connected_peer)
	multiplayer.peer_disconnected.connect(_on_disconnected_peer)


func _on_join_game_button_down():
	var lobby_code = $Screen1/GameCodeInput.text
	Network.join_lobby(lobby_code)
	
	$Screen1.hide()
	$Screen2.show()
	$Screen2/CodeValueLabel.text = lobby_code
	multiplayer.peer_connected.connect(_on_connected_to_host)



func _on_copy_clipboard_button_down() -> void:
	DisplayServer.clipboard_set($Screen2/CodeValueLabel.text)
