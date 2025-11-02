# Haruka Aibara Development Environment

A comprehensive DevContainer template for cloud infrastructure development, providing a consistent and secure development environment with pre-configured tools for AWS, Terraform, Ansible, Docker, and Python projects.

## 🚀 Features

### 📦 Pre-installed Tools

- **Infrastructure as Code**
  - Terraform (managed by tenv for version control)
  - AWS CLI v2
  - Google Cloud SDK (gcloud CLI)
  - Ansible & Ansible Lint

- **Container & Orchestration**
  - Docker-in-Docker
  - kubectl
  - minikube

- **Development Tools**
  - Python with uv (modern package manager)
  - Code quality tools (pylint, flake8, pycodestyle)
  - Static type checking (pyre-check)
  - Testing framework (pytest)
  - npm

- **Utilities**
  - jq, curl, wget, htop, tree
  - Git integration

### 🔒 Security Features

- Non-root user setup (runs as `vscode`)
- Read-only credential mounting
- Restricted container permissions
- Secure Docker runtime options
- Container health checks

### 🧰 VS Code Integration

- Optimized extensions for:
  - Infrastructure as Code (Terraform, Ansible)
  - Cloud Development (AWS, Google Cloud)
  - Python Development
  - Docker Management
  - Documentation (Markdown with Mermaid diagrams)

- Configured linting, formatting, and type checking

## 📋 Requirements

- Docker
- Visual Studio Code
- [VS Code Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- WSL2 with Ubuntu installed
- Properly configured `.aws`, `.config/gcloud`, and `.gitconfig` directories in your WSL2 Ubuntu home directory

### WSL2 Setup Prerequisites

Before using this DevContainer template, ensure:

1. WSL2 is installed and configured with Ubuntu
2. Your AWS credentials are set up in your WSL2 Ubuntu home directory:
   ```
   ~/.aws/credentials
   ~/.aws/config
   ```
3. Your Google Cloud credentials are set up in your WSL2 Ubuntu home directory (optional):
   ```
   ~/.config/gcloud/
   ```
   Run `gcloud auth login` on your host to configure credentials.
4. Your Git configuration is set up in your WSL2 Ubuntu home directory:
   ```
   ~/.gitconfig
   ```

These files will be mounted into the container (read-only) to enable authentication with cloud services and maintain consistent Git commit identity.

## 🔧 Usage

### Getting Started with the Template

This DevContainer template is published and ready to use directly through VS Code:

1. Open VS Code
2. Open Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P`) 
3. Type and select: `Dev Containers: Clone Repository in Container Volume...`
4. Enter the URL of your repository or choose a repository from GitHub
5. When prompted for a container configuration, select "Custom definition..."
6. Enter the custom template ID:
   ```
   ghcr.io/haruka-aibara/devcontainer-templates/haruka-aibara-dev-env:latest
   ```
7. Follow the prompts to complete the setup
8. VS Code will create a container volume, clone your repository, and open it within the development container

## 🛠 Working with the Development Environment

Once your container is running, you'll have access to all the pre-configured tools:

After the container is running, all pre-configured tools are immediately available in the integrated terminal:

```bash
echo "=================================================="
echo "🔍 INSTALLED TOOLS VERIFICATION"
echo "=================================================="

# Function to print tool version with consistent formatting
print_version() {
  local tool=$1
  local version_cmd=$2
  
  echo "📦 $tool version:"
  echo "-------------------"
  eval $version_cmd
  echo ""
}

# Cloud CLIs
print_version "AWS CLI" "aws --version"
print_version "Google Cloud SDK" "gcloud --version"

# Terraform and related tools
print_version "Terraform" "terraform --version"
print_version "tenv" "tenv --version"

# Container tools
print_version "Docker" "docker --version"
print_version "Docker Compose" "docker compose version"

# Kubernetes tools
print_version "kubectl" "kubectl version --client"
print_version "minikube" "minikube version"

# Configuration management
print_version "Ansible" "ansible --version"
print_version "Ansible Lint" "ansible-lint --version"

# Python and Python tools
print_version "Python" "python3 --version"
print_version "UV" "uv --version"

# Installed Python packages
echo "📦 Installed Python packages:"
echo "-------------------"
uv tool list
echo ""

# npm
print_version "npm" "npm --version"

# System tools
print_version "jq" "jq --version"
print_version "curl" "curl --version | head -n 1"
```

### Cloud Credentials

Cloud credentials from your host machine are automatically mounted (read-only) into the container.

**AWS Credentials**: Verify with:
```bash
aws sts get-caller-identity
```

**Google Cloud Credentials**: Verify with:
```bash
gcloud config list
gcloud auth list
```

## 🛠 Customization

### Modifying the Dockerfile

Edit `.devcontainer/Dockerfile` to add additional tools or customize the environment.

### Customizing VS Code Settings

Adjust `.devcontainer/devcontainer.json` to:
- Add/remove VS Code extensions
- Change editor preferences
- Modify container settings

### Post-Creation Script

The `.devcontainer/post-create.sh` script runs automatically after container creation. Modify it to:
- Install additional packages
- Configure environment variables
- Set up project-specific dependencies

## 📄 License

MIT License - Feel free to use and modify this template for your projects.
