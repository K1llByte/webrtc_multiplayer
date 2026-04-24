extends Node

################################################################################
# Data
################################################################################

# Peer ids of connected players
var players: Array[int] = []
# Key is peer id and value is player name
var players_data: Dictionary[int, String] = {}
