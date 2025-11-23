extends Node2D

# State
enum EdgeState { GREEN, RED }
var current_state: EdgeState = EdgeState.GREEN
var state_timer: float = 0.0
var state_duration: float = 2.0  # Switch every 2 seconds

# Label for emoji display
var emoji_label: Label

# Reference to score keeper
var score_keeper: Node2D = null

func _ready():
	# Position at bottom middle of screen
	var viewport_size = get_viewport_rect().size
	global_position = Vector2(viewport_size.x / 2, viewport_size.y - 80)
	
	# Create and configure emoji label
	emoji_label = Label.new()
	emoji_label.add_theme_font_size_override("font_size", 64)
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.position = Vector2(-32, -32)  # Center the emoji
	add_child(emoji_label)
	
	# Get reference to score keeper and add initial multiplier
	score_keeper = get_node_or_null("../../ScoreKeeper")
	if score_keeper:
		score_keeper.multiplier += get_score_multiplier()
	
	# Set initial emoji
	update_emoji()

func _process(delta):
	# Update timer
	state_timer += delta
	
	# Check if we need to switch states
	if state_timer >= state_duration:
		state_timer = 0.0
		toggle_state()

func toggle_state():
	"""Switch between green and red states"""
	# Remove old multiplier contribution
	if score_keeper:
		score_keeper.multiplier -= get_score_multiplier()
	
	# Switch state
	if current_state == EdgeState.GREEN:
		current_state = EdgeState.RED
	else:
		current_state = EdgeState.GREEN
	
	# Add new multiplier contribution
	if score_keeper:
		score_keeper.multiplier += get_score_multiplier()
	
	update_emoji()

func update_emoji():
	"""Update the emoji based on current state"""
	if emoji_label:
		if current_state == EdgeState.GREEN:
			emoji_label.text = "👍"
		else:
			emoji_label.text = "👎"

func get_score_multiplier() -> float:
	"""Returns the score multiplier based on current state"""
	if current_state == EdgeState.GREEN:
		return 4.0
	else:
		return -4.0

func is_green() -> bool:
	return current_state == EdgeState.GREEN

func is_red() -> bool:
	return current_state == EdgeState.RED
