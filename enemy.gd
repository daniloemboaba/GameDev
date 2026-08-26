extends CharacterBody2D

@export var speed: float = 130.0
@export var detection_range: float = 500.0
@export var stop_distance: float = 20.0

var player_node: Node2D = null

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D

func _ready() -> void:
	# Procura pelo nó do jogador na cena
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]

func _physics_process(delta: float) -> void:
	if player_node == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
		return
	
	var to_player := player_node.global_position - global_position
	var distance := to_player.length()
	
	if distance < detection_range and distance > stop_distance:
		var direction := to_player.normalized()
		velocity = velocity.move_toward(direction * speed, 800.0 * delta)
		
		# Gira o inimigo encarando o jogador
		if visual:
			var target_angle := direction.angle()
			visual.rotation = lerp_angle(visual.rotation, target_angle, 10.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	
	move_and_slide()
