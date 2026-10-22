extends CharacterBody3D
class_name RobloxCharacter

@export var speed := 16.0
@export var jump_velocity := 12.0
@export var gravity := 28.0
@export var mouse_sensitivity := 0.002

@onready var graphics: Node3D = $Graphics
@onready var torso: MeshInstance3D = $Graphics/Torso
@onready var head: MeshInstance3D = $Graphics/Head
@onready var left_arm: Node3D = $Graphics/LeftArm
@onready var right_arm: Node3D = $Graphics/RightArm
@onready var left_leg: Node3D = $Graphics/LeftLeg
@onready var right_leg: Node3D = $Graphics/RightLeg

var camera_pivot: Node3D
var camera_boom: Node3D
var camera: Camera3D

var checkpoint_position: Vector3 = Vector3.ZERO

# Animation state
var walk_cycle: float = 0.0
var idle_cycle: float = 0.0
var is_moving: bool = false
var was_on_floor: bool = true
var jump_anim_timer: float = 0.0
var fall_anim_timer: float = 0.0

# Bobbing parameters
const WALK_SPEED: float = 14.0
const BOB_AMOUNT: float = 0.35
const ARM_SWING: float = 1.1
const LEG_SWING: float = 0.9
const IDLE_BOB_SPEED: float = 2.0
const IDLE_BOB_AMOUNT: float = 0.04
const BREATH_SPEED: float = 1.5
const BREATH_AMOUNT: float = 0.025

func _ready() -> void:
	checkpoint_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create camera hierarchy in code to avoid scene instantiation issues
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 2, 0)
	add_child(camera_pivot)
	
	camera_boom = Node3D.new()
	camera_boom.name = "CameraBoom"
	camera_boom.position = Vector3(0, 0, -4.5)
	camera_pivot.add_child(camera_boom)
	
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 75
	camera_boom.add_child(camera)
	
	# Make camera current
	camera.make_current()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw: rotate the camera pivot (horizontal look)
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		# Pitch: rotate only the camera boom (vertical look)
		camera_boom.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_boom.rotation.x = clamp(camera_boom.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		jump_anim_timer = 0.3

	# Get input relative to CAMERA (camera_pivot), not character body
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Calculate movement direction relative to camera's horizontal rotation (camera_pivot)
	# camera_pivot.rotation.y is the yaw of the camera
	var camera_yaw = camera_pivot.rotation.y
	var direction = Vector3(
		input_dir.x * cos(camera_yaw) - input_dir.y * sin(camera_yaw),
		0,
		input_dir.x * sin(camera_yaw) + input_dir.y * cos(camera_yaw)
	).normalized()
	
	is_moving = direction != Vector3.ZERO and is_on_floor()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Character graphics face movement direction (smooth turn)
		var target_angle = atan2(-direction.x, -direction.z)
		graphics.rotation.y = lerp_angle(graphics.rotation.y, target_angle, 0.15)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 2)
		velocity.z = move_toward(velocity.z, 0, speed * 2)

	move_and_slide()

	_update_animations(delta)

	if global_position.y < -50:
		reset_player()

	was_on_floor = is_on_floor()

func _update_animations(delta: float) -> void:
	# Breathing animation (always active)
	idle_cycle += delta * BREATH_SPEED
	var breath = sin(idle_cycle) * BREATH_AMOUNT
	torso.scale = Vector3(1 + breath, 1 - breath * 0.5, 1 + breath)
	head.scale = Vector3(1 + breath * 0.5, 1 + breath * 0.5, 1 + breath * 0.5)

	if is_moving and is_on_floor():
		# Walking/running cycle
		walk_cycle += delta * WALK_SPEED
		var cycle = walk_cycle
		
		# Body bob up/down
		var bob = sin(cycle * 2) * BOB_AMOUNT
		graphics.position.y = bob
		
		# Body lean forward slightly when running
		graphics.rotation.x = lerp(graphics.rotation.x, -0.15, 0.1)
		
		# Arm swing (opposite to legs)
		var arm_swing = sin(cycle) * ARM_SWING
		left_arm.rotation.x = -arm_swing
		right_arm.rotation.x = arm_swing
		
		# Leg swing
		var leg_swing = sin(cycle) * LEG_SWING
		left_leg.rotation.x = leg_swing
		right_leg.rotation.x = -leg_swing
		
		# Head slight counter-bob
		head.rotation.x = -bob * 0.5
		
	elif is_on_floor():
		# Idle animation
		graphics.position.y = lerp(graphics.position.y, 0, 0.1)
		graphics.rotation.x = lerp(graphics.rotation.x, 0, 0.1)
		
		# Idle sway
		var sway = sin(idle_cycle * 0.5) * IDLE_BOB_AMOUNT
		graphics.rotation.z = sway
		
		# Arms hang naturally with slight idle movement
		left_arm.rotation.x = lerp(left_arm.rotation.x, sin(idle_cycle) * 0.1, 0.1)
		right_arm.rotation.x = lerp(right_arm.rotation.x, -sin(idle_cycle) * 0.1, 0.1)
		
		# Legs return to center
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0, 0.15)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0, 0.15)
		
		head.rotation.x = lerp(head.rotation.x, 0, 0.1)

	else:
		# Air/jump/fall animation
		graphics.position.y = lerp(graphics.position.y, 0.0, 0.1)
		graphics.rotation.x = lerp(graphics.rotation.x, 0.0, 0.1)
		
		if jump_anim_timer > 0:
			jump_anim_timer -= delta
			# Jump pose - knees up, arms up
			left_leg.rotation.x = lerp(left_leg.rotation.x, 0.8, 0.2)
			right_leg.rotation.x = lerp(right_leg.rotation.x, 0.8, 0.2)
			left_arm.rotation.x = lerp(left_arm.rotation.x, -1.2, 0.2)
			right_arm.rotation.x = lerp(right_arm.rotation.x, -1.2, 0.2)
		else:
			fall_anim_timer += delta
			# Falling pose - arms out, legs down
			left_arm.rotation.x = lerp(left_arm.rotation.x, 0.5 * sin(fall_anim_timer * 3), 0.1)
			right_arm.rotation.x = lerp(right_arm.rotation.x, -0.5 * sin(fall_anim_timer * 3), 0.1)
			left_leg.rotation.x = lerp(left_leg.rotation.x, -0.3, 0.1)
			right_leg.rotation.x = lerp(right_leg.rotation.x, -0.3, 0.1)
		
		head.rotation.x = lerp(head.rotation.x, 0.0, 0.1)

func set_checkpoint(pos: Vector3) -> void:
	checkpoint_position = pos

func reset_player() -> void:
	global_position = checkpoint_position
	velocity = Vector3.ZERO
	walk_cycle = 0.0
	idle_cycle = 0.0
	jump_anim_timer = 0.0
	fall_anim_timer = 0.0
	graphics.position = Vector3.ZERO
	graphics.rotation = Vector3.ZERO
	camera_pivot.rotation = Vector3.ZERO
	camera_boom.rotation = Vector3.ZERO
	left_arm.rotation = Vector3.ZERO
	right_arm.rotation = Vector3.ZERO
	left_leg.rotation = Vector3.ZERO
	right_leg.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	torso.scale = Vector3.ONE
	head.scale = Vector3.ONE

func apply_boost(force: Vector3) -> void:
	velocity += force
	jump_anim_timer = 0.5