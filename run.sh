#!/bin/bash
set -e

if [ ! -d "debug" ]; then
    echo "Creating debug folder..."
    mkdir -p debug
fi

odin run src/ -out:debug/arcana -sanitize:address -debug
