extends Node2D

@export var points_per_click: int = 10
@export var float_distance: float = 150.0 # How far the number floats
@export var float_duration: float = 1.2 # Matches spark lifetime
@export var base_initial_font_size: int = 24
@export var base_final_font_size: int = 40 # Grows as it floats
@export var font_scale_factor: float = 0.5 # How much larger font gets per point

var score: int = 0
var active_labels = [] # Track active floating labels
var score_display: Label = null # UI label for total score
var timer_display: Label = null # UI label for elapsed time
var elapsed_time: float = 0.0 # Time since game started

func _ready():
	setup_score_display()
	setup_timer_display()

func _process(delta):
	# Update elapsed time
	elapsed_time += delta
	update_timer_display()

func setup_score_display():
	"""Create the score display in the top-left corner"""
	score_display = Label.new()
	score_display.text = "$0"
	score_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_display.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	# Set minimum size to prevent clipping
	score_display.custom_minimum_size = Vector2(200, 60)
	
	# Style the label
	score_display.add_theme_font_size_override("font_size", 36)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 6)
	
	# Position in top-left with padding
	score_display.position = Vector2(20, 20)
	
	# Add to the CanvasLayer so it's drawn on top of the game world
	var canvas_layer = get_node("%CanvasLayer")
	canvas_layer.add_child(score_display)

func add_score(amount: int, world_position: Vector2, angle_from_center: float, button_radius: float):
	"""Add points and spawn a floating number at the given position"""
	score += amount
	update_score_display()
	spawn_floating_number(amount, world_position, angle_from_center, button_radius)

func update_score_display():
	"""Update the score display label"""
	if score_display:
		score_display.text = "$%d" % score

func setup_timer_display():
	"""Create the timer display in the top-right corner"""
	timer_display = Label.new()
	timer_display.text = "0:00"
	timer_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_display.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	# Set minimum size to prevent clipping
	timer_display.custom_minimum_size = Vector2(150, 60)
	
	# Style the label
	timer_display.add_theme_font_size_override("font_size", 36)
	timer_display.add_theme_color_override("font_color", Color.WHITE)
	timer_display.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_display.add_theme_constant_override("outline_size", 6)
	
	# Position in top-right with padding
	var viewport_size = get_viewport_rect().size
	timer_display.position = Vector2(viewport_size.x - 150, 20)
	
	# Add to the CanvasLayer so it's drawn on top of the game world
	var canvas_layer = get_node("%CanvasLayer")
	canvas_layer.add_child(timer_display)

func update_timer_display():
	"""Update the timer display with formatted time"""
	if timer_display:
		var total_seconds = int(elapsed_time)
		@warning_ignore("integer_division")
		var minutes = total_seconds / 60
		var seconds = total_seconds % 60
		timer_display.text = "%d:%02d" % [minutes, seconds]

func spawn_floating_number(amount: int, world_position: Vector2, angle_from_center: float, _button_radius: float):
	"""Create a floating number that moves away from the button center"""
	# Limit active labels to prevent buildup
	const MAX_LABELS = 20
	while active_labels.size() >= MAX_LABELS:
		var old_label = active_labels.pop_front()
		if is_instance_valid(old_label):
			old_label.queue_free()
	
	# Calculate font sizes based on score amount
	# Use logarithmic scaling so it doesn't get too crazy
	var size_multiplier = 1.0 + log(float(amount) + 1) * font_scale_factor
	var initial_font_size = int(base_initial_font_size * size_multiplier)
	var final_font_size = int(base_final_font_size * size_multiplier)
	
	# Create the label
	var label = Label.new()
	label.text = "$%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Style the label
	label.add_theme_font_size_override("font_size", initial_font_size)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	# Position at the circumference edge
	var direction = Vector2(cos(angle_from_center), sin(angle_from_center))
	var spawn_pos = world_position
	label.global_position = spawn_pos
	
	# Add to scene
	get_tree().root.add_child(label)
	active_labels.append(label)
	
	# Animate the label with scaled font sizes
	animate_floating_number(label, direction, spawn_pos, initial_font_size, final_font_size)

func animate_floating_number(label: Label, direction: Vector2, start_pos: Vector2, initial_font_size: int, final_font_size: int):
	"""Animate the floating number to move, grow, and fade using Tween for better performance"""
	# Create a tween for smooth animations
	var tween = create_tween()
	tween.set_parallel(true) # Run all animations in parallel
	
	# Animate position
	var end_pos = start_pos + direction * float_distance
	tween.tween_property(label, "global_position", end_pos, float_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Animate modulate for fade (much faster than color override)
	# Start fully opaque, fade at 60% mark
	tween.tween_property(label, "modulate:a", 1.0, float_duration * 0.6)
	tween.tween_property(label, "modulate:a", 0.0, float_duration * 0.4).set_delay(float_duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Animate color shift from yellow to orange (starts at 30% mark)
	tween.tween_method(func(color: Color):
		label.add_theme_color_override("font_color", color),
		Color.YELLOW,
		Color.ORANGE,
		float_duration * 0.7
	).set_delay(float_duration * 0.3)

	# Cleanup after animation completes
	await tween.finished
	active_labels.erase(label)
	if is_instance_valid(label):
		label.queue_free()

# Easing functions
func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_quad(t: float) -> float:
	return t * t
