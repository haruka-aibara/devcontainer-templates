# Multi-stage build using Ubuntu base image to optimize final image size
FROM mcr.microsoft.com/devcontainers/base:ubuntu AS builder

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

# Installing AWS CLI from official source
# Downloaded as zip, extracted, installed, then cleaned up to save space
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Installing minikube for local Kubernetes development
# Direct download of the latest stable release from GitHub
RUN curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64 \
    && install minikube-linux-amd64 /usr/local/bin/minikube \
    && rm minikube-linux-amd64

# Installing tenv (Terraform version manager) from the latest GitHub release
# Using GitHub API to dynamically determine the latest version
RUN LATEST_VERSION=$(curl --silent https://api.github.com/repos/tofuutils/tenv/releases/latest | jq -r .tag_name) \
    && curl -O -L "https://github.com/tofuutils/tenv/releases/latest/download/tenv_${LATEST_VERSION}_amd64.deb" \
    && dpkg -i "tenv_${LATEST_VERSION}_amd64.deb" \
    && rm "tenv_${LATEST_VERSION}_amd64.deb"

# Installing kubectl for managing Kubernetes clusters
# Using curl to get the latest stable version dynamically
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Creating the final optimized image with just the necessary tools
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Copying installed tools from the builder stage to reduce final image size
# This multi-stage approach prevents build artifacts from bloating the final image
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/minikube /usr/local/bin/minikube
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/bin/tenv /usr/bin/tenv
COPY --from=builder /usr/bin/terraform /usr/bin/terraform

# Installing minimal set of essential system tools for development
# Grouped in a single RUN command to reduce image layers
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        npm \
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
        ansible \
        ansible-lint \
    # Creating symbolic links for AWS CLI to ensure it's in the system PATH
    && ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws \
    && ln -s /usr/local/aws-cli/v2/current/bin/aws_completer /usr/local/bin/aws_completer \
    # Cleaning up to minimize image size
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Setting up a non-root user environment with appropriate permissions
# Creating log directory with restricted permissions for security
RUN mkdir -p /home/vscode/logs \
    && chown -R vscode:vscode /home/vscode \
    && chmod -R 750 /home/vscode

# Enhancing container security through Docker runtime options
# Dropping capabilities and preventing privilege escalation
ENV DOCKER_OPTIONS="--security-opt=no-new-privileges --cap-drop=ALL --security-opt=seccomp=unconfined"

# Creating application log directory with proper permissions
# Ensuring logs are writable by the application user but protected from others
RUN mkdir -p /var/log/app \
    && chown vscode:vscode /var/log/app \
    && chmod 750 /var/log/app

# Adding container health check to monitor application status
# Will perform a check every 30 seconds with appropriate timeout settings
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Switching to non-root user for better security
# Running as root in containers is a security risk
USER vscode

# Setting the working directory for all subsequent operations
WORKDIR /home/vscode

# Installing uv - Modern Python package installer and environment manager
# Using the official installation script from astral.sh
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Adding the user's local bin directory to PATH for installed tools
ENV PATH=/home/vscode/.local/bin:$PATH

# Adding metadata for better container documentation and transparency
# Includes description, licensing, and source repository information
LABEL org.opencontainers.image.description="Secure development environment for AWS, Terraform, and Python projects"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/haruka-aibara/my-devcontainer-template"