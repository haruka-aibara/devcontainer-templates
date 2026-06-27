#!/usr/bin/env bash
# Smoke test: ビルド済みコンテナ内で実行し、必須ツールの存在と最低バージョンを検証する。
# 使い方: docker run --rm <image> bash /usr/local/share/smoke-test.sh
set -uo pipefail

fail=0
need() { # need <表示名> <コマンド>
  if command -v "$2" >/dev/null 2>&1; then
    echo "OK   $1 ($2) -> $(command -v "$2")"
  else
    echo "FAIL $1 ($2) not found"
    fail=1
  fi
}

echo "== required tools =="
need "AWS CLI"  aws
need "gcloud"   gcloud
need "kubectl"  kubectl
need "minikube" minikube
need "helm"     helm
need "tenv"     tenv
need "uv"       uv
need "node"     node
need "npm"      npm
need "python3"  python3
need "jq"       jq
need "git"      git
need "claude"   claude
need "ansible"  ansible

echo "== aws login support (CLI >= 2.32) =="
if aws login help >/dev/null 2>&1; then
  echo "OK   'aws login' subcommand available"
else
  echo "FAIL 'aws login' not available (need AWS CLI >= 2.32.0)"
  fail=1
fi

echo "== forbidden: Marp/GUI deps must be ABSENT =="
for bad in google-chrome libreoffice; do
  if command -v "$bad" >/dev/null 2>&1; then
    echo "FAIL $bad is present but should have been removed"
    fail=1
  else
    echo "OK   $bad absent"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "SMOKE TEST FAILED"
  exit 1
fi
echo "SMOKE TEST PASSED"
