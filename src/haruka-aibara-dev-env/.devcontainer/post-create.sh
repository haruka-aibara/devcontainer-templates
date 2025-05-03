#!/bin/bash
set -e

echo "Running post-create setup..."

# uv tools
uv tool install pycodestyle

# Source .bashrc to apply changes
source ~/.bashrc
