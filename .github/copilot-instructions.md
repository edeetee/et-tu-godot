# Godot 3D Particle Light Physics Project

## Project Overview

This is a Godot 4.4.1 project that features 3D physics-based bouncing light particles that interact with meshes in a stage environment.

## Key Components

### Physics System

- Bouncing light particles are implemented using RigidBody3D with custom physics properties
- Custom collision system to allow light particles to interact with the stage meshes

### Visual Elements

- Advanced lighting effects using OmniLight3D nodes
- PBR materials (moss textures) from AmbientCG
- Nighttime HDR environment

### Core Scripts

- `light_controller.gd`: Controls the behavior of bouncing light particles
- `material_controller.gd`: Manages materials for meshes, including support for global material application
- `mesh_collider_generator.gd`: Dynamically generates collision shapes from stage meshes with options for individual or combined colliders

## Project Structure

- `main.tscn`: Main scene containing the stage, environment, and lighting
- `instances/bouncing_light_system.tscn`: Prefab for the bouncing light particles
- `models/stage_3d.fbx`: The 3D model used for the stage environment
- `materials/`: Contains PBR materials (moss_mat_1k.tres, moss_mat_2k.tres)
- `scripts/`: Contains all GDScript files controlling the system behavior

## Development Patterns

- Use @tool scripts for functionality that needs to work in the editor
- Physics materials are configured for bouncy behavior with low friction
- Generated collision shapes can be toggled between individual per-mesh or single combined shape

## When Writing Code

- For physics interactions, ensure colliders are properly configured
- When working with lights, consider performance impact and use appropriate attenuation
- Follow the established pattern for debug logging with prefixes (e.g., "MeshColliderGenerator: ")
- Mesh processing should handle empty meshes gracefully

## Special Notes

- The project uses custom mesh collision generation since the default collision shapes may not be appropriate for the desired light bouncing effect
- The light particles can be customized with properties like noise_motion, pulse_intensity, and random_impulses
- The collider system supports both simplified convex colliders (better performance) and detailed concave colliders (more accurate)

## Maintenance

- These instructions should be updated whenever important project changes occur
- When the developer teaches you something new about the project or codebase, add it to the relevant section
- Keep this document in sync with the evolving architecture and coding patterns of the project
