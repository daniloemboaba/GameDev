extends Node2D

@export var initial_enemy_count: int = 4
@export var min_spawn_distance_from_player: float = 280.0
@export var spawn_area_limit: float = 650.0

var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
var is_spawning_wave: bool = false
var wave_number: int = 1

@onready var player: Node2D = $Player

func _ready() -> void:
	# Garante que Y-Sort está ativo na cena principal
	y_sort_enabled = true

func _physics_process(_delta: float) -> void:
	if is_spawning_wave:
		return
	
	# Conta quantos inimigos vivos ainda existem na arena
	var living_enemies := 0
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			living_enemies += 1
	
	# Se todos os inimigos foram derrotados, gera uma nova horda aleatória!
	if living_enemies == 0:
		_start_next_wave()

func _start_next_wave() -> void:
	is_spawning_wave = true
	wave_number += 1
	
	# Pequeno intervalo antes do surgimento da nova onda (1.2 segundos)
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(_spawn_new_wave)

func _spawn_new_wave() -> void:
	var count_to_spawn := randi_range(4, 6)
	var player_pos := player.global_position if is_instance_valid(player) else Vector2.ZERO
	
	for i in range(count_to_spawn):
		var spawn_pos := _get_random_spawn_position(player_pos)
		var enemy_instance: Node2D = enemy_scene.instantiate()
		add_child(enemy_instance)
		enemy_instance.global_position = spawn_pos
		
		# Efeito visual de surgimento (animação de entrada)
		if enemy_instance.has_node("Visual"):
			var vis: Node2D = enemy_instance.get_node("Visual")
			vis.scale = Vector2(0.1, 0.1)
			vis.modulate = Color(2.0, 0.5, 2.5, 1.0) # Flash roxo de invocação
			var tween := create_tween().set_parallel(true)
			tween.tween_property(vis, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(vis, "modulate", Color.WHITE, 0.4)
	
	is_spawning_wave = false

func _get_random_spawn_position(player_pos: Vector2) -> Vector2:
	var attempts := 0
	while attempts < 20:
		attempts += 1
		var rx := randf_range(-spawn_area_limit, spawn_area_limit)
		var ry := randf_range(-spawn_area_limit, spawn_area_limit)
		var candidate := Vector2(rx, ry)
		
		# Garante que não nasce colado no jogador
		if candidate.distance_to(player_pos) >= min_spawn_distance_from_player:
			return candidate
	
	return player_pos + Vector2(300, 0).rotated(randf() * TAU)
