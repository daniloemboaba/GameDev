extends CharacterBody2D

# Configurações de Movimento Horizontal
@export var speed: float = 350.0
@export var acceleration: float = 2400.0
@export var friction: float = 2000.0
@export var air_acceleration: float = 1400.0
@export var air_friction: float = 800.0

# Configurações de Pulo Responsivo
@export var jump_velocity: float = -600.0
@export var gravity: float = 1700.0
@export var fall_gravity_multiplier: float = 1.5
@export var coyote_time_duration: float = 0.12
@export var jump_buffer_duration: float = 0.12

# Configurações de Dash
@export var dash_speed: float = 660.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

# Variáveis de Estado
var facing_direction: float = 1.0 # 1 = direita, -1 = esquerda
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	# Atualiza timers
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if is_dashing:
		_process_dash(delta)
		return
	
	# Leitura de Input Horizontal
	var input_x := Input.get_axis("move_left", "move_right")
	if input_x != 0:
		facing_direction = sign(input_x)
		if sprite:
			sprite.flip_h = (facing_direction < 0)
	
	# Controle do Chão e Coyote Time
	if is_on_floor():
		coyote_timer = coyote_time_duration
	else:
		coyote_timer -= delta
	
	# Jump Buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_duration
	else:
		jump_buffer_timer -= delta
	
	# Execução do Pulo
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
	
	# Pulo Variável (soltar o botão corta a subida mais rápido para controle fino)
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5
	
	# Gravidade Dinâmica (cai mais rápido do que sobe, eliminando sensação lenta/flutuante)
	if not is_on_floor():
		var current_gravity := gravity
		if velocity.y > 0:
			current_gravity *= fall_gravity_multiplier
		velocity.y += current_gravity * delta
	
	# Movimentação Horizontal com Aceleração / Atrito
	var accel := acceleration if is_on_floor() else air_acceleration
	var frict := friction if is_on_floor() else air_friction
	
	if input_x != 0:
		velocity.x = move_toward(velocity.x, input_x * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, frict * delta)
	
	# Verificação de Ativação do Dash (Tecla E ou LT no Xbox)
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		_start_dash(input_x)
		return
	
	move_and_slide()

func _start_dash(input_x: float) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	# Se estiver segurando direção, usa ela; senão dá o dash para onde está olhando
	if input_x != 0:
		dash_direction = Vector2(sign(input_x), 0)
	else:
		dash_direction = Vector2(facing_direction, 0)
	
	velocity = dash_direction * dash_speed
	
	# Efeito visual de dash (fica azulado e semi-transparente)
	if sprite:
		sprite.modulate = Color(0.4, 0.8, 1.0, 0.8)

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed
	move_and_slide()
	
	if dash_timer <= 0:
		is_dashing = false
		# Restaura a cor normal
		if sprite:
			sprite.modulate = Color.WHITE
