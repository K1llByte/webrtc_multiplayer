extends Node

################################################################################
# Data
################################################################################

var ws := WebSocketPeer.new()
var lobby_code: String
# WebRTC
var webrtc_peer := WebRTCMultiplayerPeer.new()
var peer_id: int

const LOBBY_SERVER_URL := "lobby_server.killbyte.workers.dev"
#var LOBBY_SERVER_URL := "192.168.1.156:8787"

################################################################################
# Implementations
################################################################################


func create_lobby() -> Variant:
	var err = ws.connect_to_url("wss://%s/create" % LOBBY_SERVER_URL)
	if err != OK:
		print("WebSocket connection failed: ", err)
	else:
		print("Connected to lobby server")

	var lobby_code = receive_lobby_code()
	#start_webrtc_as_host()
	return lobby_code


func receive_lobby_code() -> String:
	while true:
		ws.poll()
		while ws.get_available_packet_count() > 0:
			var packet = ws.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(packet)

			match msg.get("type", ""):
				"lobby_code":
					handle_lobby_code(msg["value"])
					return msg["value"]
	return ""


func start_webrtc_as_host():
	print("Starting WebRTC host")

	webrtc_peer.create_server()
	# Host should always be 1
	peer_id = 1

	multiplayer.multiplayer_peer = webrtc_peer

	# Create local offer (Godot handles internally)
	#var offer = webrtc_peer.create_offer(peer_id)

	#send_signal({
		#"type": "offer",
		#"data": offer
	#})

func join_lobby(lobby_code: String):
	#var err = ws.connect_to_url("wss://lobby_server.killbyte.workers.dev/join?lobby_code=%s" % lobby_code)
	var err = ws.connect_to_url("wss://%s/join?lobby_code=%s" % [LOBBY_SERVER_URL, lobby_code])
	
	if err != OK:
		print("WebSocket connection failed: ", err)
	else:
		print("Connected to lobby server %s" % lobby_code)


func _process(_delta):
	ws.poll()
	
	while ws.get_available_packet_count() > 0:
		var packet = ws.get_packet().get_string_from_utf8()
		var msg = JSON.parse_string(packet)
		if msg == null:
			print("Invalid message")
			return

		match msg.get("type", ""):
			"lobby_code":
				handle_lobby_code(msg["value"])
			"offer":
				handle_offer(msg["data"])
			"answer":
				handle_answer(msg["data"])
			"ice":
				handle_ice(msg["data"])
	
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSING:
		print("Disconnected from lobby server")


func handle_lobby_code(code: String):
	print("Received lobby_code: ", code)
	lobby_code = code


func handle_answer(answer):
	print("Received answer")
	webrtc_peer.set_remote_description(1, answer)


func start_as_client():
	print("Waiting for offer...")


func handle_offer(offer):
	print("Received offer")

	webrtc_peer.create_mesh(peer_id)
	webrtc_peer.set_remote_description(1, offer)

	var answer = webrtc_peer.create_answer(peer_id)

	send_signal({
		"type": "answer",
		"data": answer
	})


func handle_ice(candidate):
	self.webrtc_peer.add_ice_candidate(1, candidate)


#func create_peer():
	#var peer_conn = WebRTCPeerConnection.new()
	#peer_conn.initialize({
		#"iceServers": [
			#{ "urls": ["stun:stun.l.google.com:19302"] }
		#]
	#})
	#
	#self.webrtc_peer.add_peer(peer_conn, self.peer_id)


func offer_created():
	pass


func send_signal(data: Dictionary):
	var json = JSON.stringify(data)
	ws.send_text(json)

func is_host():
	pass
