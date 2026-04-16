extends Node

################################################################################
# Data
################################################################################

var ws := WebSocketPeer.new()
var lobby_code: String
# WebRTC
var webrtc_peer := WebRTCMultiplayerPeer.new()
var peer_id := randi_range(2, 2147483647)
var connected_peers := {}

const HOST_ID := 1
#const LOBBY_SERVER_URL := "127.0.0.1:8787"
const LOBBY_SERVER_URL := "lobbyserver.killbyte.dev"

signal lobby_created(lobby_code: String)

################################################################################
# Implementations
################################################################################

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
				#print("> Received Lobby packet in %s" % str(peer_id))
				handle_lobby_code(msg["value"])
			"offer":
				#print("> Received Offer packet in %s" % str(peer_id))
				handle_offer(msg)
			"answer":
				#print("> Received Answer packet in %s" % str(peer_id))
				handle_answer(msg)
			"ice":
				#print("> Received Ice packet in %s" % str(peer_id))
				handle_ice(msg)
	
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSING:
		print("Disconnected from lobby server")


func create_lobby():
	var err = ws.connect_to_url("ws://%s/create" % LOBBY_SERVER_URL)
	if err != OK:
		print("WebSocket connection failed: ", err)
		return;

	print("Connected to lobby server")


func join_lobby(lobby_code: String):
	var err = ws.connect_to_url("wss://%s/join?lobby_code=%s" % [LOBBY_SERVER_URL, lobby_code])
	if err != OK:
		print("WebSocket connection failed: ", err)
		return;

	print("Connected to lobby server %s" % lobby_code)
	
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		ws.poll()
	start_webrtc_as_client()
	self.lobby_code = lobby_code


#func receive_lobby_code() -> String:
#	while true:
#		ws.poll()
#		while ws.get_available_packet_count() > 0:
#			var packet = ws.get_packet().get_string_from_utf8()
#			var msg = JSON.parse_string(packet)

#			match msg.get("type", ""):
#				"lobby_code":
#					handle_lobby_code(msg["value"])
#					return msg["value"]
#	return ""


func start_webrtc_as_host():
	print("Starting WebRTC host")
	
	webrtc_peer.create_server()
	multiplayer.multiplayer_peer = webrtc_peer
	
	self.peer_id = HOST_ID


func start_webrtc_as_client():
	print("Starting WebRTC client")
	
	webrtc_peer.create_client(peer_id)
	multiplayer.multiplayer_peer = webrtc_peer
	
	var peer_conn = create_peer_connection(HOST_ID)
	# Will create and send SDP packet to remote peer through
	peer_conn.create_offer()
	print("%s WS state: %s" % [str(self.peer_id), str(ws.get_ready_state())])


func handle_lobby_code(code: String):
	print("Received lobby_code: ", code)
	self.lobby_code = code
	start_webrtc_as_host()
	lobby_created.emit(self.lobby_code)


# Host will receive connection offers from clients
func handle_offer(msg):
	if msg["to"] != self.peer_id: 
		return
	
	var from_id = int(msg["from"])
	if not connected_peers.has(from_id):
		create_peer_connection(from_id)

	var peer_conn = connected_peers[from_id]
	peer_conn.set_remote_description("offer", msg["sdp"])


# Client will receive connection answers from host
func handle_answer(msg):
	if msg["to"] != self.peer_id: 
		return
	
	var peer_conn = connected_peers[int(msg["from"])]
	peer_conn.set_remote_description("answer", msg["sdp"])


func handle_ice(msg):
	if msg["to"] != self.peer_id: 
		return
	
	var peer_conn = connected_peers[int(msg["from"])]
	peer_conn.add_ice_candidate(msg["mid"], msg["index"], msg["candidate"])


func create_peer_connection(id: int):
	var peer_conn = WebRTCPeerConnection.new()
	peer_conn.initialize({
		"iceServers": [
			{ "urls": ["stun:stun.l.google.com:19302"] }
		]
	})
	
	# Signal is emmited after calling create_offer() or set_remote_description()
	peer_conn.session_description_created.connect(_on_sdp_created.bind(id))
	# Signal is emmited when a new ICE candidate has been created
	peer_conn.ice_candidate_created.connect(_on_ice_created.bind(id))
	
	self.webrtc_peer.add_peer(peer_conn, id)
	connected_peers[id] = peer_conn
	return peer_conn


func send_signal(data: Dictionary):
	var json = JSON.stringify(data)
	ws.send_text(json)
	
func is_host() -> bool:
	return multiplayer.is_server()

################################################################################
# Signal handlers
################################################################################

func _on_sdp_created(type, sdp, id):
	var peer_conn = connected_peers[id]
	peer_conn.set_local_description(type, sdp)
	send_signal({
		"type": type,
		"to": id,
		"from": peer_id,
		"sdp": sdp
	})


func _on_ice_created(mid, index, candidate, id):
	send_signal({
		"type": "ice",
		"to": id,
		"from": peer_id,
		"candidate": candidate,
		"mid": mid,
		"index": index
	})
