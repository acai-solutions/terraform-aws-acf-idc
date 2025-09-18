#!/bin/bash
# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


#!/bin/sh

# Function to handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Get the directory of the current script
script_dir="$(cd "$(dirname "$0")" && pwd)"
parent_dir="$(dirname "$script_dir")"
echo "My directory is $script_dir, parent directory is $parent_dir"

# Change to the script directory
cd "$script_dir" || handle_error "Failed to change directory to $script_dir"

# Remove ._* files safely
find . -name '._*' -exec rm {} \;

# Build the Docker image
docker build --platform linux/arm64 -t idc_libraries_layer . || handle_error "Failed to build Docker image."

# Check if a container named "idc_libraries_layer" already exists
container_exists=$(docker ps -a --filter "name=idc_libraries_layer" -q)
if [ -n "$container_exists" ]; then
    # Delete the existing container
    docker rm idc_libraries_layer -f || handle_error "Failed to remove existing Docker container."
fi

# Create a new container from the image
container_id=$(docker create --name idc_libraries_layer idc_libraries_layer) || handle_error "Failed to create Docker container."
if [ -z "$container_id" ]; then
    handle_error "Failed to create Docker container."
fi

# Ensure the stage directory exists and is empty
stage_dir="$parent_dir/10-layer-libraries-stage"
mkdir -p "$stage_dir"
rm -rf "$stage_dir"/*
rm -rf "$parent_dir/20-zipped/idc_libraries_layer.zip" 

# Copy files from the Docker container to the host
docker cp "idc_libraries_layer:/var/task/python" "$stage_dir" || handle_error "Failed to copy files from Docker container."

# Change directory to the stage directory
cd "$stage_dir" || handle_error "Failed to change directory to $stage_dir"

# Zip the contents of the python directory, excluding ._* files
if ! zip -r "$parent_dir/20-zipped/idc_libraries_layer.zip" python -x "*/._*"; then
    handle_error "Failed to compress files into the archive."
fi
echo "Successfully created the archive at $parent_dir/20-zipped/idc_libraries_layer.zip"

# Clean up: Remove the stage directory and its contents
rm -rf "$stage_dir"

echo "Script completed successfully."
