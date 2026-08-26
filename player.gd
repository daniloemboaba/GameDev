extends CharacterBody2D

# Configurações de Movimento Top-Down
@export var speed: float = 320.0
@export var acceleration: float = 2400.0
@export var friction: float = 2200.0

# Configurações de Dash Top-Down (8 direções)
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

# Variáveis de Estado
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var last_movement_direction: Vector2 = Vector2.DOWN

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D

func _physics_process(delta: float) -> void:
	# Atualiza cooldown do dash
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	# Processamento de Dash
	if is_dashing:
		_process_dash(delta)
		return
	
	# Leitura de movimento em 8 direções (WASD / Setas / Analógico)
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		last_movement_direction = input_vector.normalized()
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		
		# Gira o rostinho/corpo do personagem na direção do movimento
		if visual:
			# Rotação suave e natural na direção que está andando
			var target_angle := input_vector.angle()
			visual.rotation = lerp_angle(visual.rotation, target_angle, 18.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	# Ativação do Dash (Tecla E ou LT no controle Xbox)
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_start_dash(input_vector)
		return
	
	move_and_slide()

func _start_dash(input_vector: Vector2) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	if input_vector != Vector2.ZERO:
		dash_direction = input_vector.normalized()
	else:
		dash_direction = last_movement_direction
	
	velocity = dash_direction * dash_speed
	
	# Efeito visual de dash (cor azulada brilhante)
	if sprite:
		sprite.modulate = Color(0.3, 0.9, 1.0, 0.8)

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed
	move_and_slide()
	
	if dash_timer <= 0.0:
		is_dashing = false
		if sprite:
			sprite.modulate = Color.WHITE
