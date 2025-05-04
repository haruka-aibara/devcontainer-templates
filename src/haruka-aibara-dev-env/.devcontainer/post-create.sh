#!/bin/bash
set -e

echo "Running post-create setup..."

# uv tools
uv tool install pycodestyle
uv tool install flake8
uv tool install pylint
uv tool install pyre-check
uv tool install pytest

# Install tenv for Terraform version management
tenv tf install latest-stable

# Add tenv to PATH in .bashrc
echo '# tenv' >> ~/.bashrc
echo 'export PATH=$(tenv update-path):$PATH' >> ~/.bashrc

# Source .bashrc to apply changes
source ~/.bashrc
