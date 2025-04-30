extends OmniLight3D

@export var pulse_enabled: bool = true
@export var pulse_speed: float = 2.0
@export var pulse_intensity: float = 2.0
@export var color_cycle: bool = false
@export var color_cycle_speed: float = 0.5

var base_energy: float
var time: float = 0.0

func _ready() -> void:
	base_energy = light_energy

func _process(delta: float) -> void:
	time += delta
	
	# Pulsing light effect
	if pulse_enabled and pulse_intensity > 0:
		light_energy = base_energy + sin(time * pulse_speed) * pulse_intensity
	
	# Color cycling effect
	if color_cycle:
		var hue = fmod(time * color_cycle_speed, 1.0)
		light_color = Color.from_hsv(hue, 1.0, 1.0)