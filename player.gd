extends CharacterBody2D

# Configurações de Movimento Top-Down
@export var speed: float = 320.0
@export var acceleration: float = 2400.0
@export var friction: float = 2200.0

# Configurações de Dash Top-Down (8 direções)
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

# Texturas das 8 Direções (Montadas com Cabeça e Corpo)
var textures: Dictionary = {}

# Variáveis de Estado
var current_direction_name: String = "down"
var last_movement_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var idle_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Carrega as 8 texturas de direção
	textures["down"] = load("res://assets/player_sprites/idle_down.png")
	textures["down_right"] = load("res://assets/player_sprites/idle_down_right.png")
	textures["right"] = load("res://assets/player_sprites/idle_right.png")
	textures["up_right"] = load("res://assets/player_sprites/idle_up_right.png")
	textures["up"] = load("res://assets/player_sprites/idle_up.png")
	textures["up_left"] = load("res://assets/player_sprites/idle_up_left.png")
	textures["left"] = load("res://assets/player_sprites/idle_left.png")
	textures["down_left"] = load("res://assets/player_sprites/idle_down_left.png")
	
	_update_sprite_direction("down")

func _physics_process(delta: float) -> void:
	# Atualiza cooldown do dash
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	# Processamento de Dash
	if is_dashing:
		_process_dash(delta)
		return
	
	# Leitura de movimento em 8 direções
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		last_movement_direction = input_vector.normalized()
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		
		# Determina a direção olhando para o vetor de movimento
		var dir_name := _get_direction_name_from_vector(input_vector)
		if dir_name != current_direction_name:
			_update_sprite_direction(dir_name)
		
		# Efeito sutil de caminhada
		idle_time += delta * 12.0
		if sprite:
			sprite.position.y = sin(idle_time) * 2.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
		# Efeito sutil de respiração idle
		idle_time += delta * 4.0
		if sprite:
			sprite.position.y = sin(idle_time) * 1.0
	
	# Ativação do Dash (Tecla E ou LT no controle Xbox)
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_start_dash(input_vector)
		return
	
	move_and_slide()

func _get_direction_name_from_vector(v: Vector2) -> String:
	var angle := v.angle() # De -PI a +PI
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

func _update_sprite_direction(dir_name: String) -> void:
	current_direction_name = dir_name
	if sprite and textures.has(dir_name) and textures[dir_name] != null:
		sprite.texture = textures[dir_name]

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
