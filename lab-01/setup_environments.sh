#!/bin/bash

# Print parent directories to be created
echo 'Creating directories logs/, configs/ and scripts/'

# Define parent directory and sub directories
parent_dir=~/"devops_challenge"
dirs=("logs/" "configs/" "scripts/")

# Create logs, config and scripts directories
for dir in "${dirs[@]}"; do
    if [ -d "$parent_dir/$dir" ]; then
        echo "Directory already exists: $dir"
    else
        mkdir "$dir"
    fi
done

# Create logs, configs and scripts files
files=("logs/system.log" "configs/app.conf" "scripts/backup.sh")

for file in "${files[@]}"; do
    if [ -f "$parent_dir/$file" ]; then
       echo "File already exists: $file."
    else
       touch "$parent_dir/$file" && echo "File $file created successfull
y."
    fi
done