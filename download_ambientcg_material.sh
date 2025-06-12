#!/bin/bash

# AmbientCG Material Creator for Godot
# Usage: 
#   Download from URL: ./download_ambientcg_material.sh "https://ambientcg.com/get?file=Rock037_4K-PNG.zip"
#   Create from existing folder: ./download_ambientcg_material.sh "/path/to/existing/material/folder"

set -e

# Check if argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <ambientcg_download_url_or_folder_path>"
    echo "Examples:"
    echo "  Download from URL: $0 'https://ambientcg.com/get?file=Rock037_4K-PNG.zip'"
    echo "  Use existing folder: $0 'materials/Rock037_4K-PNG'"
    echo "  Use existing folder: $0 '/absolute/path/to/material/folder'"
    exit 1
fi

INPUT="$1"
MATERIALS_DIR="materials"

# Determine if input is URL or folder path
if [[ "$INPUT" == http* ]]; then
    # Handle URL download
    echo "Processing URL download..."
    
    # Extract filename from URL
    ZIP_FILENAME=$(echo "$INPUT" | sed -n 's/.*file=\([^&]*\).*/\1/p')
    if [ -z "$ZIP_FILENAME" ]; then
        echo "Error: Could not extract filename from URL"
        exit 1
    fi

    # Extract material name (remove file extension)
    MATERIAL_NAME=$(echo "$ZIP_FILENAME" | sed 's/\.[^.]*$//')
    MATERIAL_DIR="$MATERIALS_DIR/$MATERIAL_NAME"

    echo "Downloading material: $MATERIAL_NAME"
    echo "Target directory: $MATERIAL_DIR"

    # Create materials directory if it doesn't exist
    mkdir -p "$MATERIALS_DIR"

    # Download the zip file
    echo "Downloading $ZIP_FILENAME..."
    curl -L -o "/tmp/$ZIP_FILENAME" "$INPUT"

    # Extract to materials directory
    echo "Extracting to $MATERIAL_DIR..."
    mkdir -p "$MATERIAL_DIR"
    unzip -o "/tmp/$ZIP_FILENAME" -d "$MATERIAL_DIR"

    # Clean up downloaded zip
    rm "/tmp/$ZIP_FILENAME"
else
    # Handle existing folder
    echo "Processing existing folder..."
    
    # Check if the folder exists
    if [ ! -d "$INPUT" ]; then
        echo "Error: Folder '$INPUT' does not exist"
        exit 1
    fi
    
    # Convert to absolute path
    MATERIAL_DIR=$(cd "$INPUT" && pwd)
    
    # Extract material name from folder name
    MATERIAL_NAME=$(basename "$MATERIAL_DIR")
    
    echo "Using existing material folder: $MATERIAL_NAME"
    echo "Source directory: $MATERIAL_DIR"
fi

# Function to generate a random UID for Godot resources
generate_uid() {
    echo "uid://$(openssl rand -hex 8)"
}

# Function to find texture files
find_texture() {
    local pattern="$1"
    find "$MATERIAL_DIR" -name "*$pattern*" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | head -1
}

# Find texture files based on common AmbientCG naming patterns
COLOR_TEX=$(find_texture "Color")
NORMAL_TEX=$(find_texture "NormalDX")
ROUGHNESS_TEX=$(find_texture "Roughness")
AO_TEX=$(find_texture "AmbientOcclusion")
DISPLACEMENT_TEX=$(find_texture "Displacement")
METALNESS_TEX=$(find_texture "Metalness")

echo "Found textures:"
echo "  Color: $COLOR_TEX"
echo "  Normal: $NORMAL_TEX"
echo "  Roughness: $ROUGHNESS_TEX"
echo "  AO: $AO_TEX"
echo "  Displacement: $DISPLACEMENT_TEX"
echo "  Metalness: $METALNESS_TEX"

# Count how many textures we found to determine load_steps
LOAD_STEPS=1
EXT_RESOURCES=""
RESOURCE_PROPS=""

# Generate external resources and material properties
ID_COUNTER=1

if [ -n "$COLOR_TEX" ]; then
    COLOR_UID=$(generate_uid)
    # Convert absolute path to relative path for Godot
    if [[ "$INPUT" == http* ]]; then
        COLOR_REL_PATH="res://${COLOR_TEX#./}"
    else
        COLOR_REL_PATH="res://materials/$(basename "$MATERIAL_DIR")/$(basename "$COLOR_TEX")"
    fi
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$COLOR_UID\" path=\"$COLOR_REL_PATH\" id=\"${ID_COUNTER}_color\"]\n"
    RESOURCE_PROPS+="albedo_texture = ExtResource(\"${ID_COUNTER}_color\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$NORMAL_TEX" ]; then
    NORMAL_UID=$(generate_uid)
    if [[ "$INPUT" == http* ]]; then
        NORMAL_REL_PATH="res://${NORMAL_TEX#./}"
    else
        NORMAL_REL_PATH="res://materials/$(basename "$MATERIAL_DIR")/$(basename "$NORMAL_TEX")"
    fi
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$NORMAL_UID\" path=\"$NORMAL_REL_PATH\" id=\"${ID_COUNTER}_normal\"]\n"
    RESOURCE_PROPS+="normal_enabled = true\n"
    RESOURCE_PROPS+="normal_scale = 1.0\n"
    RESOURCE_PROPS+="normal_texture = ExtResource(\"${ID_COUNTER}_normal\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$ROUGHNESS_TEX" ]; then
    ROUGHNESS_UID=$(generate_uid)
    if [[ "$INPUT" == http* ]]; then
        ROUGHNESS_REL_PATH="res://${ROUGHNESS_TEX#./}"
    else
        ROUGHNESS_REL_PATH="res://materials/$(basename "$MATERIAL_DIR")/$(basename "$ROUGHNESS_TEX")"
    fi
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$ROUGHNESS_UID\" path=\"$ROUGHNESS_REL_PATH\" id=\"${ID_COUNTER}_roughness\"]\n"
    RESOURCE_PROPS+="roughness_texture = ExtResource(\"${ID_COUNTER}_roughness\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$AO_TEX" ]; then
    AO_UID=$(generate_uid)
    if [[ "$INPUT" == http* ]]; then
        AO_REL_PATH="res://${AO_TEX#./}"
    else
        AO_REL_PATH="res://materials/$(basename "$MATERIAL_DIR")/$(basename "$AO_TEX")"
    fi
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$AO_UID\" path=\"$AO_REL_PATH\" id=\"${ID_COUNTER}_ao\"]\n"
    RESOURCE_PROPS+="ao_enabled = true\n"
    RESOURCE_PROPS+="ao_light_affect = 1.0\n"
    RESOURCE_PROPS+="ao_texture = ExtResource(\"${ID_COUNTER}_ao\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$DISPLACEMENT_TEX" ]; then
    DISPLACEMENT_UID=$(generate_uid)
    if [[ "$INPUT" == http* ]]; then
        DISPLACEMENT_REL_PATH="res://${DISPLACEMENT_TEX#./}"
    else
        DISPLACEMENT_REL_PATH="res://materials/$(basename "$MATERIAL_DIR")/$(basename "$DISPLACEMENT_TEX")"
    fi
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$DISPLACEMENT_UID\" path=\"$DISPLACEMENT_REL_PATH\" id=\"${ID_COUNTER}_displacement\"]\n"
    RESOURCE_PROPS+="heightmap_enabled = true\n"
    RESOURCE_PROPS+="heightmap_scale = 4.0\n"
    RESOURCE_PROPS+="heightmap_deep_parallax = true\n"
    RESOURCE_PROPS+="heightmap_min_layers = 8\n"
    RESOURCE_PROPS+="heightmap_max_layers = 32\n"
    RESOURCE_PROPS+="heightmap_texture = ExtResource(\"${ID_COUNTER}_displacement\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$METALNESS_TEX" ]; then
    METALNESS_UID=$(generate_uid)
    if [[ "$INPUT" == http* ]]; then
        METALNESS_REL_PATH="res://${METALNESS_TEX#./}"
    else
        METALNESS_REL_PATH="res://materials/$(basename "$MATERIAL_DIR")/$(basename "$METALNESS_TEX")"
    fi
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$METALNESS_UID\" path=\"$METALNESS_REL_PATH\" id=\"${ID_COUNTER}_metalness\"]\n"
    RESOURCE_PROPS+="metallic_texture = ExtResource(\"${ID_COUNTER}_metalness\")\n"
    RESOURCE_PROPS+="metallic = 1.0\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

# Determine resolution from material name for file naming
if [[ "$MATERIAL_NAME" == *"1K"* ]]; then
    TRES_FILENAME="${MATERIAL_NAME}_1k.tres"
elif [[ "$MATERIAL_NAME" == *"2K"* ]]; then
    TRES_FILENAME="${MATERIAL_NAME}_2k.tres"
elif [[ "$MATERIAL_NAME" == *"4K"* ]]; then
    TRES_FILENAME="${MATERIAL_NAME}_4k.tres"
elif [[ "$MATERIAL_NAME" == *"8K"* ]]; then
    TRES_FILENAME="${MATERIAL_NAME}_8k.tres"
else
    TRES_FILENAME="${MATERIAL_NAME}.tres"
fi

# For existing folders, create the .tres file in the materials directory
if [[ "$INPUT" == http* ]]; then
    TRES_PATH="$MATERIALS_DIR/$TRES_FILENAME"
else
    # For existing folders, put the .tres file in the materials directory with relative path
    TRES_PATH="$MATERIALS_DIR/$TRES_FILENAME"
fi

# Generate the .tres file
echo "Creating $TRES_PATH..."

MAIN_UID=$(generate_uid)

cat > "$TRES_PATH" << EOF
[gd_resource type="StandardMaterial3D" load_steps=$LOAD_STEPS format=3 uid="$MAIN_UID"]

$(echo -e "$EXT_RESOURCES")
[resource]
$(echo -e "$RESOURCE_PROPS")
EOF

echo "Material created successfully!"
echo "Files:"
if [[ "$INPUT" == http* ]]; then
    echo "  Material folder: $MATERIAL_DIR"
    echo "  Tres file: $TRES_PATH"
else
    echo "  Source folder: $MATERIAL_DIR"
    echo "  Tres file: $TRES_PATH"
fi
echo ""
echo "You may need to refresh the Godot project to see the new material."
echo "The material can be applied using the material_controller.gd script in your project."
