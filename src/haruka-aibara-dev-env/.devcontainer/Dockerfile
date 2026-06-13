# Renovate がこの digest を追跡・更新する
ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu@sha256:bb779775cfc7d2e65f9b0f80f17770878f5a50c00d15cc873b627c5c214ce37e

# Multi-stage build using Ubuntu base image to optimize final image size
FROM ${BASE_IMAGE} AS builder

# System updates and tool installation - combined in a single layer to minimize image size
# Using --no-install-recommends flag to avoid installing unnecessary packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        unzip \
        curl \
        jq \
    # Cleaning up apt cache to reduce image size
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Installing tenv (Terraform version manager) from the latest GitHub release
# Using GitHub API to dynamically determine the latest version
RUN LATEST_VERSION=$(curl --silent https://api.github.com/repos/tofuutils/tenv/releases/latest | jq -r .tag_name) \
    && curl -O -L "https://github.com/tofuutils/tenv/releases/latest/download/tenv_${LATEST_VERSION}_amd64.deb" \
    && dpkg -i "tenv_${LATEST_VERSION}_amd64.deb" \
    && rm "tenv_${LATEST_VERSION}_amd64.deb"

# Creating the final optimized image with just the necessary tools
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Copying installed tools from the builder stage to reduce final image size
# This multi-stage approach prevents build artifacts from bloating the final image
COPY --from=builder /usr/bin/tenv /usr/bin/tenv

# Installing minimal set of essential system tools for development
# Grouped in a single RUN command to reduce image layers
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        unzip \
        zip \
        gzip \
        tar \
        curl \
        wget \
        htop \
        tree \
        jq \
        ca-certificates \
        libreoffice-impress \
        fonts-noto-cjk \
    # Adding Google Chrome repository and installing Chrome
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
    # Adding Google Cloud SDK repository for gcloud CLI installation
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update \
    && apt-get install -y google-chrome-stable google-cloud-cli \
    # Cleaning up to minimize image size
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Setting up a non-root user environment with appropriate permissions
# Creating log directory with restricted permissions for security
RUN mkdir -p /home/vscode/logs \
    && chown -R vscode:vscode /home/vscode \
    && chmod -R 750 /home/vscode

# Creating application log directory with proper permissions
# Ensuring logs are writable by the application user but protected from others
RUN mkdir -p /var/log/app \
    && chown vscode:vscode /var/log/app \
    && chmod 750 /var/log/app

# Switching to non-root user for better security
# Running as root in containers is a security risk
USER vscode

# Setting the working directory for all subsequent operations
WORKDIR /home/vscode

# Installing uv - Modern Python package installer and environment manager
# Using the official installation script from astral.sh
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Installing Claude Code CLI using the official native installer
# Native installer is recommended over npm (npm install is deprecated)
# Installs to ~/.local/bin/claude which is already in PATH
RUN curl -fsSL https://claude.ai/install.sh | bash

# Adding the user's local bin directory to PATH for installed tools
ENV PATH=/home/vscode/.local/bin:$PATH

# Disable gcloud logging to avoid read-only file system warnings
# ENV CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1

# Adding metadata for better container documentation and transparency
# Includes description, licensing, and source repository information
LABEL org.opencontainers.image.description="Secure development environment for AWS, Terraform, and Python projects"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/haruka-aibara/devcontainer-templates"
