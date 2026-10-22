extends CharacterBody3D

@export var speed := 7.0
@export var jump_velocity := 7.0
@export var gravity := 18.0
@export var mouse_sensitivity := 0.010

var checkpoint_position: Vector3

# Drag and drop your character's visual model node here from the scene tree
@export var player_mesh: Node3D
@onready var spring_arm: SpringArm3D = $SpringArm3D

func _ready() -> void:
	checkpoint_position = global_position
	# Locks and hides the mouse cursor inside the game window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 1. Rotate the whole player Left/Right (Yaw) using the mouse X axis
		rotate_y(-event.relative.x * mouse_sensitivity)
		# 2. Rotate ONLY the SpringArm Up/Down (Pitch) using the mouse Y axis
		# This completely prevents the camera from tilting sideways
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		# Clamp the vertical angle so the camera doesn't flip completely upside down
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-70), deg_to_rad(70))
	
	# Press Escape to unlock the mouse (useful for debugging)
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Because the player root rotates with the camera, 
	# movement vector calculation becomes clean and straightforward
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# OPTIONAL: Make the mesh face the exact direction you are walking
		# Remove these 2 lines if you want a classic shooter style where the mesh always faces forward
		var target_angle = atan2(-direction.x, -direction.z)
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, target_angle, 0.5)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	if global_position.y < -20:
		reset_player()

func set_checkpoint(pos: Vector3) -> void:
	checkpoint_position = pos

func reset_player() -> void:
	global_position = checkpoint_position
	velocity = Vector3.ZERO
