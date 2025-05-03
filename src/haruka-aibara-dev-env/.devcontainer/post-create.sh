#!/bin/bash
set -e

echo "Running post-create setup..."

# uv tools
uv tool install pycodestyle
uv tool install flake8
uv tool install pylint
uv tool install pyre-check
uv tool install pytest

# Source .bashrc to apply changes
source ~/.bashrc
