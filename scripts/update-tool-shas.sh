#!/usr/bin/env bash
# Dockerfile の ARG SHA256 値を各ツールの最新リリースに合わせて更新する。
# Renovate が VERSION ARG を bump した後に実行する。
# 使い方: bash scripts/update-tool-shas.sh
set -euo pipefail

DOCKERFILE="src/haruka-aibara-dev-env/.devcontainer/Dockerfile"

update_tenv() {
  local ver
  ver=$(grep '^ARG TENV_VERSION=' "$DOCKERFILE" | cut -d= -f2)
  echo "==> tenv $ver"
  local checksums amd64 arm64
  checksums=$(curl -fsSL "https://github.com/tofuutils/tenv/releases/download/${ver}/tenv_${ver}_checksums.txt")
  amd64=$(echo "$checksums" | grep "_amd64.deb$" | awk '{print $1}')
  arm64=$(echo "$checksums" | grep "_arm64.deb$" | awk '{print $1}')
  sed -i "s|^ARG TENV_SHA256_AMD64=.*|ARG TENV_SHA256_AMD64=${amd64}|" "$DOCKERFILE"
  sed -i "s|^ARG TENV_SHA256_ARM64=.*|ARG TENV_SHA256_ARM64=${arm64}|" "$DOCKERFILE"
  echo "   AMD64: $amd64"
  echo "   ARM64: $arm64"
}

update_uv() {
  local ver
  ver=$(grep '^ARG UV_VERSION=' "$DOCKERFILE" | cut -d= -f2)
  echo "==> uv $ver"
  local amd64 arm64
  amd64=$(curl -fsSL "https://github.com/astral-sh/uv/releases/download/${ver}/uv-x86_64-unknown-linux-gnu.tar.gz.sha256" | awk '{print $1}')
  arm64=$(curl -fsSL "https://github.com/astral-sh/uv/releases/download/${ver}/uv-aarch64-unknown-linux-gnu.tar.gz.sha256" | awk '{print $1}')
  sed -i "s|^ARG UV_SHA256_AMD64=.*|ARG UV_SHA256_AMD64=${amd64}|" "$DOCKERFILE"
  sed -i "s|^ARG UV_SHA256_ARM64=.*|ARG UV_SHA256_ARM64=${arm64}|" "$DOCKERFILE"
  echo "   AMD64: $amd64"
  echo "   ARM64: $arm64"
}

update_claude() {
  local ver
  ver=$(grep '^ARG CLAUDE_VERSION=' "$DOCKERFILE" | cut -d= -f2)
  echo "==> claude $ver"
  local manifest amd64 arm64
  manifest=$(curl -fsSL "https://downloads.claude.ai/claude-code-releases/${ver}/manifest.json")
  amd64=$(echo "$manifest" | jq -r '.platforms["linux-x64"].checksum')
  arm64=$(echo "$manifest" | jq -r '.platforms["linux-arm64"].checksum')
  sed -i "s|^ARG CLAUDE_SHA256_AMD64=.*|ARG CLAUDE_SHA256_AMD64=${amd64}|" "$DOCKERFILE"
  sed -i "s|^ARG CLAUDE_SHA256_ARM64=.*|ARG CLAUDE_SHA256_ARM64=${arm64}|" "$DOCKERFILE"
  echo "   AMD64: $amd64"
  echo "   ARM64: $arm64"
}

update_tenv
update_uv
update_claude

echo ""
echo "Done. Run 'devcontainer build' to verify."
