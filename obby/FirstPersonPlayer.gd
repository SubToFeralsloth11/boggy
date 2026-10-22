extends CharacterBody3D
class_name FirstPersonPlayer

@export var speed := 10.0
@export var jump_velocity := 8.0
@export var gravity := 24.0
@export var mouse_sensitivity := 0.0015

@onready var camera: Camera3D = $Camera3D

var checkpoint_position: Vector3 = Vector3.ZERO

# Animation state
var walk_cycle: float = 0.0
var is_moving: bool = false
var was_on_floor: bool = true

# Bobbing parameters
const WALK_SPEED: float = 12.0
const BOB_AMOUNT: float = 0.08
const BOB_SWAY: float = 0.03

func _ready() -> void:
	checkpoint_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.make_current()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	var direction = (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	is_moving = direction != Vector3.ZERO and is_on_floor()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 2)
		velocity.z = move_toward(velocity.z, 0, speed * 2)

	move_and_slide()

	_update_camera_bob(delta)

	if global_position.y < -50:
		reset_player()

	was_on_floor = is_on_floor()

func _update_camera_bob(delta: float) -> void:
	if is_moving:
		walk_cycle += delta * WALK_SPEED
		var cycle = walk_cycle
		
		# Camera bob up/down
		var bob = sin(cycle * 2) * BOB_AMOUNT
		var sway = sin(cycle) * BOB_SWAY
		camera.position.y = 1.7 + bob
		camera.position.x = sway
	else:
		# Smooth return to center
		camera.position.y = lerp(camera.position.y, 1.7, 0.15)
		camera.position.x = lerp(camera.position.x, 0.0, 0.15)

func set_checkpoint(pos: Vector3) -> void:
	checkpoint_position = pos

func reset_player() -> void:
	global_position = checkpoint_position
	velocity = Vector3.ZERO
	walk_cycle = 0.0
	camera.position = Vector3(0, 1.7, 0)
	camera.rotation = Vector3.ZERO
	rotation = Vector3.ZERO