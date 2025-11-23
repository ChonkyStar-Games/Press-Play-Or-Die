extends Node2D

# Reference to the play button
@onready var press_play: Node2D = %PlayButton

# Track if we're currently processing to prevent infinite loops
var is_processing_duplicate: bool = false

func _ready():
	# Set this node to process input before press_play
	process_priority = -1

func _input(event):
	# Skip if we're already processing a duplicate to prevent infinite loops
	if is_processing_duplicate:
		return
	
	# Only process clicks/taps that are pressed
	var is_click = event is InputEventMouseButton and event.pressed
	var is_tap = event is InputEventScreenTouch and event.pressed
	
	if not (is_click or is_tap):
		return
	
	if not press_play:
		return
	
	# Check if the click is within the button's radius
	var click_pos = event.position if is_click else event.position
	var button_pos = press_play.global_position
	var distance = (click_pos - button_pos).length()
	
	# If click is on the button, trigger a second click directly after a delay
	if distance <= press_play.radius:
		# Trigger the duplicate click asynchronously
		trigger_duplicate_click(event, is_click)

func trigger_duplicate_click(original_event, is_click: bool):
	"""Trigger a second click after a delay"""
	# Wait 50ms to make the stutter effect visible
	await get_tree().create_timer(0.05).timeout
	
	# Set flag to prevent infinite loops
	is_processing_duplicate = true
	
	# Create a duplicate event for the second click
	var duplicate_event
	if is_click:
		duplicate_event = InputEventMouseButton.new()
		duplicate_event.button_index = original_event.button_index
		duplicate_event.pressed = true
		duplicate_event.position = original_event.position
		duplicate_event.global_position = original_event.global_position
	else:  # is_tap
		duplicate_event = InputEventScreenTouch.new()
		duplicate_event.pressed = true
		duplicate_event.position = original_event.position
		duplicate_event.index = original_event.index
	
	# Call press_play's input handler directly instead of injecting into global input
	if is_instance_valid(press_play):
		press_play._input(duplicate_event)
	
	# Clear flag after processing
	is_processing_duplicate = false
