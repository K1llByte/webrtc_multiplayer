extends Control

func fill_connected_peers():
	print("IN fill_connected_peers")
	#print(multiplayer.get_peers())
	$Screen2/ItemList.clear()
	$Screen2/ItemList.add_item(str(Network.peer_id))
	for peer_id in Network.connected_peers.keys():
		$Screen2/ItemList.add_item(str(peer_id))

func _update_connected_peers(new_peer_id):
	print("PEER CONNECTED")
	fill_connected_peers()

func _on_create_game_button_down():
	var lobby_code = Network.create_lobby()
	
	$Screen1.hide()
	$Screen2.show()
	$Screen2/CodeValueLabel.text = lobby_code
	fill_connected_peers()
	multiplayer.peer_connected.connect(_update_connected_peers)
	multiplayer.peer_disconnected.connect(_update_connected_peers)


func _on_join_game_button_down():
	var lobby_code = $Screen1/TextEdit.text
	Network.join_lobby(lobby_code)
	
	$Screen1.hide()
	$Screen2.show()
	$Screen2/CodeValueLabel.text = lobby_code
	fill_connected_peers()
	multiplayer.peer_connected.connect(_update_connected_peers)
	multiplayer.peer_disconnected.connect(_update_connected_peers)
