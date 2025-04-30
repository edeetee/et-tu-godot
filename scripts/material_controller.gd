@tool
extends Node

# Array to store all found mesh instances
var mesh_instances = []

# Track original materials to restore them when global material is disabled
var original_materials = {}

# Export an array of custom materials you can set in the Inspector
@export var custom_materials: Array[Material] = []

# Dictionary to match mesh names to material indices
@export var mesh_name_to_material_index: Dictionary[String, int] = {}

# Option to apply a single material to all meshes
@export var global_material: Material:
	set(value):
		global_material = value
		if use_global_material and is_inside_tree():
			apply_global_material()

@export var use_global_material: bool = false:
	set(value):
		# If turning off global material, restore original materials
		if use_global_material and not value:
			restore_original_materials()
		
		use_global_material = value
		
		if is_inside_tree():
			if value and global_material:
				# Save original materials before applying global
				save_original_materials()
				apply_global_material()

# Make the Apply Materials button visible in the editor
@export var apply_materials_now: bool = false:
	set(value):
		if value and is_inside_tree():
			find_mesh_instances(self)
			apply_materials()
			apply_materials_now = false

# Flag to force editor update when scene is loaded
var _editor_init_done = false

func _enter_tree():
	# This gets called when the node enters the scene tree
	if Engine.is_editor_hint():
		# Schedule a delayed initialization to ensure the FBX is fully loaded
		if not _editor_init_done:
			_schedule_editor_init()

func _schedule_editor_init():
	# In editor, we need to wait longer to ensure the FBX is fully loaded
	# This is because instanced scenes load differently in the editor
	if Engine.is_editor_hint():
		get_tree().create_timer(1.0).timeout.connect(func():
			initialize()
			_editor_init_done = true
		)

func _process(_delta):
	# Only in editor, check if we need to re-scan for meshes
	if Engine.is_editor_hint() and _editor_init_done:
		if mesh_instances.size() == 0 or not _are_meshes_valid():
			find_mesh_instances(self)
			apply_materials()

# Check if the mesh instances we have are still valid (editor can unload them)
func _are_meshes_valid() -> bool:
	for mesh in mesh_instances:
		if not is_instance_valid(mesh) or not mesh.is_inside_tree():
			return false
	return true

func _ready():
	# In runtime (not in editor), initialize normally
	if not Engine.is_editor_hint():
		# Wait a frame to ensure the scene is fully loaded
		await get_tree().process_frame
		initialize()

func initialize():
	# Find all mesh instances starting from this node
	find_mesh_instances(self)
	
	# Print the names of all found mesh instances for debugging
	print("Found ", mesh_instances.size(), " mesh instances:")
	for i in range(mesh_instances.size()):
		var mesh = mesh_instances[i]
		if is_instance_valid(mesh):
			print(i, ": ", mesh.name)
	
	# Save original materials on initialization
	save_original_materials()
	
	# Apply materials based on configuration
	apply_materials()

# Save original materials before applying global material
func save_original_materials():
	original_materials.clear()
	for mesh in mesh_instances:
		if is_instance_valid(mesh):
			# Store both surface material overrides and material overrides
			var mesh_data = {
				"material_override": mesh.material_override,
				"surface_materials": {}
			}
			
			# Save individual surface materials if any
			if mesh.get_surface_override_material_count() > 0:
				for i in range(mesh.get_surface_override_material_count()):
					mesh_data["surface_materials"][i] = mesh.get_surface_override_material(i)
			
			original_materials[mesh.get_instance_id()] = mesh_data

# Restore original materials
func restore_original_materials():
	for mesh in mesh_instances:
		if is_instance_valid(mesh):
			var instance_id = mesh.get_instance_id()
			if original_materials.has(instance_id):
				var mesh_data = original_materials[instance_id]
				
				# Restore material override
				mesh.material_override = mesh_data["material_override"]
				
				# Restore surface materials
				for surface_idx in mesh_data["surface_materials"]:
					mesh.set_surface_override_material(surface_idx, mesh_data["surface_materials"][surface_idx])

# Recursively find all MeshInstance3D nodes
func find_mesh_instances(node):
	mesh_instances.clear()
	_find_mesh_instances_recursive(node)
	
	# Special handling for FBX files which might not have their children loaded in editor
	if Engine.is_editor_hint() and mesh_instances.size() == 0:
		# For FBX files, the meshes might be in a sub-scene that's not fully loaded in editor
		# Try to access the internal structure of the imported scene
		if node.get_child_count() > 0:
			var root_child = node.get_child(0)
			if root_child and "mesh" in root_child:
				mesh_instances.append(root_child)
				print("Added root mesh from FBX file")
			
			# Sometimes FBX files have a deeper structure
			for child in root_child.get_children() if root_child else []:
				if "mesh" in child:
					mesh_instances.append(child)
					print("Added child mesh from FBX file: ", child.name)

func _find_mesh_instances_recursive(node):
	if not is_instance_valid(node):
		return
		
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		_find_mesh_instances_recursive(child)

# Apply materials to mesh instances based on the configuration
func apply_materials():
	# If global material option is enabled, apply it to all meshes
	if use_global_material and global_material:
		apply_global_material()
		return
		
	if custom_materials.size() == 0:
		if Engine.is_editor_hint():
			print("No custom materials defined in material controller.")
		else:
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
			if is_instance_valid(mesh) and mesh.name == mesh_name:
				print("Applying material to: ", mesh.name)
				mesh.material_override = target_material

# Apply the global material to all mesh instances
func apply_global_material():
	if not global_material:
		printerr("Global material is not set!")
		return
		
	print("Applying global material to all ", mesh_instances.size(), " meshes")
	for mesh in mesh_instances:
		if is_instance_valid(mesh):
			mesh.material_override = global_material

# Toggle the global material on/off at runtime
func toggle_global_material(enable: bool):
	use_global_material = enable # Uses the setter which handles restoring materials

# Set a new global material at runtime
func set_global_material(material: Material):
	global_material = material
	if use_global_material:
		apply_global_material()

# Function to apply a material to a specific mesh by name
func set_material_by_mesh_name(mesh_name: String, material: Material):
	for mesh in mesh_instances:
		if is_instance_valid(mesh) and mesh.name == mesh_name:
			# Save original material first if we haven't already
			if not original_materials.has(mesh.get_instance_id()):
				save_original_materials()
			mesh.material_override = material
			return true
	
	printerr("Could not find mesh with name: ", mesh_name)
	return false

# Function to apply a material to a specific mesh by index
func set_material_by_mesh_index(mesh_index: int, material: Material):
	if mesh_index >= 0 and mesh_index < mesh_instances.size():
		var mesh = mesh_instances[mesh_index]
		if is_instance_valid(mesh):
			# Save original material first if we haven't already
			if not original_materials.has(mesh.get_instance_id()):
				save_original_materials()
			mesh.material_override = material
			return true
	
	printerr("Invalid mesh index: ", mesh_index)
	return false

# Reset all material overrides to original state
func reset_all_materials():
	restore_original_materials()
