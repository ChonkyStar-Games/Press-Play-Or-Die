extends Node2D

@export var grid_spacing: float = 40.0
@export var line_width: float = 3.0
@export var normal_color: Color = Color(0.2, 0.4, 1.0, 0.8) # Blue
@export var warped_color: Color = Color(1.0, 0.2, 0.2, 0.9) # Red
@export var warp_strength: float = 0.8 # How much the grid warps
@export var warp_radius_multiplier: float = 3.0 # Warp radius relative to button radius
@export var grid_extension: float = 0.5 # REDUCED: How many viewport sizes to extend beyond viewport
@export var fade_radius_multiplier: float = 4.0 # Fade distance as multiple of button radius
@export var press_play_node: Node2D

# Cache for tracking when redraw is needed
var last_button_pos: Vector2 = Vector2.ZERO
var last_button_radius: float = 0.0
var last_viewport_size: Vector2 = Vector2.ZERO

func _process(_delta):
	# Only redraw when something actually changes
	if not press_play_node:
		return
	
	var current_pos = press_play_node.global_position
	var current_radius = press_play_node.radius
	var current_viewport = get_viewport_rect().size
	
	# Check if anything changed (with small epsilon for floating point comparison)
	if (current_pos.distance_to(last_button_pos) > 0.1 or
		abs(current_radius - last_button_radius) > 0.1 or
		current_viewport != last_viewport_size):
		last_button_pos = current_pos
		last_button_radius = current_radius
		last_viewport_size = current_viewport
		queue_redraw()

func _draw():
	var viewport_size = get_viewport_rect().size
	
	if not press_play_node:
		return
	
	var button_pos = press_play_node.global_position
	var button_radius = press_play_node.radius
	var warp_radius = button_radius * warp_radius_multiplier
	var fade_distance = button_radius * fade_radius_multiplier
	
	# Calculate extended grid bounds
	var extension_x = viewport_size.x * grid_extension
	var extension_y = viewport_size.y * grid_extension
	var min_x = - extension_x
	var max_x = viewport_size.x + extension_x
	var min_y = - extension_y
	var max_y = viewport_size.y + extension_y
	
	# OPTIMIZED: Use larger step size (0.5 instead of 0.2)
	var step = grid_spacing * 0.5
	
	# Draw vertical lines
	var x = min_x
	while x <= max_x:
		var points = PackedVector2Array()
		var distances = PackedFloat32Array() # OPTIMIZED: Cache distances
		var warp_factors = PackedFloat32Array() # OPTIMIZED: Use packed array
		var y = min_y
		
		while y <= max_y:
			var point = Vector2(x, y)
			var result = warp_point_with_factor(point, button_pos, button_radius, warp_radius)
			points.append(result.point)
			distances.append(result.distance) # Cache distance
			warp_factors.append(result.warp_factor)
			y += step
		
		# Draw the line segments (skip segments inside the button)
		for i in range(len(points) - 1):
			# OPTIMIZED: Use cached distances instead of recalculating
			if distances[i] > button_radius and distances[i + 1] > button_radius:
				# Calculate color based on average warp factor
				var avg_warp = (warp_factors[i] + warp_factors[i + 1]) * 0.5
				var color = normal_color.lerp(warped_color, avg_warp)
				
				# Apply fade to black based on distance from circle circumference
				var avg_distance = (distances[i] + distances[i + 1]) * 0.5
				# Start fade from button edge, not center
				var distance_from_edge = max(0.0, avg_distance - button_radius)
				var fade_factor = clamp(distance_from_edge / fade_distance, 0.0, 1.0)
				# Apply very gradual power curve for ultra-smooth fade
				fade_factor = pow(fade_factor, 0.2)
				color = color.lerp(Color.BLACK, fade_factor)
				
				draw_line(points[i], points[i + 1], color, line_width)
		
		x += grid_spacing
	
	# Draw horizontal lines
	var y_pos = min_y
	while y_pos <= max_y:
		var points = PackedVector2Array()
		var distances = PackedFloat32Array() # OPTIMIZED: Cache distances
		var warp_factors = PackedFloat32Array() # OPTIMIZED: Use packed array
		var x2 = min_x
		
		while x2 <= max_x:
			var point = Vector2(x2, y_pos)
			var result = warp_point_with_factor(point, button_pos, button_radius, warp_radius)
			points.append(result.point)
			distances.append(result.distance) # Cache distance
			warp_factors.append(result.warp_factor)
			x2 += step
		
		# Draw the line segments (skip segments inside the button)
		for i in range(len(points) - 1):
			# OPTIMIZED: Use cached distances instead of recalculating
			if distances[i] > button_radius and distances[i + 1] > button_radius:
				# Calculate color based on average warp factor
				var avg_warp = (warp_factors[i] + warp_factors[i + 1]) * 0.5
				var color = normal_color.lerp(warped_color, avg_warp)
				
				# Apply fade to black based on distance from circle circumference
				var avg_distance = (distances[i] + distances[i + 1]) * 0.5
				# Start fade from button edge, not center
				var distance_from_edge = max(0.0, avg_distance - button_radius)
				var fade_factor = clamp(distance_from_edge / fade_distance, 0.0, 1.0)
				# Apply very gradual power curve for ultra-smooth fade
				fade_factor = pow(fade_factor, 0.2)
				color = color.lerp(Color.BLACK, fade_factor)
				
				draw_line(points[i], points[i + 1], color, line_width)
		
		y_pos += grid_spacing

func warp_point_with_factor(point: Vector2, center: Vector2, button_radius: float, warp_radius: float) -> Dictionary:
	var offset = point - center
	var distance = offset.length()
	
	# Don't warp if we're too far away
	if distance > warp_radius:
		return {"point": point, "distance": distance, "warp_factor": 0.0}
	
	# Calculate warp factor (stronger closer to center, scales with button size)
	var normalized_dist = distance / warp_radius
	
	# Inverse square falloff like gravity, but smoothed
	var warp_factor = 1.0 - normalized_dist
	warp_factor = warp_factor * warp_factor # Square for stronger effect near center
	
	# Pull points toward the center (black hole effect)
	# The pull strength increases with button radius
	var pull_strength = warp_strength * button_radius * warp_factor
	
	# Calculate how much to pull the point toward center
	var pull_direction = - offset.normalized()
	var warped_point = point + pull_direction * pull_strength
	
	return {"point": warped_point, "distance": distance, "warp_factor": warp_factor}
