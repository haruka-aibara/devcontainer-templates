FROM mcr.microsoft.com/devcontainers/base:ubuntu

# ======================================================================
# Install essential utility packages
# ======================================================================
# Install all required packages in a single layer to reduce image size
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
    # Clean up to reduce image size and attack surface
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# ======================================================================
# Install AWS CLI
# ======================================================================
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# ======================================================================
# Install minikube
# ======================================================================
# reference article
# https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download
RUN curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64 \
    && install minikube-linux-amd64 /usr/local/bin/minikube \
    && rm minikube-linux-amd64

# ======================================================================
# Install tenv
# ======================================================================
# reference article
# https://github.com/tofuutils/tenv?tab=readme-ov-file#installation
RUN LATEST_VERSION=$(curl --silent https://api.github.com/repos/tofuutils/tenv/releases/latest | jq -r .tag_name) \
    && curl -O -L "https://github.com/tofuutils/tenv/releases/latest/download/tenv_${LATEST_VERSION}_amd64.deb" \
    && dpkg -i "tenv_${LATEST_VERSION}_amd64.deb" \
    && rm "tenv_${LATEST_VERSION}_amd64.deb"

# ======================================================================
# Create non-root user(vscode) and set proper permissions
# ======================================================================
# Create directories with proper permissions for non-root user
RUN mkdir -p /home/vscode/logs \
    && chown -R vscode:vscode /home/vscode \
    && chmod -R 750 /home/vscode

# ======================================================================
# Security Hardening
# ======================================================================
# Set no-new-privileges flag to prevent privilege escalation
ENV DOCKER_OPTIONS="--security-opt=no-new-privileges"

# ======================================================================
# Switch to non-root user
# ======================================================================
# Switch to the custom user
USER vscode

# Set the workdir
WORKDIR /home/vscode

# ======================================================================
# Install uv - Python package and project manager
# ======================================================================
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Make uv available in PATH
ENV PATH=/home/vscode/.local/bin:$PATH
