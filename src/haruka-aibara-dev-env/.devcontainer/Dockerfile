FROM mcr.microsoft.com/devcontainers/base:ubuntu


# ======================================================================
# Create non-root user(vscode) and set proper permissions
# ======================================================================
# reference article
# https://www.docker.com/ja-jp/blog/understanding-the-docker-user-instruction/
# Create vscode user with appropriate permissions for security
# This is critical for container security best practices
RUN mkdir -p /home/vscode/logs \
    && chown -R vscode:vscode /home/vscode \
    && chmod -R 750 /home/vscode

# ======================================================================
# Set non-root user for container execution
# ======================================================================
# Switch to non-root user for improved container security
# This must match the remoteUser in devcontainer.json
# Switch to the custom user
USER vscode

# Set the workdir
WORKDIR /home/vscode

# ======================================================================
# Security Hardening
# ======================================================================
# Set no-new-privileges flag to prevent privilege escalation
ENV DOCKER_OPTIONS="--security-opt=no-new-privileges"

# ======================================================================
# Install essential utility packages
# ======================================================================
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    # list installing packages
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
    # cleanup
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# ======================================================================
# Install uv - Python package and project manager
# ======================================================================
# Note: Direct curl installation doesn't work in this context
# Must use "su vscode" to execute as the vscode user
RUN su vscode -c "curl -LsSf https://astral.sh/uv/install.sh | sh"

# Make uv available in PATH
ENV PATH=/home/vscode/.local/bin:$PATH

# ======================================================================
# Install AWS CLI
# ======================================================================
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Create directories
RUN mkdir -p /home/vscode/logs

# ======================================================================
# Install ansible ansible-lint
# ======================================================================
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    # list installing packages
    ansible \
    ansible-lint \
    # cleanup
    && apt-get clean -y && rm -rf /var/lib/apt/lists/* 

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
    && dpkg -i "tenv_${LATEST_VERSION}_amd64.deb"
