#!/bin/bash
# Ensure script exits immediately if a command fails 
# and provides error messages on failure
set -e
trap 'echo "ERROR: Command failed at line $LINENO"' ERR

echo "Running post-create setup..."

# ======================================================================
# Install uv tools
# ======================================================================
echo "Step 1: Installing uv tools..."
# Code style
uv tool install pycodestyle
uv tool install flake8
uv tool install pylint

# Static typing
# Usage: Check at the project directory level with commands like
# uvx --from pyre-check pyre --source-directory "project_dir" check
echo "Step 2: Installing static typing tools..."
uv tool install pyre-check

# Testing
# Usage:
# uvx pytest test_xxx.py -v
echo "Step 3: Installing testing tools..."
uv tool install pytest

# ======================================================================
# tenv settings
# ======================================================================
# Install tenv for Terraform version management
echo "Step 4: Configuring terraform environment..."
tenv tf install latest-stable

# Add tenv to PATH in .bashrc
echo '# tenv' >> ~/.bashrc
echo 'export PATH=$(tenv update-path):$PATH' >> ~/.bashrc

# ======================================================================
# Use AWS icons in Markdown preview
# ======================================================================
# With this setup, you'll be able to use AWS icons in your Markdown preview, 
# making your documentation more visually appealing and easier to understand when referencing AWS services.
echo "Step 5: Setting up Markdown AWS icon support..."
# Create the custom HTML head file with AWS icon support
# reference article
# https://qiita.com/take_me/items/83769d32c35e99b85ec8
mkdir -p ~/.local/state/crossnote
cat > ~/.local/state/crossnote/head.html << 'EOL'
<!-- The content below will be included at the end of the <head> element. -->
<script type="text/javascript">
   const configureMermaidIconPacks = () => {
    window["mermaid"].registerIconPacks([
      {
        name: "logos",
        loader: () =>
          fetch("https://unpkg.com/@iconify-json/logos/icons.json").then(
            (res) => res.json()
          ),
      },
    ]);
  };

  // ref: https://stackoverflow.com/questions/39993676/code-inside-domcontentloaded-event-not-working
  if (document.readyState !== 'loading') {
    configureMermaidIconPacks();
  } else {
    document.addEventListener("DOMContentLoaded", () => {
      configureMermaidIconPacks();
    });
  }
</script>
EOL

# ======================================================================
# Security check
# ======================================================================
echo "Step 6: Running basic security check..."
# Check for minimal permissions on sensitive files
# This helps ensure proper security configurations
if [ -d "$HOME/.aws" ]; then
    chmod -R go-rwx $HOME/.aws
    echo "Secured AWS credentials directory"
fi

echo "Post-create setup completed successfully!"

# Source .bashrc to apply changes
source ~/.bashrc
