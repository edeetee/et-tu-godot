extends RigidBody3D

@export var follow_mouse: bool = false
@export var mouse_force: float = 100.0
@export var random_impulses: bool = false
@export var impulse_min_time: float = 1.0
@export var impulse_max_time: float = 3.0
@export var impulse_strength: float = 5.0
@export var noise_motion: bool = false
@export var noise_speed: float = 1.0
@export var noise_strength: float = 10.0
@export_range(0.1, 10.0) var noise_scale: float = 1.0

@onready var light = $OmniLight3D
var impulse_timer: float = 0.0
var noise = FastNoiseLite.new()
var noise_position = Vector3.ZERO

func _ready() -> void:
	if random_impulses:
		impulse_timer = randf_range(impulse_min_time, impulse_max_time)
	
	# Initialize noise for continuous motion
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 2
	
	# Start with a random position in the noise field
	noise_position = Vector3(randf() * 1000, randf() * 1000, randf() * 1000)

func _physics_process(delta: float) -> void:
	# Follow mouse functionality
	if follow_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var camera = get_viewport().get_camera_3d()
		if camera:
			var mouse_pos = get_viewport().get_mouse_position()
			
			# Create a plane at the light's height (perpendicular to the global Y axis)
			var plane = Plane(Vector3.UP, global_position.y)
			
			# Project a ray from the mouse position into the 3D world
			var from = camera.project_ray_origin(mouse_pos)
			var dir = camera.project_ray_normal(mouse_pos)
			
			# Find where the ray intersects the horizontal plane
			var intersection = plane.intersects_ray(from, dir)
			
			if intersection:
				# Calculate direction to the intersection point (only on X/Z plane)
				var target_pos = intersection
				var direction = (target_pos - global_position)
				direction.y = 0 # Restrict to X/Z plane movement
				
				if direction.length() > 0.1: # Only apply force if there's meaningful distance
					direction = direction.normalized()
					apply_central_force(direction * mouse_force)

	# Random impulses
	if random_impulses:
		impulse_timer -= delta
		if impulse_timer <= 0:
			var random_direction = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			apply_central_impulse(random_direction * impulse_strength)
			impulse_timer = randf_range(impulse_min_time, impulse_max_time)
	
	# Continuous noise-based motion
	if noise_motion:
		# Update position in noise field
		noise_position.x += delta * noise_speed
		noise_position.y += delta * noise_speed * 0.7 # Different rates for more organic motion
		noise_position.z += delta * noise_speed * 0.5
		
		# Calculate force direction from noise
		var force = Vector3(
			noise.get_noise_3d(noise_position.x * noise_scale, 0, 0),
			noise.get_noise_3d(0, noise_position.y * noise_scale, 0),
			noise.get_noise_3d(0, 0, noise_position.z * noise_scale)
		)
		
		# Apply force
		apply_central_force(force * noise_strength)