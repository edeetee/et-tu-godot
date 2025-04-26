extends Node

# Array to store all found mesh instances
var mesh_instances = []

# Export an array of custom materials you can set in the Inspector
@export var custom_materials: Array[Material] = []

# Dictionary to match mesh names to material indices
@export var mesh_name_to_material_index: Dictionary = {}

func _ready():
	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	
	# Find the stage_3d node (or use a direct reference if you attach this script to a specific node)
	var stage_node = get_parent().get_node("stage_3d")
	if not stage_node:
		printerr("Could not find stage_3d node!")
		return
	
	# Find all mesh instances in the stage
	find_mesh_instances(stage_node)
	
	# Print the names of all found mesh instances for debugging
	print("Found ", mesh_instances.size(), " mesh instances:")
	for i in range(mesh_instances.size()):
		var mesh = mesh_instances[i]
		print(i, ": ", mesh.name)
	
	# Apply materials based on configuration
	apply_materials()

# Recursively find all MeshInstance3D nodes
func find_mesh_instances(node):
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		find_mesh_instances(child)

# Apply materials to mesh instances based on the configuration
func apply_materials():
	if custom_materials.size() == 0:
		printerr("No custom materials defined!")
		return
	
	for mesh_name in mesh_name_to_material_index:
		var material_index = mesh_name_to_material_index[mesh_name]
		
		if material_index < 0 or material_index >= custom_materials.size():
			printerr("Invalid material index for mesh: ", mesh_name)
			continue
		
		var target_material = custom_materials[material_index]
		
		# Find all meshes with this name
		for mesh in mesh_instances:
			if mesh.name == mesh_name:
				print("Applying material to: ", mesh.name)
				mesh.material_override = target_material

# Function to apply a material to a specific mesh by name
func set_material_by_mesh_name(mesh_name: String, material: Material):
	for mesh in mesh_instances:
		if mesh.name == mesh_name:
			mesh.material_override = material
			return true
	
	printerr("Could not find mesh with name: ", mesh_name)
	return false

# Function to apply a material to a specific mesh by index
func set_material_by_mesh_index(mesh_index: int, material: Material):
	if mesh_index >= 0 and mesh_index < mesh_instances.size():
		mesh_instances[mesh_index].material_override = material
		return true
	
	printerr("Invalid mesh index: ", mesh_index)
	return false

# Function to reset a material on a specific mesh
func reset_material(mesh_name: String):
	for mesh in mesh_instances:
		if mesh.name == mesh_name:
			mesh.material_override = null
			return true
	
	return false