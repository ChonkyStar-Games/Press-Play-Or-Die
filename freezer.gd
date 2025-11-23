extends Node2D

@export var freeze_interval: float = 5.0  # How often to freeze (seconds)
@export var freeze_duration: float = 2.0   # How long the freeze lasts (seconds)

@onready var press_play: Node2D = %PlayButton

var time_until_freeze: float = 0.0

func _ready():
	time_until_freeze = freeze_interval

func _process(delta):
	time_until_freeze -= delta
	
	if time_until_freeze <= 0:
		# Trigger freeze
		freeze_button()
		# Reset timer
		time_until_freeze = freeze_interval

func freeze_button():
	if not press_play:
		return
	
	# Apply freeze logic
	if press_play.has_method("set_frozen"):
		press_play.set_frozen(true)
	
	# Apply ice visual effect
	if press_play.has_method("add_visual_effect"):
		press_play.add_visual_effect("ice")
	
	# Unfreeze after duration
	await get_tree().create_timer(freeze_duration).timeout
	
	if not is_instance_valid(press_play):
		return
	
	# Remove freeze logic
	if press_play.has_method("set_frozen"):
		press_play.set_frozen(false)
	
	# Remove ice visual effect
	if press_play.has_method("remove_visual_effect"):
		press_play.remove_visual_effect("ice")
