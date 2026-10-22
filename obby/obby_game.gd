extends Node3D
class_name ObbyGame

var generator: ObbyGenerator
var player: RobloxCharacter
var ui_root: CanvasLayer

# UI elements
var height_label: Label
var height_bar: ProgressBar
var time_label: Label
var time_bar: ProgressBar
var cp_label: Label
var cp_bar: ProgressBar
var speed_label: Label

var game_start_time: float = 0
var game_paused: bool = false
var max_height: float = 0

func _ready() -> void:
	# Get references
	generator = $ObbyGenerator
	player = $Player
	
	# Load all platform variants
	var platform_scenes = [
		preload("res://platform_blue.tscn"),
		preload("res://platform_pink.tscn"),
		preload("res://platform_green.tscn"),
		preload("res://platform_purple.tscn"),
		preload("res://platform_red.tscn"),
		preload("res://platform_yellow.tscn"),
	]
	generator.platform_models = platform_scenes
	generator.checkpoint_scene = preload("res://checkpoint.tscn")
	generator.boost_pad_scene = preload("res://boost_pad.tscn")
	generator.wall_scene = preload("res://wall.tscn")
	generator.metal_bar_scene = preload("res://metal_bar.tscn")
	generator.platform_scene = preload("res://platform_blue.tscn")
	
	generator.set_player(player)
	generator.checkpoint_reached.connect(_on_checkpoint_reached)
	
	player.set_checkpoint(Vector3(0, 3, 0))
	
	# Create UI programmatically
	_create_ui()
	
	game_start_time = Time.get_ticks_msec() / 1000.0
	_reset_ui()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _create_ui() -> void:
	ui_root = CanvasLayer.new()
	add_child(ui_root)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.anchors_preset = Control.PRESET_FULL_RECT
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = 20
	main_vbox.offset_bottom = 20
	ui_root.add_child(main_vbox)
	
	# Top bar
	var top_hbox = HBoxContainer.new()
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(top_hbox)
	
	# Height panel
	var height_panel_data = _create_stat_panel("HEIGHT", Color(0.7, 0.9, 1), Color(0.2, 1, 1), 
		Color(0.2, 0.8, 1), 1000)
	height_label = height_panel_data["label"]
	height_bar = height_panel_data["bar"]
	top_hbox.add_child(height_panel_data["panel"])
	
	# Time panel
	var time_panel_data = _create_stat_panel("TIME", Color(1, 0.9, 0.7), Color(1, 0.8, 0.2),
		Color(1, 0.8, 0.2), 3600)
	time_label = time_panel_data["label"]
	time_bar = time_panel_data["bar"]
	top_hbox.add_child(time_panel_data["panel"])
	
	# Checkpoint panel
	var cp_panel_data = _create_stat_panel("CHECKPOINTS", Color(1, 0.7, 0.7), Color(1, 0.3, 0.3),
		Color(1, 0.3, 0.3), 100)
	cp_label = cp_panel_data["label"]
	cp_bar = cp_panel_data["bar"]
	top_hbox.add_child(cp_panel_data["panel"])
	
	# Bottom info
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_hbox.alignment = 1  # BoxContainer.ALIGN_CENTER
	main_vbox.add_child(bottom_hbox)
	
	speed_label = Label.new()
	speed_label.text = "Speed: 0 m/s"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.add_theme_font_size_override("font_size", 16)
	speed_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(speed_label)

func _create_stat_panel(title: String, title_color: Color, value_color: Color, 
		bar_color: Color, max_val: float) -> Dictionary:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 100)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = 10
	vbox.offset_bottom = 10
	panel.add_child(vbox)
	
	var t_label = Label.new()
	t_label.text = title
	t_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_label.add_theme_font_size_override("font_size", 14)
	t_label.add_theme_color_override("font_color", title_color)
	t_label.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(t_label)
	
	var v_label = Label.new()
	v_label.text = "0"
	v_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_label.add_theme_font_size_override("font_size", 28)
	v_label.add_theme_color_override("font_color", value_color)
	v_label.custom_minimum_size = Vector2(0, 35)
	vbox.add_child(v_label)
	
	var bar_bg = PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(0, 8)
	var bar_bg_style = StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0, 0, 0, 0.7)
	bar_bg_style.corner_radius_top_left = 4
	bar_bg_style.corner_radius_top_right = 4
	bar_bg_style.corner_radius_bottom_left = 4
	bar_bg_style.corner_radius_bottom_right = 4
	bar_bg.add_theme_stylebox_override("panel", bar_bg_style)
	vbox.add_child(bar_bg)
	
	var p_bar = ProgressBar.new()
	p_bar.anchors_preset = Control.PRESET_FULL_RECT
	p_bar.offset_left = 2
	p_bar.offset_top = 2
	p_bar.offset_right = 2
	p_bar.offset_bottom = 2
	p_bar.max_value = max_val
	p_bar.value = 0
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = bar_color
	bar_style.corner_radius_top_left = 4
	bar_style.corner_radius_top_right = 4
	bar_style.corner_radius_bottom_left = 4
	bar_style.corner_radius_bottom_right = 4
	p_bar.add_theme_stylebox_override("progress", bar_style)
	p_bar.add_theme_stylebox_override("background", bar_bg_style)
	bar_bg.add_child(p_bar)
	
	return {"panel": panel, "label": v_label, "bar": p_bar}

func _reset_ui() -> void:
	game_start_time = Time.get_ticks_msec() / 1000.0
	max_height = 0
	if height_label: height_label.text = "0 m"
	if height_bar: height_bar.value = 0
	if time_label: time_label.text = "00:00.00"
	if time_bar: time_bar.value = 0
	if cp_label: cp_label.text = "0"
	if cp_bar: cp_bar.value = 0
	if speed_label: speed_label.text = "Speed: 0 m/s"

func _process(delta: float) -> void:
	if game_paused:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0 - game_start_time
	var height = generator.get_height()
	var cp_count = generator.get_checkpoint_count()
	var speed = player.velocity.length()
	
	_update_height(height)
	_update_time(current_time)
	_update_checkpoints(cp_count)
	_update_speed(speed)
	
	max_height = max(max_height, height)
	
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()

func _update_height(height: float) -> void:
	if height_label:
		height_label.text = "%d m" % max(height, 0)
	if height_bar:
		height_bar.value = clamp(height, 0, height_bar.max_value)

func _update_time(elapsed: float) -> void:
	var mins = int(elapsed / 60)
	var secs = int(fmod(elapsed, 60.0))
	var ms = int((elapsed - int(elapsed)) * 100)
	if time_label:
		time_label.text = "%02d:%02d.%02d" % [mins, secs, ms]
	if time_bar:
		time_bar.value = clamp(elapsed, 0, time_bar.max_value)

func _update_checkpoints(count: int) -> void:
	if cp_label:
		cp_label.text = str(count)
	if cp_bar:
		cp_bar.value = clamp(count, 0, cp_bar.max_value)

func _update_speed(speed: float) -> void:
	if speed_label:
		speed_label.text = "Speed: %.1f m/s" % speed

func _on_checkpoint_reached(index: int, height: float) -> void:
	print("Checkpoint %d reached at height %.1f" % [index, height])

func toggle_pause() -> void:
	game_paused = not game_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game_paused else Input.MOUSE_MODE_CAPTURED
	get_tree().paused = game_paused

func reset_game() -> void:
	generator.reset()
	player.reset_player()
	game_start_time = Time.get_ticks_msec() / 1000.0
	_reset_ui()
	game_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED