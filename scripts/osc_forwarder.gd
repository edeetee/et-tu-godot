class_name OSCForwarder
extends Node
## Generic node for Receiving OSC messages. Must have an active OSCServer in the scene to work. 
## Make this node the child of a node you want to control with OSC. To add your own code, extend the 
## script attached to the OSCReceiver you create by right clicking and "extend script"

## The OSCServer to receive messages from
@export var target_server: OSCServer

## The OSC address to receive
# @export var osc_address := "/example"

var full_message = []
var incoming_values = []

var root: Node

var previous_value = []
func _ready() -> void:
	target_server.message_received.connect(received_message)
	root = get_tree().root
	

func _process_message(address: String, vals: Array, time):
	print("OSCForwarder: Received message at address: %s with values: %s at time: %s" % [address, str(vals), str(time)])
	
	# Parse and apply the OSC address to set node properties
	_parse_and_apply_osc_address(address, vals)

func received_message(address, vals, time):
	if not vals is Array:
		vals = [vals]
	full_message = [address, vals, time]
	if previous_value != vals:
		incoming_values = vals
		_process_message(address, vals, time)
	
	pass

## Parse OSC address format: /parent1/parent2/etc/nodename:component:property
## and set the corresponding property to the given values
func _parse_and_apply_osc_address(address: String, vals: Array):
	# Remove leading slash and split the address
	var clean_address = address.trim_prefix("/")
	if clean_address.is_empty():
		print("OSCForwarder: Empty address received")
		return
	
	# Split by last colon to separate property info from node path
	var parts = clean_address.split(":")
	if parts.size() < 2:
		print("OSCForwarder: Invalid address format. Expected format: /path/to/node:component:property or /path/to/node:property")
		return
	
	var node_path = parts.slice(0, 1)[0]
	# node_path = ":".join(path_parts)
	var properties = parts.slice(1)
	
	# Find the target node
	var target_node = _find_node_by_path(node_path)
	if not target_node:
		print("OSCForwarder: Node not found at path: %s" % node_path)
		return
	
	# If component is specified, get the component node
	# if not component.is_empty():
	# 	target_node = target_node.get_node_or_null(component)
	# 	if not target_node:
	# 		print("OSCForwarder: Component '%s' not found in node at path: %s" % [component, node_path])
	# 		return
	
	# Set the property
	_set_node_property(target_node, properties, vals)

## Find a node by its path relative to root
func _find_node_by_path(path: String) -> Node:
	var current_node = root
	var path_parts = path.split("/")
	
	for part in path_parts:
		if part.is_empty():
			continue
		current_node = current_node.get_node_or_null(part)
		if not current_node:
			return null
	
	return current_node

## Set a property on a node, handling single values and arrays appropriately
## Supports nested properties like environment:volumetric_fog_density
func _set_node_property(node: Node, properties: PackedStringArray, vals: Array):
	if properties.size() == 0:
		print("OSCForwarder: No properties specified")
		return
	
	var current_object = node
	var property_path = ""
	
	# Navigate through the property chain except for the last property
	for i in range(properties.size() - 1):
		var property = properties[i]
		property_path += property
		
		# Check if the property exists on the current object
		if not _property_exists_on_object(current_object, property):
			print("OSCForwarder: Property '%s' not found on object '%s'" % [property, _get_object_name(current_object)])
			return
		
		# Get the next object in the chain
		current_object = current_object.get(property)
		if current_object == null:
			print("OSCForwarder: Property '%s' returned null, cannot continue navigation" % property_path)
			return
		
		property_path += "."
	
	# Now set the final property on the current object
	var final_property = properties[properties.size() - 1]
	property_path += final_property
	
	# Check if the final property exists
	if not _property_exists_on_object(current_object, final_property):
		print("OSCForwarder: Final property '%s' not found on object '%s'" % [final_property, _get_object_name(current_object)])
		return
	
	# Determine the value to set based on property type and number of values
	var value_to_set = _convert_values_to_property_type(current_object, final_property, vals)
	
	# Attempt to set the property
	current_object.set(final_property, value_to_set)
	print("OSCForwarder: Set %s.%s = %s" % [_get_object_name(node), property_path, str(value_to_set)])

## Check if a property exists on an object (Node or other Object)
func _property_exists_on_object(obj: Object, property: String) -> bool:
	var property_list = obj.get_property_list()
	for prop in property_list:
		if prop.name == property:
			return true
	return false

## Get a readable name for an object (Node name or class name)
func _get_object_name(obj: Object) -> String:
	if obj is Node:
		return (obj as Node).name
	else:
		return obj.get_class()

## Convert values to the appropriate type based on the target property
func _convert_values_to_property_type(obj: Object, property: String, vals: Array):
	var value_to_set
	
	# Determine how to set the value based on the property type and number of values
	if vals.size() == 1:
		value_to_set = vals[0]
	else:
		# Multiple values - could be Vector2, Vector3, Color, etc.
		var current_prop_value = obj.get(property)
		
		if current_prop_value is Vector2 and vals.size() >= 2:
			value_to_set = Vector2(vals[0], vals[1])
		elif current_prop_value is Vector3 and vals.size() >= 3:
			value_to_set = Vector3(vals[0], vals[1], vals[2])
		elif current_prop_value is Vector4 and vals.size() >= 4:
			value_to_set = Vector4(vals[0], vals[1], vals[2], vals[3])
		elif current_prop_value is Color:
			if vals.size() >= 4:
				value_to_set = Color(vals[0], vals[1], vals[2], vals[3])
			elif vals.size() >= 3:
				value_to_set = Color(vals[0], vals[1], vals[2], 1.0)
		elif current_prop_value is Array:
			value_to_set = vals
		else:
			# Default: use the array as-is or first value
			value_to_set = vals if vals.size() > 1 else vals[0]
	
	return value_to_set
