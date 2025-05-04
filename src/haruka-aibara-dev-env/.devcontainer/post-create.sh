#!/bin/bash
# =============================================================================
# DevContainer Post-Creation Setup Script
# =============================================================================
# This script runs automatically after the container is created to set up
# development tools, configure environments, and verify installations.
# =============================================================================

# Enable strict error handling to catch issues early
# set -e: Exit immediately if any command exits with a non-zero status
# trap: Display location of any errors to aid in troubleshooting
set -e
trap 'echo "ERROR: Command failed at line $LINENO"' ERR

echo "Running post-create setup..."

# =============================================================================
# Python Development Tools Installation
# =============================================================================
# Installing code quality and linting tools via uv (Python package manager)
# uv provides faster, more reliable package installation than pip
# =============================================================================

echo "Step 1: Installing Python code quality tools..."
# Code style and linting tools to enforce consistent code quality
uv tool install pycodestyle   # Simple style checker against PEP 8
uv tool install flake8        # Wrapper combining pycodestyle, pyflakes and complexity analysis
uv tool install pylint        # Comprehensive static code analyzer with detailed reports

# Static type checking tools installation
echo "Step 2: Installing static typing tools..."
# Type checking helps catch errors before runtime
# Usage example: Check at the project directory level with:
# uvx --from pyre-check pyre --source-directory "project_dir" check
uv tool install pyre-check    # Fast, incremental type checker for Python

# Testing framework installation
echo "Step 3: Installing testing tools..."
# Automated testing ensures code reliability and prevents regressions
# Usage example: Run tests with detailed output using:
# uvx pytest test_xxx.py -v
uv tool install pytest        # Feature-rich testing framework for Python

# =============================================================================
# Terraform Environment Configuration
# =============================================================================
# Setting up Terraform version management with tenv
# This allows for switching between different Terraform versions as needed
# =============================================================================

echo "Step 4: Configuring Terraform environment..."
# Install the latest stable version of Terraform
tenv tf install latest-stable

# Add tenv to PATH by updating .bashrc
# This ensures the Terraform executable is available in all terminal sessions
echo '# tenv - Terraform version management' >> ~/.bashrc
echo 'export PATH=$(tenv update-path):$PATH' >> ~/.bashrc

# =============================================================================
# Markdown Enhancement for Documentation
# =============================================================================
# Configure Markdown preview to support AWS service icons in diagrams
# This makes architecture diagrams more readable and professional
# =============================================================================

echo "Step 5: Setting up Markdown AWS icon support..."
# Create required directory structure for crossnote custom configurations
mkdir -p ~/.local/state/crossnote

# Create custom HTML head file with AWS icon support for Markdown preview
# This configuration allows the use of AWS service icons in Mermaid diagrams
# Referenced article: https://qiita.com/take_me/items/83769d32c35e99b85ec8
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

  // Ensure the icon configuration runs after DOM is fully loaded
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

# =============================================================================
# Environment Verification
# =============================================================================
# Verify tool installations and display version information
# This confirms that all tools are correctly installed and available
# =============================================================================

echo "Step 9: Verifying installed tool versions..."

echo "AWS CLI version:"
aws --version

echo "Ansible version:"
ansible --version

echo "Terraform version:"
terraform --version

echo "Docker version:"
docker --version

echo "kubectl version:"
kubectl version --client

echo "minikube version:"
minikube version

echo "Post-creation setup completed successfully!"

# Apply changes to the current session by sourcing .bashrc
# This makes newly configured tools available immediately without restarting the shell
source ~/.bashrc