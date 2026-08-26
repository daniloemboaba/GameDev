extends CharacterBody2D

# Configurações de Movimento Top-Down
@export var speed: float = 320.0
@export var acceleration: float = 2400.0
@export var friction: float = 2200.0

# Configurações de Dash Top-Down (8 direções)
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

# Configurações de Zoom da Câmera (Mouse Scroll)
@export var default_zoom: float = 2.0
@export var min_zoom: float = 0.8
@export var max_zoom: float = 3.5
@export var zoom_step: float = 0.25
var target_zoom: float = 2.0

# Cena do Ataque de Raio Roxo (Chidori + Kamehameha)
var beam_scene: PackedScene = preload("res://scenes/attacks/beam_attack.tscn")

# Dicionários de Texturas das 8 Direções
var idle_textures: Dictionary = {}
var walk_textures: Dictionary = {}
var attack_textures: Dictionary = {}

# Variáveis de Animação e Estado
var current_direction: String = "down"
var last_movement_direction: Vector2 = Vector2.DOWN

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN

var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_duration: float = 0.3
var attack_anim_fps: float = 14.0

var walk_anim_timer: float = 0.0
var walk_anim_fps: float = 12.0
var idle_breath_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	target_zoom = default_zoom
	if camera:
		camera.zoom = Vector2(target_zoom, target_zoom)
		camera.position_smoothing_enabled = true
	
	var dir_names := ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]
	
	# 1. Carrega as 8 texturas Idle
	for d in dir_names:
		var path := "res://assets/sprites/player/idle_%s.png" % d
		if ResourceLoader.exists(path):
			idle_textures[d] = load(path)
	
	# 2. Carrega os frames de Caminhada (8 frames x 8 direções)
	for d in dir_names:
		walk_textures[d] = []
		for f in range(8):
			var path := "res://assets/sprites/player/walk_%s_%d.png" % [d, f]
			if ResourceLoader.exists(path):
				walk_textures[d].append(load(path))
	
	# 3. Carrega os frames de Ataque
	for d in dir_names:
		attack_textures[d] = []
		for f in range(4):
			var path := "res://assets/sprites/player/attack_%s_%d.png" % [d, f]
			if ResourceLoader.exists(path):
				attack_textures[d].append(load(path))
	
	_update_sprite()

func _unhandled_input(event: InputEvent) -> void:
	# 1. Controle de Zoom com Scroll do Mouse
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom + zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_check_click_target_enemy(get_global_mouse_position())

func _check_click_target_enemy(click_pos: Vector2) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best_target: Node2D = null
	var min_dist: float = 60.0 # Hitbox generosa e precisa
	
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			# Verifica se o clique está dentro do corpo do inimigo
			if enemy.has_method("is_point_inside") and enemy.is_point_inside(click_pos):
				best_target = enemy
				break
			
			var d: float = enemy.global_position.distance_to(click_pos)
			if d < min_dist:
				min_dist = d
				best_target = enemy
	
	if best_target != null:
		cast_beam_attack(best_target)

func cast_beam_attack(target_enemy: Node2D) -> void:
	if not is_instance_valid(target_enemy):
		return
	
	# Vira o personagem na direção do inimigo
	var to_enemy := target_enemy.global_position - global_position
	if to_enemy != Vector2.ZERO:
		current_direction = _get_direction_name_from_vector(to_enemy)
		last_movement_direction = to_enemy.normalized()
	
	is_attacking = true
	attack_timer = 0.0
	
	# Dispara o raio de energia roxo
	if beam_scene:
		var beam = beam_scene.instantiate()
		get_parent().add_child(beam)
		var spawn_offset := to_enemy.normalized() * 22.0 + Vector2(0, -15)
		beam.setup(global_position + spawn_offset, target_enemy)
	
	_update_sprite()

func _process(delta: float) -> void:
	if camera:
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), 12.0 * delta)

func _physics_process(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	if is_dashing:
		_process_dash(delta)
		return
	
	if is_attacking:
		attack_timer += delta
		_update_attack_animation()
		if attack_timer >= attack_duration:
			is_attacking = false
	
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		last_movement_direction = input_vector.normalized()
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		
		if not is_attacking:
			current_direction = _get_direction_name_from_vector(input_vector)
			walk_anim_timer += delta * walk_anim_fps
			_update_sprite(true)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		walk_anim_timer = 0.0
		
		if not is_attacking:
			idle_breath_timer += delta * 4.0
			_update_sprite(false)
	
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_start_dash(input_vector)
		return
	
	move_and_slide()

func _update_attack_animation() -> void:
	if not sprite:
		return
	if attack_textures.has(current_direction) and attack_textures[current_direction].size() > 0:
		var frames: Array = attack_textures[current_direction]
		var frame_index := int(attack_timer * attack_anim_fps) % frames.size()
		sprite.texture = frames[frame_index]
		sprite.position.y = -25.0

func _update_sprite(is_moving: bool = false) -> void:
	if not sprite or is_attacking:
		return
	
	if is_moving and walk_textures.has(current_direction) and walk_textures[current_direction].size() > 0:
		var frames: Array = walk_textures[current_direction]
		var frame_index := int(walk_anim_timer) % frames.size()
		sprite.texture = frames[frame_index]
		sprite.position.y = -25.0
	else:
		if idle_textures.has(current_direction) and idle_textures[current_direction] != null:
			sprite.texture = idle_textures[current_direction]
		sprite.position.y = -25.0 + sin(idle_breath_timer) * 0.8

func _get_direction_name_from_vector(v: Vector2) -> String:
	var angle := v.angle()
	var octant := int(round(8.0 * angle / (2.0 * PI))) % 8
	if octant < 0:
		octant += 8
	
	match octant:
		0: return "right"
		1: return "down_right"
		2: return "down"
		3: return "down_left"
		4: return "left"
		5: return "up_left"
		6: return "up"
		7: return "up_right"
		_: return "down"

func _start_dash(input_vector: Vector2) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	if input_vector != Vector2.ZERO:
		dash_direction = input_vector.normalized()
	else:
		dash_direction = last_movement_direction
	
	velocity = dash_direction * dash_speed
	
	if sprite:
		sprite.modulate = Color(0.4, 0.9, 1.0, 0.8)

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed
	move_and_slide()
	
	if dash_timer <= 0.0:
		is_dashing = false
		if sprite:
			sprite.modulate = Color.WHITE
