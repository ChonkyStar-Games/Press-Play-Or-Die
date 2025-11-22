extends Node2D

@export var radius: float = 20.0
@export var min_radius: float = 5.0  # Minimum radius the button can shrink to
@export var base_growth_rate: float = 0.05  # Base multiplier for growth calculation
@export var click_power: float = 25  # Force applied against growth when clicking
@export var click_power_decay_rate: float = 0.997  # Click power multiplier per second (< 1 means weakening)
@export var click_decay: float = 75  # How fast the click force decays
@export var max_shrink_velocity: float = 150.0  # Maximum shrink velocity to prevent spam clicking abuse
@export var min_grow_radius_rate: float = 40;

var shrink_velocity: float = 0.0  # Current counter-force against growth
var growth_rate: float = 0.0  # Calculated based on radius

# Particle effects
@onready var sparks_template: CPUParticles2D = $CPUParticles2D
var active_spark_groups = []  # Track active spark particle groups

# Score keeper
@onready var score_keeper: Node2D = $"../ScoreKeeper"

# Jelly wobble physics
const NUM_POINTS = 64  # Number of points around the circle
const SPRING_STIFFNESS = 40.0  # Reduced to allow waves to travel
const SPRING_DAMPING = 1.5  # Low damping for persistent waves
const BASE_RIPPLE_INTENSITY = 0.15  # Base ripple as fraction of radius
const RIPPLE_VELOCITY_SCALE = 0.005  # How much shrink_velocity amplifies ripples
const WAVE_PROPAGATION = 4.0  # High value for strong wave propagation around circumference

var point_offsets = []  # Displacement from ideal position
var point_velocities = []  # Velocity of each point

func _ready():
	var viewport_size = get_viewport_rect().size
	global_position = viewport_size / 2
	
	# Initialize wobble physics arrays
	for i in range(NUM_POINTS):
		point_offsets.append(0.0)
		point_velocities.append(0.0)
	
	# Configure spark particles
	setup_sparks()

func setup_sparks():
	# Create elongated line texture for sparks (vertical)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.5, Color.WHITE)
	gradient.add_point(1.0, Color(1, 1, 1, 0))  # Fade at edges
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.5, 0)
	gradient_texture.fill_to = Vector2(0.5, 1)
	gradient_texture.width = 4
	gradient_texture.height = 32
	
	# Configure the spark particle effect template
	sparks_template.texture = gradient_texture
	sparks_template.emitting = false
	sparks_template.one_shot = true
	sparks_template.explosiveness = 1.0
	sparks_template.amount = 1
	sparks_template.lifetime = 1.2  # Live longer
	
	# Emission shape - small sphere
	sparks_template.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks_template.emission_sphere_radius = 5.0
	
	# Movement - will be set per-instance to point away from button
	sparks_template.direction = Vector2(1, 0)  # Default outward, will rotate
	sparks_template.spread = 45.0  # Only spread in a cone away from button
	sparks_template.initial_velocity_min = 100.0
	sparks_template.initial_velocity_max = 280.0
	
	# Slow down over time (negative linear accel acts as drag)
	sparks_template.gravity = Vector2.ZERO
	sparks_template.linear_accel_min = -80.0  # Deceleration
	sparks_template.linear_accel_max = -120.0
	
	# Orient particles in direction of motion (makes lines point the right way)
	sparks_template.particle_flag_align_y = true
	
	# Size and fade - scale the line particles
	sparks_template.scale_amount_min = 0.5
	sparks_template.scale_amount_max = 0.75
	
	# Create fade curve
	var fade_curve = Curve.new()
	fade_curve.add_point(Vector2(0, 1))    # Start at full size
	fade_curve.add_point(Vector2(0.7, 0.8))  # Maintain size longer
	fade_curve.add_point(Vector2(1, 0))    # Fade to nothing
	sparks_template.scale_amount_curve = fade_curve
	
	# Color - yellow to orange sparks that fade out
	sparks_template.color = Color.YELLOW
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color.YELLOW)              # Start yellow
	color_ramp.add_point(0.3, Color(1, 0.8, 0, 1))       # Yellow-orange
	color_ramp.add_point(0.6, Color.ORANGE)              # Orange
	color_ramp.add_point(1.0, Color(1, 0.5, 0, 0))       # Fade to transparent orange
	sparks_template.color_ramp = color_ramp
	
	# Hide the template
	sparks_template.visible = false

func spawn_sparks_at_circumference(click_angle: float, distance_from_center: float):
	# Limit number of concurrent spark groups to prevent buildup from rapid clicking
	const MAX_SPARK_GROUPS = 10
	while active_spark_groups.size() >= MAX_SPARK_GROUPS:
		# Remove oldest spark group
		var old_group = active_spark_groups.pop_front()
		for spark in old_group:
			if is_instance_valid(spark):
				spark.queue_free()
	
	# Calculate angular spread based on distance from center
	# At center (0.0): spread across most of circumference (240 degrees)
	# At edge (1.0): very focused spread (30 degrees)
	var max_spread = lerp(deg_to_rad(360), deg_to_rad(30), distance_from_center * distance_from_center)
	
	# Number of spark emitters to spawn (more when closer to center)
	var num_emitters = int(lerp(16, 2, distance_from_center * distance_from_center))
	
	# Collect all spawned sparks for batch cleanup
	var spawned_sparks = []
	
	# Spawn multiple spark emitters around the click angle
	for i in range(num_emitters):
		# Distribute emitters within the spread range
		var angle_offset = 0.0
		if num_emitters > 1:
			# Spread them evenly within the angular range
			var t = float(i) / (num_emitters - 1)  # 0 to 1
			angle_offset = (t - 0.5) * max_spread  # Center around click_angle
		
		var spawn_angle = click_angle + angle_offset
		
		# Create a new spark instance
		var new_sparks = sparks_template.duplicate()
		add_child(new_sparks)
		new_sparks.visible = true
		
		# Find the actual wobbled radius at this spawn angle
		var normalized_angle = fmod(spawn_angle + TAU, TAU)
		var point_index = (normalized_angle / TAU) * NUM_POINTS
		
		# Get the closest point's offset (or interpolate between two points)
		var index_floor = int(floor(point_index)) % NUM_POINTS
		var index_ceil = int(ceil(point_index)) % NUM_POINTS
		var lerp_factor = point_index - floor(point_index)
		
		# Interpolate between the two nearest wobble offsets
		var offset_at_angle = lerp(point_offsets[index_floor], point_offsets[index_ceil], lerp_factor)
		var actual_radius = radius + offset_at_angle
		
		# Position at the actual wobbled circumference
		var circumference_pos = Vector2(cos(spawn_angle), sin(spawn_angle)) * actual_radius
		new_sparks.position = circumference_pos
		
		# Rotate the particle emission to point away from button center
		new_sparks.direction = Vector2(cos(spawn_angle), sin(spawn_angle))
		
		# Emit the particles
		new_sparks.emitting = true
		
		spawned_sparks.append(new_sparks)
	
	# Track this group
	active_spark_groups.append(spawned_sparks)
	
	# Single cleanup timer for all sparks from this click
	await get_tree().create_timer(sparks_template.lifetime + 0.1).timeout
	
	# Remove from active tracking and cleanup
	active_spark_groups.erase(spawned_sparks)
	for spark in spawned_sparks:
		if is_instance_valid(spark):
			spark.queue_free()

func _process(delta):
	# Calculate growth rate based on button size (n log n curve)
	# Using radius * log(radius + 1) to avoid log(0), scaled by base_growth_rate
	growth_rate = base_growth_rate * max(min_grow_radius_rate, radius) * log(radius + 1)
	
	# Apply net growth (growth rate minus shrink velocity from clicks)
	var net_growth = growth_rate - shrink_velocity
	var new_radius = radius + net_growth * delta
	
	# If we would go below minimum, clamp and consume the excess shrink velocity
	if new_radius < min_radius:
		# Calculate how much shrink velocity was "used up" hitting the floor
		var shrink_amount = radius - min_radius
		var shrink_velocity_used = shrink_amount / delta if delta > 0 else 0
		# Reduce shrink velocity by the amount consumed (prevents accumulation at minimum)
		shrink_velocity = max(0, shrink_velocity - shrink_velocity_used)
		radius = min_radius
	else:
		radius = new_radius
	
	# Weaken click power over time (exponential decay)
	click_power *= pow(click_power_decay_rate, delta)
	
	# Decay the shrink velocity over time
	shrink_velocity = max(0, shrink_velocity - click_decay * delta)
	
	# Create temporary array for new offsets to allow wave propagation
	var new_velocities = point_velocities.duplicate()
	
	# Update wobble physics for each point
	for i in range(NUM_POINTS):
		# Get neighboring points (wrapping around)
		var prev = (i - 1 + NUM_POINTS) % NUM_POINTS
		var next = (i + 1) % NUM_POINTS
		
		# Spring force pulling back to original position
		var force = -SPRING_STIFFNESS * point_offsets[i]
		# Damping to reduce oscillation
		force -= SPRING_DAMPING * point_velocities[i]
		
		# Wave propagation from neighbors
		var neighbor_influence = (point_offsets[prev] + point_offsets[next]) * 0.5 - point_offsets[i]
		force += neighbor_influence * WAVE_PROPAGATION * SPRING_STIFFNESS
		
		# Update velocity and position
		new_velocities[i] += force * delta
	
	# Apply new velocities and update positions
	for i in range(NUM_POINTS):
		point_velocities[i] = new_velocities[i]
		point_offsets[i] += point_velocities[i] * delta
	
	queue_redraw()

func _draw():
	# Skip drawing if radius is too small to prevent triangulation errors
	if radius < 1.0:
		return
	
	# Draw wobbly circle as a polygon
	var points = PackedVector2Array()
	for i in range(NUM_POINTS):
		var angle = (float(i) / NUM_POINTS) * TAU
		# Ensure current_radius stays positive even with wobble offsets
		var current_radius = max(1.0, radius + point_offsets[i])
		var point = Vector2(cos(angle), sin(angle)) * current_radius
		points.append(point)
	
	draw_colored_polygon(points, Color.WHITE)
	
	# Draw "PLAY" text in the center, scaled to fit the circle
	var font = ThemeDB.fallback_font
	var text = "PLAY"
	var font_size = radius * 0.4  # Scale font size relative to radius
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(-text_size.x / 2, text_size.y / 4)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)

func _input(event):
	var is_click = event is InputEventMouseButton and event.pressed
	var is_tap = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_tap:
		var pos = get_global_mouse_position() - global_position
		if pos.length() <= radius:
			# Apply click force as a counter-velocity against growth
			shrink_velocity += click_power
			# Cap shrink velocity to prevent spam clicking abuse
			shrink_velocity = min(shrink_velocity, max_shrink_velocity)
			
			# Apply jelly wobble at click position
			var click_angle = atan2(pos.y, pos.x)
			
			# Calculate how close the click is to the center (0.0 = center, 1.0 = edge)
			var distance_from_center = pos.length() / radius
			
			# Calculate actual wobbled radius at this angle for accurate circumference position
			var normalized_angle = fmod(click_angle + TAU, TAU)
			var point_index = (normalized_angle / TAU) * NUM_POINTS
			var index_floor = int(floor(point_index)) % NUM_POINTS
			var index_ceil = int(ceil(point_index)) % NUM_POINTS
			var lerp_factor = point_index - floor(point_index)
			var offset_at_angle = lerp(point_offsets[index_floor], point_offsets[index_ceil], lerp_factor)
			var actual_radius = radius + offset_at_angle
			
			# Position at the actual wobbled circumference for score display
			var circumference_pos = Vector2(cos(click_angle), sin(click_angle)) * actual_radius
			var world_circumference_pos = global_position + circumference_pos
			
			# Calculate score based on button size (quadratic growth, slower scaling)
			# Small button (~5 radius) = 1 point, large button (100 radius) = 10 points
			var points = max(1, int(radius * radius / 1000.0))
			
			# Add score and show floating number
			if score_keeper:
				score_keeper.add_score(points, world_circumference_pos, click_angle, actual_radius)
			
			# Emit sparks at the circumference
			spawn_sparks_at_circumference(click_angle, distance_from_center)
			
			# Calculate ripple intensity based on shrink_velocity and normalized by radius
			# This makes ripples scale-consistent and more intense when clicking rapidly
			var ripple_multiplier = 1.0 + (shrink_velocity * RIPPLE_VELOCITY_SCALE)
			var ripple_force = radius * BASE_RIPPLE_INTENSITY * ripple_multiplier
			
			# Make the ripple spread wider near the center, narrower near the edge
			# At center: narrow multiplier = 1.0 (wide spread)
			# At edge: narrow multiplier = 12.0 (very focused)
			var narrow_multiplier = 1.0 + (distance_from_center * distance_from_center * 11.0)
			
			# Create a sharp, localized disturbance that will send waves around the circle
			for i in range(NUM_POINTS):
				var point_angle = (float(i) / NUM_POINTS) * TAU
				var angle_diff = abs(angle_difference(point_angle, click_angle))
				
				# Gaussian width varies based on click position
				var influence = exp(-angle_diff * angle_diff * narrow_multiplier)
				
				# Create initial displacement and velocity for wave propagation
				# Scaled by radius for consistent visual effect at any size
				point_offsets[i] -= ripple_force * influence
				# Give a strong velocity kick to launch the wave
				point_velocities[i] -= ripple_force * 5.0 * influence
