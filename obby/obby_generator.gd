extends Node3D
class_name ObbyGenerator

signal checkpoint_reached(checkpoint_index: int, height: float)
signal player_fell()

@export var platform_scene: PackedScene
@export var checkpoint_scene: PackedScene
@export var boost_pad_scene: PackedScene
@export var wall_scene: PackedScene
@export var metal_bar_scene: PackedScene

@export var initial_platform_count: int = 20
@export var generation_distance: float = 100.0
@export var cleanup_distance: float = 150.0
@export var checkpoint_interval: int = 10
@export var base_platform_gap: float = 3.0
@export var max_platform_gap: float = 5.5
@export var horizontal_spread: float = 8.0
@export var height_gain_per_platform: float = 2.0

# Platform variants (obj models)
@export var platform_models: Array = []

var platforms: Array[Node3D] = []
var checkpoints: Array[Node3D] = []
var current_height: float = 0.0
var highest_checkpoint: int = -1
var next_platform_id: int = 0
var player: Node3D = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# Use current time as seed for different map each run
	rng.seed = (int(Time.get_ticks_msec()) * 1000 + int(Time.get_unix_time_from_system())) % 2147483647
	call_deferred("_generate_initial_platforms")

func set_player(player_node: Node3D) -> void:
	player = player_node

func _process(delta: float) -> void:
	if not player:
		return

	var player_height = player.global_position.y

	# Generate more platforms ahead
	if player_height + generation_distance > current_height:
		_generate_platform_chunk(10)

	# Cleanup old platforms
	_cleanup_old_platforms(player_height)

	# Check checkpoint triggers
	_check_checkpoints(player_height)

func _generate_initial_platforms() -> void:
	# Starting platform - larger and centered
	var start_platform = _create_platform(Vector3(0, 0, 0), 0, true)
	current_height = 2.0

	# Generate initial chunk
	_generate_platform_chunk(initial_platform_count)

func _generate_platform_chunk(count: int) -> void:
	for i in range(count):
		var platform_type = _choose_platform_type()
		var pos = _calculate_next_position(platform_type)
		
		var platform = _create_platform(pos, next_platform_id, false, platform_type)
		next_platform_id += 1
		current_height = max(current_height, pos.y + 2.0)
		
		# Place checkpoint
		if next_platform_id % checkpoint_interval == 0:
			_place_checkpoint(pos + Vector3(0, 3, 0), next_platform_id / checkpoint_interval)

func _choose_platform_type() -> Dictionary:
	var height_factor = clamp(current_height / 200.0, 0.0, 1.0)

	var types = [
		{"type": "normal", "weight": 55 - height_factor * 25},
		{"type": "boost", "weight": 5 + height_factor * 5},
		{"type": "wall", "weight": 3 + height_factor * 7},
		{"type": "metal_bar", "weight": 2 + height_factor * 5},
		{"type": "normal", "weight": 10 + height_factor * 10},  # extra normal
	]

	var total_weight = 0
	for t in types:
		total_weight += t.weight

	var roll = rng.randi_range(1, total_weight)
	var cumulative = 0
	for t in types:
		cumulative += t.weight
		if roll <= cumulative:
			return t

	return {"type": "normal", "weight": 50}

func _calculate_next_position(platform_type: Dictionary) -> Vector3:
	var last_platform = platforms[platforms.size() - 1] if platforms.size() > 0 else null
	var base_y = last_platform.global_position.y if last_platform else 0
	var base_x = last_platform.global_position.x if last_platform else 0
	var base_z = last_platform.global_position.z if last_platform else 0

	# Height gain increases slightly with height but capped for jumpability
	var height_gain = height_gain_per_platform * (1.0 + current_height / 800.0)
	height_gain = clamp(height_gain, height_gain_per_platform, 4.0)

	# Gap calculation - ensure it's always jumpable
	# Max horizontal distance for a jump at speed 16, gravity 28, jump_vel 12:
	# Time to apex = 12/28 = 0.43s, total air time ~0.86s
	# Max horizontal distance = 16 * 0.86 = ~13.7 units
	# But we need margin, so keep gaps smaller
	var gap = rng.randi_range(int(base_platform_gap * 10), int(max_platform_gap * 10)) / 10.0
	gap *= (1.0 + current_height / 1500.0)
	gap = clamp(gap, base_platform_gap, 6.5)  # Cap at 6.5 for guaranteed jumps

	var x_offset = rng.randi_range(-int(horizontal_spread * 10), int(horizontal_spread * 10)) / 10.0
	var z_offset = rng.randi_range(-int(horizontal_spread * 10), int(horizontal_spread * 10)) / 10.0

	# Ensure some forward progress (positive Z)
	if z_offset < 1.0:
		z_offset = 1.0 + rng.randi_range(0, 20) / 10.0

	# Apply gap to Z offset (forward distance)
	z_offset = max(z_offset, gap)

	return Vector3(base_x + x_offset, base_y + height_gain, base_z + z_offset)

func _create_platform(position: Vector3, id: int, is_start: bool, platform_type: Dictionary = {"type": "normal"}) -> Node3D:
	var platform_node: Node3D
	var mesh_instance: MeshInstance3D = null

	if platform_type.type == "boost" and boost_pad_scene:
		platform_node = boost_pad_scene.instantiate()
	elif platform_type.type == "wall" and wall_scene:
		platform_node = wall_scene.instantiate()
	elif platform_type.type == "metal_bar" and metal_bar_scene:
		platform_node = metal_bar_scene.instantiate()
	elif platform_models.size() > 0:
		# Pick a random platform model (color variant)
		var model_scene = platform_models[rng.randi_range(0, platform_models.size() - 1)]
		if model_scene:
			platform_node = model_scene.instantiate()
		else:
			platform_node = platform_scene.instantiate()
	else:
		# Fallback: create a simple platform
		platform_node = StaticBody3D.new()
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3(4, 0.5, 4)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		mesh.surface_material_override = [mat]
		platform_node.add_child(mesh)
		var col = CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = Vector3(4, 0.5, 4)
		platform_node.add_child(col)

	if not platform_node:
		platform_node = Node3D.new()

	platform_node.name = "Platform_%d" % id

	# Add metadata
	platform_node.set_meta("platform_id", id)
	platform_node.set_meta("platform_type", platform_type.type)

	add_child(platform_node)
	platform_node.global_position = position
	platforms.append(platform_node)
	return platform_node

func _place_checkpoint(position: Vector3, index: int) -> void:
	if not checkpoint_scene:
		return

	var cp = checkpoint_scene.instantiate()
	cp.name = "Checkpoint_%d" % index
	cp.set_meta("checkpoint_index", index)

	# Add trigger behavior
	var trigger = cp.get_node_or_null("Trigger")
	if trigger:
		trigger.body_entered.connect(_on_checkpoint_body_entered.bind(index, cp))

	add_child(cp)
	cp.global_position = position
	checkpoints.append(cp)
func _on_boost_body_entered(body: Node3D, boost_pad: Node3D) -> void:
	if body.has_method("apply_boost"):
		body.apply_boost(Vector3.UP * 25.0)

func _on_checkpoint_body_entered(body: Node3D, index: int, cp: Node3D) -> void:
	if body.has_method("set_checkpoint") and index > highest_checkpoint:
		highest_checkpoint = index
		body.set_checkpoint(cp.global_position + Vector3(0, 3, 0))
		checkpoint_reached.emit(index, cp.global_position.y)

func _check_checkpoints(player_height: float) -> void:
	for cp in checkpoints:
		var idx = cp.get_meta("checkpoint_index", -1)
		if idx > highest_checkpoint and player_height > cp.global_position.y - 5:
			highest_checkpoint = idx
			if player and player.has_method("set_checkpoint"):
				player.set_checkpoint(cp.global_position + Vector3(0, 3, 0))
			checkpoint_reached.emit(idx, cp.global_position.y)

func _cleanup_old_platforms(player_height: float) -> void:
	var to_remove = []
	for p in platforms:
		if player_height - p.global_position.y > cleanup_distance:
			to_remove.append(p)

	for p in to_remove:
		platforms.erase(p)
		p.queue_free()

	var cp_to_remove = []
	for cp in checkpoints:
		if player_height - cp.global_position.y > cleanup_distance + 50:
			cp_to_remove.append(cp)

	for cp in cp_to_remove:
		checkpoints.erase(cp)
		cp.queue_free()

func get_height() -> float:
	if player:
		return player.global_position.y
	return current_height

func get_checkpoint_count() -> int:
	return highest_checkpoint + 1

func reset() -> void:
	for p in platforms:
		p.queue_free()
	for cp in checkpoints:
		cp.queue_free()
	platforms.clear()
	checkpoints.clear()
	current_height = 0.0
	highest_checkpoint = -1
	next_platform_id = 0
	# Re-seed for new map on reset
	rng.seed = (int(Time.get_ticks_msec()) * 1000 + int(Time.get_unix_time_from_system())) % 2147483647
	_generate_initial_platforms()