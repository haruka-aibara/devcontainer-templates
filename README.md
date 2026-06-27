# Haruka Aibara Development Environment

A DevContainer template for cloud infrastructure development. Provides a consistent, secure environment for AWS, Terraform, Ansible, Docker, and Python projects.

## Pre-installed Tools

### Infrastructure as Code
- **Terraform** — managed by [tenv](https://github.com/tofuutils/tenv)
- **AWS CLI v2** — with `aws login` support (no long-lived keys required)
- **Google Cloud SDK** — gcloud CLI
- **Ansible & Ansible Lint** — via uv tool

### Container & Orchestration
- Docker-in-Docker
- kubectl, Helm, minikube

### Development Tools
- **Python** with [uv](https://github.com/astral-sh/uv) (package/env manager)
- pylint, flake8, pyre-check, pytest
- Node.js / npm
- **GitHub CLI** (`gh`)
- **Claude Code** (`claude`)

### Utilities
- jq, curl, wget, htop, tree, zip/tar
- Git (SSH agent forwarding enabled)

## Security Design

- Runs as non-root user (`vscode`)
- No long-lived credentials — host credential mounts are intentionally absent
- Base image pinned by digest; tenv/uv/claude pinned by version + SHA256
- devcontainer Features pinned by digest via `devcontainer-lock.json`

## Authentication

Credentials are **not** mounted from the host. Log in inside the container after first open:

**AWS**
```bash
aws login
# Opens browser — no IAM long-lived keys needed (AWS CLI 2.32+)
```

**Google Cloud**
```bash
gcloud auth login
gcloud auth application-default login
```

**Git / SSH**  
SSH agent forwarding is enabled by default in Dev Containers. Run `ssh-add` on the host before opening the container.

**GitHub CLI**
```bash
gh auth login
```

## Requirements

- Docker
- Visual Studio Code with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## Usage

1. Open VS Code
2. Open Command Palette (`Ctrl+Shift+P`)
3. Select **Dev Containers: Clone Repository in Container Volume...**
4. Enter the template ID when prompted:
   ```
   ghcr.io/haruka-aibara/devcontainer-templates/haruka-aibara-dev-env:latest
   ```

## Customization

- **Add tools**: prefer adding a devcontainer Feature in `.devcontainer/devcontainer.json` first; use the Dockerfile only for tools without an official Feature
- **VS Code extensions/settings**: `.devcontainer/devcontainer.json`
- **Post-create setup**: `.devcontainer/post-create.sh`

## License

MIT
