extends Area2D

@export var speed: float = 950.0
@export var lifetime: float = 2.0

var target_enemy: Node2D = null
var direction: Vector2 = Vector2.RIGHT
var traveled_time: float = 0.0
var hit_performed: bool = false

# Cores do Chidori / Kamehameha Roxo
var core_color: Color = Color(1.0, 0.95, 1.0, 1.0) # Branco/lilás central
var aura_color: Color = Color(0.75, 0.2, 1.0, 0.95) # Roxo neon
var lightning_color: Color = Color(0.9, 0.45, 1.0, 0.95) # Magenta elétrico
var outer_glow: Color = Color(0.55, 0.1, 0.95, 0.45)

func _ready() -> void:
	# Toca o som do raio sintetizado
	var audio_player := AudioStreamPlayer2D.new()
	add_child(audio_player)
	var sfx: AudioStream = load("res://assets/sounds/beam_attack.wav")
	if sfx:
		audio_player.stream = sfx
		audio_player.play()
	
	body_entered.connect(_on_body_entered)

func setup(start_pos: Vector2, target: Node2D) -> void:
	global_position = start_pos
	target_enemy = target
	if is_instance_valid(target):
		direction = (target.global_position - start_pos).normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	traveled_time += delta
	if traveled_time >= lifetime:
		queue_free()
		return
	
	# Leve atração magnética até o alvo
	if is_instance_valid(target_enemy):
		var desired_dir := (target_enemy.global_position - global_position).normalized()
		direction = direction.slerp(desired_dir, 16.0 * delta)
		rotation = direction.angle()
	
	global_position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	var trail_length := 48.0
	var core_radius := 10.0
	
	# 1. Brilho/Aura externa
	draw_circle(Vector2.ZERO, core_radius * 1.8 + sin(traveled_time * 25.0) * 2.0, outer_glow)
	
	# 2. Núcleo central (Kamehameha roxo)
	draw_circle(Vector2.ZERO, core_radius, aura_color)
	draw_circle(Vector2.ZERO, core_radius * 0.55, core_color)
	
	# 3. Rastro e arcos elétricos oscilantes do Chidori
	var points_core := PackedVector2Array()
	var points_lightning_1 := PackedVector2Array()
	var points_lightning_2 := PackedVector2Array()
	
	var segments := 12
	for i in range(segments):
		var t := float(i) / float(segments)
		var lx := -t * trail_length
		points_core.append(Vector2(lx, 0))
		
		var wave1 := sin(traveled_time * 42.0 + t * 14.0) * (7.0 * (1.0 - t * 0.4))
		var wave2 := cos(traveled_time * 52.0 + t * 16.0) * (9.0 * (1.0 - t * 0.4))
		
		points_lightning_1.append(Vector2(lx, wave1))
		points_lightning_2.append(Vector2(lx, wave2))
	
	if points_core.size() > 1:
		draw_polyline(points_core, aura_color, 8.0)
		draw_polyline(points_core, core_color, 3.5)
	
	if points_lightning_1.size() > 1:
		draw_polyline(points_lightning_1, lightning_color, 2.5)
	if points_lightning_2.size() > 1:
		draw_polyline(points_lightning_2, core_color, 1.8)

func _on_body_entered(body: Node2D) -> void:
	if hit_performed:
		return
	
	if body.is_in_group("enemy") or (target_enemy != null and body == target_enemy):
		hit_performed = true
		if body.has_method("take_damage"):
			body.take_damage(1)
		_spawn_hit_impact()
		queue_free()

func _spawn_hit_impact() -> void:
	var particles := CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 26
	particles.lifetime = 0.45
	particles.spread = 180.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 240.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.9, 0.45, 1.0, 1.0)
	
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(particles.queue_free)
