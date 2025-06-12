#!/bin/bash

# AmbientCG Material Downloader for Godot
# Usage: ./download_ambientcg_material.sh "https://ambientcg.com/get?file=Rock037_4K-PNG.zip"

set -e

# Check if URL is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <ambientcg_download_url>"
    echo "Example: $0 'https://ambientcg.com/get?file=Rock037_4K-PNG.zip'"
    exit 1
fi

URL="$1"
MATERIALS_DIR="materials"

# Extract filename from URL
ZIP_FILENAME=$(echo "$URL" | sed -n 's/.*file=\([^&]*\).*/\1/p')
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
curl -L -o "/tmp/$ZIP_FILENAME" "$URL"

# Extract to materials directory
echo "Extracting to $MATERIAL_DIR..."
mkdir -p "$MATERIAL_DIR"
unzip -o "/tmp/$ZIP_FILENAME" -d "$MATERIAL_DIR"

# Clean up downloaded zip
rm "/tmp/$ZIP_FILENAME"

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

echo "Found textures:"
echo "  Color: $COLOR_TEX"
echo "  Normal: $NORMAL_TEX"
echo "  Roughness: $ROUGHNESS_TEX"
echo "  AO: $AO_TEX"
echo "  Displacement: $DISPLACEMENT_TEX"

# Count how many textures we found to determine load_steps
LOAD_STEPS=1
EXT_RESOURCES=""
RESOURCE_PROPS=""

# Generate external resources and material properties
ID_COUNTER=1

if [ -n "$COLOR_TEX" ]; then
    COLOR_UID=$(generate_uid)
    COLOR_REL_PATH="res://${COLOR_TEX#./}"
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$COLOR_UID\" path=\"$COLOR_REL_PATH\" id=\"${ID_COUNTER}_color\"]\n"
    RESOURCE_PROPS+="albedo_texture = ExtResource(\"${ID_COUNTER}_color\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$NORMAL_TEX" ]; then
    NORMAL_UID=$(generate_uid)
    NORMAL_REL_PATH="res://${NORMAL_TEX#./}"
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$NORMAL_UID\" path=\"$NORMAL_REL_PATH\" id=\"${ID_COUNTER}_normal\"]\n"
    RESOURCE_PROPS+="normal_enabled = true\n"
    RESOURCE_PROPS+="normal_scale = 1.0\n"
    RESOURCE_PROPS+="normal_texture = ExtResource(\"${ID_COUNTER}_normal\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$ROUGHNESS_TEX" ]; then
    ROUGHNESS_UID=$(generate_uid)
    ROUGHNESS_REL_PATH="res://${ROUGHNESS_TEX#./}"
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$ROUGHNESS_UID\" path=\"$ROUGHNESS_REL_PATH\" id=\"${ID_COUNTER}_roughness\"]\n"
    RESOURCE_PROPS+="roughness_texture = ExtResource(\"${ID_COUNTER}_roughness\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$AO_TEX" ]; then
    AO_UID=$(generate_uid)
    AO_REL_PATH="res://${AO_TEX#./}"
    EXT_RESOURCES+="[ext_resource type=\"Texture2D\" uid=\"$AO_UID\" path=\"$AO_REL_PATH\" id=\"${ID_COUNTER}_ao\"]\n"
    RESOURCE_PROPS+="ao_enabled = true\n"
    RESOURCE_PROPS+="ao_light_affect = 1.0\n"
    RESOURCE_PROPS+="ao_texture = ExtResource(\"${ID_COUNTER}_ao\")\n"
    ((LOAD_STEPS++))
    ((ID_COUNTER++))
fi

if [ -n "$DISPLACEMENT_TEX" ]; then
    DISPLACEMENT_UID=$(generate_uid)
    DISPLACEMENT_REL_PATH="res://${DISPLACEMENT_TEX#./}"
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

TRES_PATH="$MATERIALS_DIR/$TRES_FILENAME"

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
echo "  Material folder: $MATERIAL_DIR"
echo "  Tres file: $TRES_PATH"
echo ""
echo "You may need to refresh the Godot project to see the new material."
echo "The material can be applied using the material_controller.gd script in your project."
