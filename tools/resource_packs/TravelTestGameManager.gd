extends Node

var player_reference: Node3D = null
var current_language := "ar"
var notifications: Array[String] = []

func register_player(player: Node3D) -> void:
	player_reference = player

func post_notification(message: String, _alert: bool = false) -> void:
	notifications.append(message)
