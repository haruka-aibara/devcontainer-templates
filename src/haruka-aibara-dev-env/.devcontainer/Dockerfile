FROM mcr.microsoft.com/devcontainers/base:ubuntu

# ======================================================================
# Install essential utility packages
# ======================================================================
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    # list installing packages
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

# uv tools
# RUN uv tool install pycodestyle \
#     && uv tool install flake8 \
#     && uv tool install pylint \
#     && uv tool install pyre-check \
#     && uv tool install pytest

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
