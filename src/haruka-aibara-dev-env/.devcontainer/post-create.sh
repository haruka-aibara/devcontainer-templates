#!/bin/bash
set -e

echo "Running post-create setup..."

# ======================================================================
# Install uv tools
# ======================================================================
# code style
uv tool install pycodestyle
uv tool install flake8
uv tool install pylint

# Static typing
# Usage: Check at the project directory level with commands like
# uvx --from pyre-check pyre --source-directory "project_dir" check
uv tool install pyre-check

# Testing
# Usage:
# uvx pytest test_xxx.py -v
uv tool install pytest

# ======================================================================
# tenv settings
# ======================================================================
# Install tenv for Terraform version management
tenv tf install latest-stable

# Add tenv to PATH in .bashrc
echo '# tenv' >> ~/.bashrc
echo 'export PATH=$(tenv update-path):$PATH' >> ~/.bashrc

# ======================================================================
# Use AWS icons in Markdown preview
# ======================================================================
# With this setup, you'll be able to use AWS icons in your Markdown preview, 
# making your documentation more visually appealing and easier to understand when referencing AWS services.
# Create the custom HTML head file with AWS icon support
# reference article
# https://qiita.com/take_me/items/83769d32c35e99b85ec8
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

# Source .bashrc to apply changes
source ~/.bashrc
