extends Control


func _on_create_game_button_down() -> void:
	var lobby_code = Network.create_lobby()
	print("Network.create_lobby returned %s" % lobby_code)
	$Screen1.hide()
	$Screen2.show()
	$Screen2/CodeValueLabel.text = lobby_code
	$Screen2/ItemList.add_item($Screen1/TextEdit.text)
