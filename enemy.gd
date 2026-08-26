extends CharacterBody2D

@export var speed: float = 130.0
@export var detection_range: float = 500.0
@export var stop_distance: float = 20.0
@export var max_health: int = 2

var current_health: int = 2
var is_dead: bool = false
var player_node: Node2D = null
var is_hovered: bool = false

@onready var visual: Node2D = $Visual
@onready var body_rect: ColorRect = $Visual/Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	current_health = max_health
	input_pickable = true
	
	if body_rect:
		# Conecta eventos de mouse diretamente no quadrado visual para clique 100% preciso
		body_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		body_rect.gui_input.connect(_on_body_gui_input)
		body_rect.mouse_entered.connect(_on_mouse_entered)
		body_rect.mouse_exited.connect(_on_mouse_exited)
	
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]

func _on_body_gui_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_trigger_player_attack()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_trigger_player_attack()

func _on_mouse_entered() -> void:
	if is_dead:
		return
	is_hovered = true
	# Efeito visual de foco/mira ao passar o mouse por cima
	if visual:
		visual.scale = Vector2(1.1, 1.1)

func _on_mouse_exited() -> void:
	is_hovered = false
	if visual and not is_dead:
		visual.scale = Vector2(1.0, 1.0)

func is_point_inside(global_pos: Vector2) -> bool:
	if is_dead:
		return false
	# Detecção precisa de clique cobrindo todo o quadrado (e margem de tolerância de 32px)
	var dist := global_position.distance_to(global_pos)
	if dist <= 36.0:
		return true
	var local_pos := global_pos - global_position
	return abs(local_pos.x) <= 28.0 and abs(local_pos.y) <= 28.0

func _trigger_player_attack() -> void:
	if not is_instance_valid(player_node):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
	
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
	var tween := create_tween()
	if visual:
		visual.modulate = Color(2.2, 0.4, 2.2, 1.0)
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
	
	# Partículas de desintegração
	var particles := CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 55
	particles.lifetime = 0.7
	particles.spread = 180.0
	particles.gravity = Vector2(0, -60)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.85, 0.3, 1.0, 0.95)
	
	if visual:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(visual, "modulate", Color(1.5, 0.2, 1.8, 0.0), 0.55)
		tween.tween_property(visual, "scale", Vector2(1.4, 1.4), 0.55)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
