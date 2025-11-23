extends Node2D

# Reference to the play button
@onready var press_play: Node2D = %PlayButton

# Click tracking
var click_count: int = 0
var BONUS_CLICK: int = 3  # Every 3rd click gets bonus

# Label for display
var count_label: Label

# Reference to score keeper
var score_keeper: Node2D = null

func _ready():
	# Position at bottom middle of screen (offset from other powerups)
	var viewport_size = get_viewport_rect().size
	global_position = Vector2(viewport_size.x / 2, viewport_size.y - 160)
	
	# Create and configure count label
	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 48)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.position = Vector2(-24, -24)  # Center the text
	add_child(count_label)
	
	# Get reference to score keeper and add initial multiplier
	score_keeper = get_node_or_null("../../ScoreKeeper")
	if score_keeper:
		score_keeper.multiplier += get_score_multiplier()
	
	# Set initial display
	update_display()
	
	# Set this node to process input after press_play to catch successful clicks
	process_priority = 1

func _input(event):
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
	
	# If click is on the button, increment counter
	if distance <= press_play.radius:
		# Remove old multiplier contribution
		if score_keeper:
			score_keeper.multiplier -= get_score_multiplier()
		
		# Update click count
		click_count += 1
		if click_count >= BONUS_CLICK:
			click_count = 0
		
		# Add new multiplier contribution
		if score_keeper:
			score_keeper.multiplier += get_score_multiplier()
		
		update_display()

func update_display():
	"""Update the display based on current click count"""
	if count_label:
		match click_count:
			0:
				count_label.text = "1️⃣"
			1:
				count_label.text = "2️⃣"
			2:
				count_label.text = "🎉"  # Next click is bonus!

func get_score_multiplier() -> float:
	"""Returns 2x multiplier when on the bonus click (click_count == 2), otherwise 1x"""
	if click_count == 2:
		return 1.0
	else:
		return 0.0
