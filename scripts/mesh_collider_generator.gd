@tool
extends StaticBody3D

# Define proper enums for better type safety and code readability
enum ColliderMode {
	INDIVIDUAL_COLLIDERS,
	SINGLE_COMBINED_COLLIDER
}

enum GenerationMode {
	RUNTIME_GENERATION,
	SAVE_IN_SCENE
}

# Configuration properties
@export var target_node: NodePath
@export var simplified_collision: bool = true
@export var collider_mode: ColliderMode = ColliderMode.INDIVIDUAL_COLLIDERS
@export_range(0.1, 1.0, 0.1) var mesh_simplification: float = 0.5
@export var generation_mode: GenerationMode = GenerationMode.SAVE_IN_SCENE
@export var generate_now: bool = false:
	set(value):
		if value:
			generate_collision_shapes()
			generate_now = false

# Internal variables
var _mesh_instances = []

func _ready():
	if not Engine.is_editor_hint() and generation_mode == GenerationMode.RUNTIME_GENERATION:
		# Runtime generation mode - wait a frame to ensure the scene is fully loaded
		await get_tree().process_frame
		generate_collision_shapes()

func _process(_delta):
	# For editor visualization
	if Engine.is_editor_hint() and generate_now:
		generate_collision_shapes()
		generate_now = false

# Clear existing collision shapes
func clear_collision_shapes():
	var count = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
			count += 1
	print("MeshColliderGenerator: Cleared ", count, " existing collision shapes")

# Find all mesh instances in the target node
func find_mesh_instances():
	_mesh_instances.clear()
	var node_to_search = self
	
	if target_node:
		node_to_search = get_node_or_null(target_node)
		if not node_to_search:
			printerr("MeshColliderGenerator: Target node not found at path: ", target_node)
			return
		else:
			print("MeshColliderGenerator: Target node found: ", node_to_search.name)
	
	_find_mesh_instances_recursive(node_to_search)
	print("MeshColliderGenerator: Found ", _mesh_instances.size(), " mesh instances for collision generation")

# Recursively find all MeshInstance3D nodes
func _find_mesh_instances_recursive(node):
	if node is MeshInstance3D:
		_mesh_instances.append(node)
	
	for child in node.get_children():
		_find_mesh_instances_recursive(child)

# Generate collision shapes for all found mesh instances
func generate_collision_shapes():
	print("MeshColliderGenerator: Starting collision shape generation")
	clear_collision_shapes()
	find_mesh_instances()
	
	if _mesh_instances.size() == 0:
		printerr("MeshColliderGenerator: No mesh instances found for collision generation")
		return
	
	if collider_mode == ColliderMode.INDIVIDUAL_COLLIDERS:
		for mesh_instance in _mesh_instances:
			if mesh_instance is MeshInstance3D and mesh_instance.mesh:
				create_collision_for_mesh(mesh_instance)
		print("MeshColliderGenerator: Generated individual collision shapes for ", _mesh_instances.size(), " meshes")
	else: # ColliderMode.SINGLE_COMBINED_COLLIDER
		create_combined_collision()
		print("MeshColliderGenerator: Generated single combined collision shape from ", _mesh_instances.size(), " meshes")
	
	# Print the current children after generation
	print("MeshColliderGenerator: Child count after generation: ", get_child_count())
	
	# Force the scene tree to update in the editor
	if Engine.is_editor_hint():
		notify_property_list_changed()

# Simplify a set of mesh vertices to reduce the number of points
func simplify_mesh_points(points: Array) -> Array:
	print("MeshColliderGenerator: Simplifying mesh from ", points.size(), " points")
	
	if points.size() <= 8:
		# Already very simple, no need to simplify further
		return points
	
	# First, find the bounding box of the mesh
	var min_point = Vector3(INF, INF, INF)
	var max_point = Vector3(-INF, -INF, -INF)
	
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		min_point.z = min(min_point.z, point.z)
		
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
		max_point.z = max(max_point.z, point.z)
	
	# Calculate grid cell size based on mesh simplification setting
	var size = max_point - min_point
	var max_dim = max(max(size.x, size.y), size.z)
	var cell_size = max_dim * (1.0 - mesh_simplification + 0.1) / 10.0
	
	# Use a set to avoid duplicate points
	var simplified_points_set = {}
	var simplified_points = []
	
	# Calculate a simplified point for each original point
	for point in points:
		# Snap the point to a grid
		var grid_x = floor((point.x - min_point.x) / cell_size)
		var grid_y = floor((point.y - min_point.y) / cell_size)
		var grid_z = floor((point.z - min_point.z) / cell_size)
		
		# Create a key for the dictionary to check for duplicates
		var key = str(grid_x) + "_" + str(grid_y) + "_" + str(grid_z)
		
		if not simplified_points_set.has(key):
			# Convert back to world space (center of the grid cell)
			var simplified_point = Vector3(
				min_point.x + (grid_x + 0.5) * cell_size,
				min_point.y + (grid_y + 0.5) * cell_size,
				min_point.z + (grid_z + 0.5) * cell_size
			)
			
			simplified_points_set[key] = true
			simplified_points.append(simplified_point)
	
	# If we simplified too much, add the corners of the bounding box
	if simplified_points.size() < 8:
		# Add all corners of the bounding box
		simplified_points.append(Vector3(min_point.x, min_point.y, min_point.z))
		simplified_points.append(Vector3(max_point.x, min_point.y, min_point.z))
		simplified_points.append(Vector3(min_point.x, max_point.y, min_point.z))
		simplified_points.append(Vector3(max_point.x, max_point.y, min_point.z))
		simplified_points.append(Vector3(min_point.x, min_point.y, max_point.z))
		simplified_points.append(Vector3(max_point.x, min_point.y, max_point.z))
		simplified_points.append(Vector3(min_point.x, max_point.y, max_point.z))
		simplified_points.append(Vector3(max_point.x, max_point.y, max_point.z))
	
	print("MeshColliderGenerator: Simplified to ", simplified_points.size(), " points")
	return simplified_points

# Create a collision shape for a single mesh instance
func create_collision_for_mesh(mesh_instance: MeshInstance3D):
	var mesh = mesh_instance.mesh
	if not mesh:
		print("MeshColliderGenerator: Skipping mesh_instance ", mesh_instance.name, " - no mesh found")
		return
		
	print("MeshColliderGenerator: Creating collision for mesh: ", mesh_instance.name)
	
	var collision_shape = CollisionShape3D.new()
	add_child(collision_shape)
	
	# Set the owner to ensure the node is saved with the scene when in "Save In Scene" mode
	if Engine.is_editor_hint() and generation_mode == GenerationMode.SAVE_IN_SCENE and get_tree() and get_tree().edited_scene_root:
		collision_shape.owner = get_tree().edited_scene_root
	
	# Set the shape's transform to match the mesh instance's global transform
	# relative to this StaticBody
	var relative_transform = mesh_instance.global_transform * global_transform.inverse()
	collision_shape.transform = relative_transform
	
	var faces = mesh.get_faces()
	print("MeshColliderGenerator: Mesh ", mesh_instance.name, " has ", faces.size(), " vertices")
	
	if faces.size() == 0:
		print("MeshColliderGenerator: No faces found in mesh: ", mesh_instance.name)
		collision_shape.queue_free()
		return
	
	# Simplify the mesh data to reduce file size
	var simplified_points = simplify_mesh_points(faces)
	
	if simplified_collision:
		# Create a simplified convex hull shape
		var shape = ConvexPolygonShape3D.new()
		shape.set_points(simplified_points)
		collision_shape.shape = shape
	else:
		# Create a detailed concave shape (more accurate but more performance intensive)
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		collision_shape.shape = shape
	
	# Give the collision shape a name based on the mesh
	collision_shape.name = "CollisionShape_" + mesh_instance.name
	
	print("MeshColliderGenerator: Created collision shape: ", collision_shape.name)

# Create a single combined collision shape from all meshes
func create_combined_collision():
	# Skip if no meshes found
	if _mesh_instances.size() == 0:
		return
		
	print("MeshColliderGenerator: Creating combined collision shape")
	
	# Create a new collision shape
	var collision_shape = CollisionShape3D.new()
	add_child(collision_shape)
	
	# Set the owner to ensure the node is saved with the scene when in "Save In Scene" mode
	if Engine.is_editor_hint() and generation_mode == GenerationMode.SAVE_IN_SCENE and get_tree() and get_tree().edited_scene_root:
		collision_shape.owner = get_tree().edited_scene_root
	
	collision_shape.name = "CombinedCollisionShape"
	
	# Collect all mesh faces
	var all_faces = []
	
	for mesh_instance in _mesh_instances:
		if mesh_instance is MeshInstance3D and mesh_instance.mesh:
			var mesh = mesh_instance.mesh
			var faces = mesh.get_faces()
			
			print("MeshColliderGenerator: Adding ", faces.size(), " vertices from mesh: ", mesh_instance.name)
			
			if faces.size() == 0:
				print("MeshColliderGenerator: No faces found in mesh: ", mesh_instance.name)
				continue
			
			# Transform vertices to global space based on mesh instance transform
			var relative_transform = mesh_instance.global_transform * global_transform.inverse()
			for i in range(faces.size()):
				faces[i] = relative_transform.basis * faces[i] + relative_transform.origin
			
			# Add transformed faces to the collection
			all_faces.append_array(faces)
	
	if all_faces.size() == 0:
		print("MeshColliderGenerator: No faces collected from any meshes")
		collision_shape.queue_free()
		return
		
	print("MeshColliderGenerator: Combined shape has ", all_faces.size(), " vertices")
	
	# Simplify the combined points
	var simplified_points = simplify_mesh_points(all_faces)
	
	# Create the appropriate shape based on settings
	if simplified_collision:
		var shape = ConvexPolygonShape3D.new()
		shape.set_points(simplified_points)
		collision_shape.shape = shape
	else:
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(all_faces)
		collision_shape.shape = shape
	
	print("MeshColliderGenerator: Created combined collision shape: ", collision_shape.name)
