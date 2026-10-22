extends CanvasLayer

@onready var height_value: Label = $MainContainer/TopBar/HeightPanel/HeightVBox/HeightValue
@onready var height_bar: ProgressBar = $MainContainer/TopBar/HeightPanel/HeightVBox/HeightBarBg/HeightBarFill
@onready var time_value: Label = $MainContainer/TopBar/TimePanel/TimeVBox/TimeValue
@onready var time_bar: ProgressBar = $MainContainer/TopBar/TimePanel/TimeVBox/TimeBarBg/TimeBarFill
@onready var cp_value: Label = $MainContainer/TopBar/CheckpointPanel/CPVBox/CPValue
@onready var cp_bar: ProgressBar = $MainContainer/TopBar/CheckpointPanel/CPVBox/CPBarBg/CPBarFill
@onready var speed_label: Label = $MainContainer/BottomInfo/SpeedLabel

var start_time: float = 0
var paused: bool = false
var max_height: float = 0

func _ready() -> void:
	start_time = Time.get_ticks_msec() / 1000.0
	height_bar.max_value = 1000
	time_bar.max_value = 3600
	cp_bar.max_value = 100

func update_height(height: float) -> void:
	max_height = max(max_height, height)
	height_value.text = "%d m" % max(height, 0)
	height_bar.value = clamp(height, 0, height_bar.max_value)

func update_time(elapsed: float) -> void:
	var mins = int(elapsed / 60)
	var secs = int(fmod(elapsed, 60.0))
	var ms = int((elapsed - int(elapsed)) * 100)
	time_value.text = "%02d:%02d.%02d" % [mins, secs, ms]
	time_bar.value = clamp(elapsed, 0, time_bar.max_value)

func update_checkpoints(count: int) -> void:
	cp_value.text = str(count)
	cp_bar.value = clamp(count, 0, cp_bar.max_value)

func update_speed(speed: float) -> void:
	speed_label.text = "Speed: %.1f m/s" % speed

func reset() -> void:
	start_time = Time.get_ticks_msec() / 1000.0
	max_height = 0
	height_value.text = "0 m"
	height_bar.value = 0
	time_value.text = "00:00.00"
	time_bar.value = 0
	cp_value.text = "0"
	cp_bar.value = 0
	speed_label.text = "Speed: 0 m/s"

func set_paused(pause: bool) -> void:
	paused = pause