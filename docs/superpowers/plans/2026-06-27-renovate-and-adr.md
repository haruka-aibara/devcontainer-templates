# Renovate 自動更新 + ADR 整備 実装計画 (Plan C)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Renovate を設定して全ての外部依存バージョンを自動 PR 更新し、ADR-0001 と ADR 一覧を整備する。

**Architecture:** `renovate.json5` を repo root に置き、GitHub Actions / Docker base digest / devcontainer Features / tenv・uv・claude のバージョン ARG を Renovate が追跡する。バージョン ARG が変わったときに SHA256 を更新するヘルパースクリプトを添える。ADR は既存 0002/0004/0005/0007 に加え 0001 を追記し、`docs/adr/README.md` で一覧化する。

**Tech Stack:** Renovate (GitHub App / hosted), renovate-config-validator (npx), bash

---

## ファイル構成

- 作成: `renovate.json5` — Renovate 本体設定
- 作成: `scripts/update-tool-shas.sh` — tenv/uv/claude の SHA256 を最新に更新するスクリプト
- 作成: `docs/adr/0001-version-pinning-and-renovate.md` — バージョン管理方針 ADR
- 作成: `docs/adr/README.md` — ADR 一覧インデックス

---

## Task 1: ADR-0001 を書く

**Files:**
- Create: `docs/adr/0001-version-pinning-and-renovate.md`

- [ ] **Step 1: ファイルを作成する**

`docs/adr/0001-version-pinning-and-renovate.md`:

```markdown
# ADR-0001: 全外部依存をバージョンピン + Renovate で自動管理する

## ステータス
採用 (2026-06-13)

## コンテキスト
devcontainer のツール群(base イメージ / devcontainer Features / tenv / uv / Claude Code / GitHub Actions)が全て「最新を動的取得」または無追跡だった。セキュリティ上の問題(サプライチェーン汚染のリスク)と再現性の欠如が課題。

## 決定
全ての外部依存を以下の方針で管理する:

| 対象 | ピン方法 | 自動更新 |
|------|---------|---------|
| base イメージ | Dockerfile ARG に digest ピン | Renovate docker manager |
| devcontainer Features | devcontainer-lock.json に digest | Renovate devcontainer manager |
| tenv / uv / Claude Code | Dockerfile ARG にバージョン + SHA256 | Renovate regex manager (バージョン) + update-tool-shas.sh (SHA) |
| GitHub Actions | @v4 等のタグ(将来 SHA ピンへ移行) | Renovate github-actions manager |

Renovate は GitHub App(hosted)で有効化し、`renovate.json5` を repo root に配置して設定する。

## 検討した選択肢
- Dependabot: devcontainer Features / カスタム regex 追跡が弱い。却下。
- 手動管理: ヒューマンエラーと更新漏れのリスク。却下。
- Renovate(採用): 豊富な datasource・カスタム regex・lock ファイル対応。

## トレードオフ
Renovate PR が定期的に飛んでくる。`schedule` で週1回にまとめることで管理コストを抑える。tenv/uv/claude は SHA256 の自動更新が未対応(Plan B で CI ワークフロー化予定)。現状は Renovate が VERSION ARG を更新する PR に対して手動で `scripts/update-tool-shas.sh` を実行する。
```

- [ ] **Step 2: コミット**

```bash
git add docs/adr/0001-version-pinning-and-renovate.md
git commit -m "docs: add ADR-0001 (version pinning and Renovate strategy)"
```

---

## Task 2: ADR 一覧 README を書く

**Files:**
- Create: `docs/adr/README.md`

- [ ] **Step 1: ファイルを作成する**

`docs/adr/README.md`:

```markdown
# Architecture Decision Records

このディレクトリは、devcontainer 設計上の重要な決定を ADR(Architecture Decision Record)として記録する。

## 一覧

| ADR | タイトル | ステータス |
|-----|---------|---------|
| [0001](0001-version-pinning-and-renovate.md) | 全外部依存をバージョンピン + Renovate で自動管理する | 採用 |
| [0002](0002-prefer-devcontainer-features.md) | 公式 devcontainer Features を優先し Dockerfile を極薄化する | 採用 |
| [0004](0004-auth-no-long-lived-secrets.md) | 認証は長期シークレットを持たない方式に統一する | 採用 |
| [0005](0005-drop-marp-presentation-tools.md) | Marp/プレゼンツールを devcontainer から廃止する | 採用 |
| [0007](0007-multi-arch-support.md) | マルチアーキテクチャ(amd64 + arm64)対応 | 採用 |

## 欠番について

- 0003: CI・サプライチェーン (Plan B で作成予定)
- 0006: イメージ配布戦略 (Plan B で作成予定)

## フォーマット

各 ADR は以下の構成を持つ:
- **ステータス**: 提案 / 採用 / 非推奨 / 廃止
- **コンテキスト**: なぜこの決定が必要だったか
- **決定**: 何を決めたか
- **検討した選択肢**: 却下した案とその理由
- **トレードオフ**: 採用した案のデメリット
```

- [ ] **Step 2: コミット**

```bash
git add docs/adr/README.md
git commit -m "docs: add ADR index README"
```

---

## Task 3: SHA256 更新ヘルパースクリプトを書く

**Files:**
- Create: `scripts/update-tool-shas.sh`

- [ ] **Step 1: スクリプトを作成する**

`scripts/update-tool-shas.sh`:

```bash
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
  local amd64 arm64
  amd64=$(curl -fsSL "https://github.com/tofuutils/tenv/releases/download/${ver}/tenv_${ver}_amd64.deb.sha256sum" | awk '{print $1}')
  arm64=$(curl -fsSL "https://github.com/tofuutils/tenv/releases/download/${ver}/tenv_${ver}_arm64.deb.sha256sum" | awk '{print $1}')
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
  amd64=$(echo "$manifest" | jq -r '.["linux-x64"].checksum')
  arm64=$(echo "$manifest" | jq -r '.["linux-arm64"].checksum')
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
```

- [ ] **Step 2: 実行権限を付与して shellcheck を通す**

Run:
```bash
chmod +x scripts/update-tool-shas.sh
shellcheck scripts/update-tool-shas.sh
```
Expected: 出力なし(終了コード 0)。警告が出たら修正する。

- [ ] **Step 3: スクリプトを動かして現行 SHA が正しいか確認**

Run:
```bash
bash scripts/update-tool-shas.sh
git diff src/haruka-aibara-dev-env/.devcontainer/Dockerfile
```
Expected: `git diff` の出力が空(現在の SHA が既に正しい)。差分が出た場合は SHA がズレていたことになるので `git add` して続ける。

- [ ] **Step 4: コミット**

```bash
git add scripts/update-tool-shas.sh
git commit -m "chore: add update-tool-shas.sh helper script"
```

---

## Task 4: renovate.json5 を書く

**Files:**
- Create: `renovate.json5`

- [ ] **Step 1: renovate.json5 を作成する**

`renovate.json5`:

```json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended"
  ],

  // 週1回月曜 JST 9:00 にまとめて更新 PR を作る
  "schedule": ["before 9am on Monday"],
  "timezone": "Asia/Tokyo",

  // PR をグループ化して通知を減らす
  "groupName": "devcontainer dependencies",

  // GitHub Actions: uses: actions/checkout@v4 等を追跡
  "github-actions": {
    "enabled": true
  },

  // Docker: Dockerfile の FROM を追跡(ARG BASE_IMAGE は customManagers で別途対応)
  "docker": {
    "enabled": true
  },

  // devcontainer Features: devcontainer.json + devcontainer-lock.json を追跡
  "devcontainer": {
    "enabled": true
  },

  "customManagers": [
    // base image digest (ARG BASE_IMAGE=...@sha256:...)
    {
      "customType": "regex",
      "fileMatch": ["^src/.*/\\.devcontainer/Dockerfile$"],
      "matchStrings": [
        "ARG BASE_IMAGE=(?<depName>[^@\\n]+)@sha256:(?<currentDigest>[a-f0-9]+)"
      ],
      "datasourceTemplate": "docker",
      "versioningTemplate": "docker"
    },
    // tenv バージョン
    {
      "customType": "regex",
      "fileMatch": ["^src/.*/\\.devcontainer/Dockerfile$"],
      "matchStrings": [
        "ARG TENV_VERSION=(?<currentValue>v[\\d.]+)"
      ],
      "depNameTemplate": "tofuutils/tenv",
      "datasourceTemplate": "github-releases",
      "versioningTemplate": "semver"
    },
    // uv バージョン
    {
      "customType": "regex",
      "fileMatch": ["^src/.*/\\.devcontainer/Dockerfile$"],
      "matchStrings": [
        "ARG UV_VERSION=(?<currentValue>[\\d.]+)"
      ],
      "depNameTemplate": "astral-sh/uv",
      "datasourceTemplate": "github-releases",
      "versioningTemplate": "semver",
      "extractVersionTemplate": "^v?(?<version>.*)$"
    },
    // claude バージョン (npm パッケージ @anthropic-ai/claude-code でバージョン追跡)
    {
      "customType": "regex",
      "fileMatch": ["^src/.*/\\.devcontainer/Dockerfile$"],
      "matchStrings": [
        "ARG CLAUDE_VERSION=(?<currentValue>[\\d.]+)"
      ],
      "depNameTemplate": "@anthropic-ai/claude-code",
      "datasourceTemplate": "npm",
      "versioningTemplate": "semver"
    }
  ],

  // VERSION ARG が更新されたら SHA も更新が必要な旨を PR に注記
  "prBodyNotes": [
    "**tenv / uv / claude のバージョンが更新された場合:** `bash scripts/update-tool-shas.sh` を実行して SHA256 を更新してください。"
  ]
}
```

- [ ] **Step 2: renovate-config-validator で設定を検証**

Run:
```bash
npx --yes renovate-config-validator renovate.json5
```
Expected:
```
INFO: Validating renovate.json5
INFO: Config validated successfully
```
エラーが出たら JSON5 の構文や設定キー名を修正する。

- [ ] **Step 3: コミット**

```bash
git add renovate.json5
git commit -m "chore: add renovate.json5 for automated dependency updates (ADR-0001)"
```

---

## Task 5: Renovate App を有効化して動作確認

**Files:** なし(GitHub の設定操作)

- [ ] **Step 1: Renovate GitHub App をインストール**

ブラウザで https://github.com/apps/renovate を開き、**Install** → `haruka-aibara/devcontainer-templates` リポジトリを選択してインストールする。

既にインストール済みの場合は Settings → GitHub Apps → Renovate → Repository access でリポジトリが含まれているか確認する。

- [ ] **Step 2: Renovate が onboarding PR を作らないことを確認**

`renovate.json5` が既に存在するため onboarding PR は作られない。数分後に GitHub Actions の Renovate ジョブが走り始める。

`https://github.com/haruka-aibara/devcontainer-templates/actions` で **Renovate** ワークフローが実行されていることを確認する。

- [ ] **Step 3: Renovate が dependency を認識しているか確認**

Renovate ログ(Actions のワークフロー出力)で以下が検出されていることを確認する:
- `docker` manager: `mcr.microsoft.com/devcontainers/base`
- `devcontainer` manager: `ghcr.io/devcontainers/features/*` (5件)
- `github-actions` manager: `actions/checkout`, `devcontainers/action`
- `regex` manager: `tofuutils/tenv`, `astral-sh/uv`, `@anthropic-ai/claude-code`

全て最新なら PR は作られない。古いものがあれば自動で PR が作られる。

---

## 完了の定義 (Plan C)

- `renovate.json5` が repo root に存在し `renovate-config-validator` をパスする
- Renovate が以下を追跡している: base image digest / devcontainer Features / tenv / uv / claude / GitHub Actions
- `scripts/update-tool-shas.sh` が shellcheck クリーンで実行可能
- `docs/adr/0001-version-pinning-and-renovate.md` が存在する
- `docs/adr/README.md` が ADR 0001/0002/0004/0005/0007 を一覧化している
- Renovate GitHub App がリポジトリに対して有効化されている

## 次の計画 (Plan B: CI・サプライチェーン)

- ci.yaml 新設(PR 時に hadolint + shellcheck + smoke test)
- release.yaml に Trivy スキャン + SBOM + cosign 署名 + SLSA provenance
- GitHub Actions の SHA ピン強化
- tenv/uv/claude の SHA 更新を Renovate PR 時に CI が自動実行
- ADR-0003(CI)、ADR-0006(配布戦略)
