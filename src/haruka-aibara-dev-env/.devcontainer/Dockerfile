# Base image: mcr.microsoft.com/devcontainers/base:ubuntu, pinned by digest for reproducibility.
# Digest-only (no tag) form is required: the devcontainer CLI cannot parse a combined name:tag@sha256 reference.
# Renovate がこの digest を追跡・更新する。
ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base@sha256:bb779775cfc7d2e65f9b0f80f17770878f5a50c00d15cc873b627c5c214ce37e

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

# Installing tenv (Terraform/OpenTofu version manager) from a pinned GitHub release.
# Version + per-arch SHA256 are pinned for reproducibility; Renovate updates them.
ARG TENV_VERSION=v4.14.8
ARG TENV_SHA256_AMD64=4d6f019563fdb472bc16a77d0e7f950373a65111c97f298bda78dc5ab84ac00e
ARG TENV_SHA256_ARM64=6f7db564f4f21cf42595c8104adfcccb90376400582d0f4ce5985af13fa5ce61
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) sha="${TENV_SHA256_AMD64}";; \
      arm64) sha="${TENV_SHA256_ARM64}";; \
      *) echo "unsupported arch: ${TARGETARCH}"; exit 1;; \
    esac; \
    curl -fsSL -o tenv.deb "https://github.com/tofuutils/tenv/releases/download/${TENV_VERSION}/tenv_${TENV_VERSION}_${TARGETARCH}.deb"; \
    echo "${sha}  tenv.deb" | sha256sum -c -; \
    dpkg -i tenv.deb; \
    rm tenv.deb

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
    # Adding Google Cloud SDK repository for gcloud CLI installation (official apt repo, keyring-verified)
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update \
    && apt-get install -y google-cloud-cli \
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

# Installing uv (Python package/env manager) from a pinned release with checksum verification.
ARG UV_VERSION=0.11.21
ARG UV_SHA256_AMD64=8c88519b0ef0af9801fcdee419bbb12116bd9e6b18e162ae093c932d8b264050
ARG UV_SHA256_ARM64=88e800834007cc5efd4675f166eb2a51e7e3ad19876d85fa8805a6fb5c922397
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) triple=x86_64-unknown-linux-gnu; sha="${UV_SHA256_AMD64}";; \
      arm64) triple=aarch64-unknown-linux-gnu; sha="${UV_SHA256_ARM64}";; \
      *) echo "unsupported arch: ${TARGETARCH}"; exit 1;; \
    esac; \
    mkdir -p "$HOME/.local/bin"; \
    curl -fsSL -o uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${triple}.tar.gz"; \
    echo "${sha}  uv.tar.gz" | sha256sum -c -; \
    tar -xzf uv.tar.gz; \
    install "uv-${triple}/uv" "uv-${triple}/uvx" "$HOME/.local/bin/"; \
    rm -rf uv.tar.gz "uv-${triple}"

# Installing Claude Code CLI from a pinned version with checksum verification.
# We bypass install.sh (which always pulls latest) to pin the version for reproducibility.
# Checksums are from the official release manifest.json.
ARG CLAUDE_VERSION=2.1.177
ARG CLAUDE_SHA256_AMD64=ff41753634b20c869ef6a32a20863521b33d4186ac0d6a49379ab48a48395ee7
ARG CLAUDE_SHA256_ARM64=baf3926dc166215772f959e367da9784ff4c75157aaafe4524fdc79ebff984b1
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) platform=linux-x64; sha="${CLAUDE_SHA256_AMD64}";; \
      arm64) platform=linux-arm64; sha="${CLAUDE_SHA256_ARM64}";; \
      *) echo "unsupported arch: ${TARGETARCH}"; exit 1;; \
    esac; \
    mkdir -p "$HOME/.local/bin"; \
    curl -fsSL -o claude "https://downloads.claude.ai/claude-code-releases/${CLAUDE_VERSION}/${platform}/claude"; \
    echo "${sha}  claude" | sha256sum -c -; \
    install claude "$HOME/.local/bin/claude"; \
    rm claude

# Adding the user's local bin directory to PATH for installed tools
ENV PATH=/home/vscode/.local/bin:$PATH

# Disable gcloud logging to avoid read-only file system warnings
# ENV CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1

# Adding metadata for better container documentation and transparency
# Includes description, licensing, and source repository information
LABEL org.opencontainers.image.description="Secure development environment for AWS, Terraform, and Python projects"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/haruka-aibara/devcontainer-templates"
