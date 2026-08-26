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

# Texturas das 8 Direções (Idle e Walk Cycles)
var idle_textures: Dictionary = {}
var walk_textures: Dictionary = {} # "down": [f0, f1, f2, f3, f4, f5, f6, f7], ...

# Variáveis de Animação e Estado
var current_direction: String = "down"
var last_movement_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN

var walk_anim_timer: float = 0.0
var walk_anim_fps: float = 12.0
var idle_breath_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	target_zoom = default_zoom
	if camera:
		camera.zoom = Vector2(target_zoom, target_zoom)
		camera.position_smoothing_enabled = true
	
	var dir_names := ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]
	
	# Carrega as 8 texturas Idle
	for d in dir_names:
		var path := "res://assets/player_sprites/idle_%s.png" % d
		if ResourceLoader.exists(path):
			idle_textures[d] = load(path)
	
	# Carrega os 8 frames de caminhada para cada uma das 8 direções
	for d in dir_names:
		walk_textures[d] = []
		for f in range(8):
			var path := "res://assets/player_sprites/walk_%s_%d.png" % [d, f]
			if ResourceLoader.exists(path):
				walk_textures[d].append(load(path))
	
	_update_sprite()

func _unhandled_input(event: InputEvent) -> void:
	# Controle de Zoom com o Scroll do Mouse
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom + zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom - zoom_step, min_zoom, max_zoom)

func _process(delta: float) -> void:
	# Suavização do Zoom da Câmera
	if camera:
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), 12.0 * delta)

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
		
		# Atualiza a direção que o personagem está olhando
		current_direction = _get_direction_name_from_vector(input_vector)
		
		# Avança o ciclo de passos da caminhada (braços e pernas se movimentando)
		walk_anim_timer += delta * walk_anim_fps
		
		_update_sprite(true)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		walk_anim_timer = 0.0
		
		# Efeito sutil de respiração quando parado (idle)
		idle_breath_timer += delta * 4.0
		_update_sprite(false)
	
	# Ativação do Dash (Tecla E ou LT no controle Xbox)
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_start_dash(input_vector)
		return
	
	move_and_slide()

func _update_sprite(is_moving: bool = false) -> void:
	if not sprite:
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
