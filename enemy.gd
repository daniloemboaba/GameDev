extends CharacterBody2D

@export var speed: float = 130.0
@export var detection_range: float = 500.0
@export var stop_distance: float = 20.0
@export var max_health: int = 2

var current_health: int = 2
var is_dead: bool = false
var is_flashing: bool = false
var player_node: Node2D = null

@onready var visual: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	current_health = max_health
	input_pickable = true # Permite detecção de clique do mouse sobre o inimigo
	
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_dead:
		return
	# Clique com o botão esquerdo no inimigo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_instance_valid(player_node) and player_node.has_method("cast_beam_attack"):
			player_node.cast_beam_attack(self)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if player_node == null or not is_instance_valid(player_node):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
		return
	
	var to_player := player_node.global_position - global_position
	var distance := to_player.length()
	
	if distance < detection_range and distance > stop_distance:
		var direction := to_player.normalized()
		velocity = velocity.move_toward(direction * speed, 800.0 * delta)
		
		if visual:
			var target_angle := direction.angle()
			visual.rotation = lerp_angle(visual.rotation, target_angle, 10.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	
	move_and_slide()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	current_health -= amount
	
	if current_health <= 0:
		_disintegrate()
	else:
		_hit_flash()

func _hit_flash() -> void:
	# Efeito de dano no 1º golpe (flash branco/roxo)
	var tween := create_tween()
	if visual:
		visual.modulate = Color(2.0, 0.5, 2.0, 1.0)
		tween.tween_property(visual, "modulate", Color.WHITE, 0.2)

func _disintegrate() -> void:
	is_dead = true
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Som de desintegração
	var audio := AudioStreamPlayer2D.new()
	get_parent().add_child(audio)
	audio.global_position = global_position
	var dis_sfx: AudioStream = load("res://assets/sounds/disintegrate.wav")
	if dis_sfx:
		audio.stream = dis_sfx
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	# Partículas de desintegração (cinzas e energia roxa/plasma)
	var particles := CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 55
	particles.lifetime = 0.7
	particles.spread = 180.0
	particles.gravity = Vector2(0, -60) # Flutua para cima como cinzas
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.85, 0.3, 1.0, 0.95)
	
	# Animação de dissolução do corpo
	if visual:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(visual, "modulate", Color(1.5, 0.2, 1.8, 0.0), 0.55)
		tween.tween_property(visual, "scale", Vector2(1.4, 1.4), 0.55)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
