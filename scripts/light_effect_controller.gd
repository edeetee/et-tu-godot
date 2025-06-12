extends OmniLight3D

@export var pulse_enabled: bool = true
@export var pulse_speed: float = 2.0
@export var pulse_intensity: float = 2.0
@export var pulse_pow: float = 1.0
@export var pulse_speed_random_offset: float = 0.5

@export var color_cycle: bool = false
@export var color_cycle_speed: float = 0.5
@export var color_saturation: float = 1.0
@export var color_value: float = 1.0

@export var random_offset: float = 1.0

var base_energy: float
var time: float = 0.0
var offset: float

func _ready() -> void:
	base_energy = light_energy
	offset = randf_range(-random_offset, random_offset)
	pulse_speed *= 1.0 + randf_range(-pulse_speed_random_offset, pulse_speed_random_offset)

func _process(delta: float) -> void:
	time += delta
	
	# Pulsing light effect
	if pulse_enabled and pulse_intensity > 0:
		var sin_val = sin((time + offset) * pulse_speed)
		var pow_val = pow(abs(sin_val), pulse_pow) * sign(sin_val)
		light_energy = base_energy + pow_val * pulse_intensity * base_energy;
	
	# Color cycling effect
	if color_cycle:
		var hue = fmod((time + offset) * color_cycle_speed, 1.0)
		light_color = Color.from_hsv(hue, color_saturation, color_value)