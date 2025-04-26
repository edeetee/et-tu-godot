extends RigidBody3D

@export var pulse_speed: float = 2.0
@export var pulse_intensity: float = 2.0
@export var color_cycle: bool = false
@export var color_cycle_speed: float = 0.5
@export var follow_mouse: bool = false
@export var mouse_force: float = 100.0
@export var random_impulses: bool = false
@export var impulse_min_time: float = 1.0
@export var impulse_max_time: float = 3.0
@export var impulse_strength: float = 5.0

@onready var light = $OmniLight3D
var base_energy: float
var time: float = 0.0
var impulse_timer: float = 0.0

func _ready() -> void:
	base_energy = light.light_energy
	if random_impulses:
		impulse_timer = randf_range(impulse_min_time, impulse_max_time)

func _process(delta: float) -> void:
	time += delta
	
	# Pulsing light effect
	if pulse_intensity > 0:
		light.light_energy = base_energy + sin(time * pulse_speed) * pulse_intensity
	
	# Color cycling effect
	if color_cycle:
		var hue = fmod(time * color_cycle_speed, 1.0)
		light.light_color = Color.from_hsv(hue, 1.0, 1.0)

func _physics_process(delta: float) -> void:
	# Follow mouse functionality
	if follow_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var camera = get_viewport().get_camera_3d()
		if camera:
			var mouse_pos = get_viewport().get_mouse_position()
			var from = camera.project_ray_origin(mouse_pos)
			var to = from + camera.project_ray_normal(mouse_pos) * 100
			
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)
			
			if result:
				var target_pos = result.position
				var direction = (target_pos - global_position).normalized()
				apply_central_force(direction * mouse_force)
	
	# Random impulses
	if random_impulses:
		impulse_timer -= delta
		if impulse_timer <= 0:
			var random_direction = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			apply_central_impulse(random_direction * impulse_strength)
			impulse_timer = randf_range(impulse_min_time, impulse_max_time)