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
