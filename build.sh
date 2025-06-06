#!/bin/bash
set -e

BUILD_DIR="build"
SHADER_SRC="assets/shaders/main.metal"
SHADER_AIR="$BUILD_DIR/main.air"
SHADER_LIB="$BUILD_DIR/default.metallib"

if [ ! -d "$BUILD_DIR" ]; then
    echo "Creating build folder..."
    mkdir -p "$BUILD_DIR"
fi

echo "Compiling Metal shaders..."
xcrun -sdk macosx metal -c "$SHADER_SRC" -o "$SHADER_AIR"
xcrun -sdk macosx metallib "$SHADER_AIR" -o "$SHADER_LIB"
rm "$SHADER_AIR"

echo "Building Odin project..."
odin build src/ -out:"$BUILD_DIR/arcana" -o:speed -show-timings

echo "Build complete."
