#!/bin/bash
set -e

DEBUG_DIR="debug"
SHADER_SRC="assets/shaders/main.metal"
SHADER_AIR="$DEBUG_DIR/main.air"
SHADER_LIB="$DEBUG_DIR/default.metallib"

if [ ! -d "$DEBUG_DIR" ]; then
    echo "Creating debug folder..."
    mkdir -p "$DEBUG_DIR"
fi

echo "Compiling Metal shaders for debug..."
xcrun -sdk macosx metal -c "$SHADER_SRC" -o "$SHADER_AIR"
xcrun -sdk macosx metallib "$SHADER_AIR" -o "$SHADER_LIB"
rm "$SHADER_AIR"

echo "Running Odin project..."
odin run src/ -out:"$DEBUG_DIR/arcana" -sanitize:address -debug
