# Devcontainer イメージ/本体 再設計 実装計画 (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dockerfile/devcontainer.json/post-create.sh を、公式 Features 中心・検証付き・マルチアーキ・Marp 削除・認証マウント廃止に再設計し、ローカルで再現ビルドできる状態にする。

**Architecture:** 手組み apt/curl インストールを公式 devcontainer Features に移譲し、Feature の無いツール(tenv/uv/Claude Code)だけ Dockerfile にバージョンピン+SHA256 検証で残す。base イメージは digest ピン、`$TARGETARCH` で arm64/amd64 両対応。検証はアプリのユニットテストではなく「ビルド → コンテナ内スモークテスト」で行う。

**Tech Stack:** Docker (buildx, multi-arch), devcontainer CLI, devcontainer Features (ghcr.io/devcontainers/*), bash, shellcheck, hadolint。

**注記(TDD の翻訳):** インフラ構成のため、各タスクは「スモークテストを更新 → 旧状態ではビルド/検証が失敗することを確認 → 変更 → ビルド/検証が通ることを確認 → コミット」のリズムで進める。スモークテスト = コンテナ内でツールの存在と最低バージョンを検査する bash スクリプト。

**前提コマンド:** `docker buildx`、`devcontainer`(`npm i -g @devcontainers/cli`)、`hadolint`、`shellcheck` がローカルにあること。無ければ Task 0 で導入する。

**作業ブランチ:** main へ直接コミットしない。`feat/devcontainer-foundation` ブランチを切って作業する。

---

## ファイル構成(このプランで触る範囲)

- 作成: `src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh` — ビルド済みコンテナ内で実行するツール検証スクリプト
- 修正: `src/haruka-aibara-dev-env/.devcontainer/Dockerfile` — 極薄化・digest ピン・$TARGETARCH・検証付き・Marp 削除
- 修正: `src/haruka-aibara-dev-env/.devcontainer/devcontainer.json` — Features 列挙・マウント削除・Marp 拡張/設定削除・image 参照対応
- 修正: `src/haruka-aibara-dev-env/.devcontainer/post-create.sh` — `set -euo pipefail` 強化、crossnote 維持
- 作成: `docs/adr/0002-prefer-devcontainer-features.md`, `0004-auth-no-long-lived-secrets.md`, `0005-drop-marp-presentation-tools.md`, `0007-multi-arch-support.md`(本プランで決めた判断の根拠)

---

## Task 0: 作業ブランチとツール準備

**Files:** なし(環境準備)

- [ ] **Step 1: ブランチを切る**

```bash
cd /workspaces/devcontainer-templates
git checkout -b feat/devcontainer-foundation
```

- [ ] **Step 2: 必要 CLI の存在確認**

Run:
```bash
for c in docker shellcheck hadolint devcontainer; do command -v "$c" >/dev/null && echo "OK $c" || echo "MISSING $c"; done
```
Expected: 4 つとも `OK`。`MISSING` があれば導入する:
- devcontainer CLI: `npm install -g @devcontainers/cli`
- hadolint: `docker pull hadolint/hadolint`(以降 `docker run --rm -i hadolint/hadolint < Dockerfile` で使う)
- shellcheck: `sudo apt-get update && sudo apt-get install -y shellcheck`

---

## Task 1: スモークテストスクリプトを作る(検証ハーネス)

**Files:**
- Create: `src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh`

- [ ] **Step 1: スモークテストを書く**

`src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh`:

```bash
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
```

- [ ] **Step 2: 実行権限を付与**

Run: `chmod +x src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh`

- [ ] **Step 3: shellcheck を通す**

Run: `shellcheck src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh`
Expected: 出力なし(終了コード 0)。警告が出たら修正する。

- [ ] **Step 4: コミット**

```bash
git add src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh
git commit -m "test: add container smoke-test for required toolset"
```

---

## Task 2: base イメージを digest ピン + マルチアーキ土台

**Files:**
- Modify: `src/haruka-aibara-dev-env/.devcontainer/Dockerfile`

- [ ] **Step 1: 現在の base イメージ digest を取得**

Run:
```bash
docker buildx imagetools inspect mcr.microsoft.com/devcontainers/base:ubuntu --format '{{.Manifest.Digest}}'
```
Expected: `sha256:....` が表示される。この値を控える(以降 `<BASE_DIGEST>` と表記)。

- [ ] **Step 2: Dockerfile の FROM を digest ピンに置換**

`Dockerfile` の builder/final 両方の `FROM mcr.microsoft.com/devcontainers/base:ubuntu` を、Step 1 で得た digest 付きに変更する(可読性のため ARG 化):

```dockerfile
# Renovate がこの digest を追跡・更新する
ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu@<BASE_DIGEST>

FROM ${BASE_IMAGE} AS builder
...
FROM ${BASE_IMAGE}
```

- [ ] **Step 3: ビルドが通ることを確認**

Run:
```bash
docker build -t devcontainer-foundation:wip src/haruka-aibara-dev-env/.devcontainer
```
Expected: digest ピンの base を pull してビルドが成功する(この時点では旧来のツール構成のまま)。

- [ ] **Step 4: コミット**

```bash
git add src/haruka-aibara-dev-env/.devcontainer/Dockerfile
git commit -m "build: pin base image by digest via BASE_IMAGE arg"
```

---

## Task 3: AWS CLI / kubectl・minikube・helm / Node / Python を Features へ移行

**Files:**
- Modify: `src/haruka-aibara-dev-env/.devcontainer/Dockerfile`(該当インストールを削除)
- Modify: `src/haruka-aibara-dev-env/.devcontainer/devcontainer.json`(features 追加)

- [ ] **Step 1: devcontainer.json の features に公式 Feature を追加**

`devcontainer.json` の `features` を次に置き換える(docker-in-docker は維持):

```jsonc
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {
    "moby": true,
    "dockerDashComposeVersion": "v2"
  },
  "ghcr.io/devcontainers/features/aws-cli:1": {},
  "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {},
  "ghcr.io/devcontainers/features/node:1": {},
  "ghcr.io/devcontainers/features/python:1": {}
}
```

- [ ] **Step 2: Dockerfile から重複インストールを削除**

`Dockerfile` から次を削除する:
- builder ステージ: AWS CLI の install(`awscli-exe-linux-x86_64.zip` 一式)、minikube の install、kubectl の install
- final ステージ: builder からの `COPY` のうち minikube/kubectl/aws 関連、apt の `npm`、AWS シンボリックリンク作成行

tenv の COPY は残す(Task 5 で扱う)。

- [ ] **Step 3: devcontainer CLI でビルドし、スモークテストを実行**

Run:
```bash
devcontainer build --workspace-folder src/haruka-aibara-dev-env --image-name devcontainer-foundation:wip
docker run --rm -v "$PWD/src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh:/usr/local/share/smoke-test.sh" \
  devcontainer-foundation:wip bash /usr/local/share/smoke-test.sh
```
Expected: `aws` `kubectl` `minikube` `helm` `node` `npm` `python3` が `OK`、`aws login` が `OK`。`tenv` `uv` `claude` `gcloud` `ansible` はまだ FAIL でも構わない(後続タスクで対応)。

> 補足: `devcontainer build` は features をイメージに焼き込むため、Feature 由来のツールはこのイメージに含まれる。

- [ ] **Step 4: コミット**

```bash
git add src/haruka-aibara-dev-env/.devcontainer/Dockerfile src/haruka-aibara-dev-env/.devcontainer/devcontainer.json
git commit -m "build: migrate aws-cli/kubectl/node/python to official devcontainer features"
```

---

## Task 4: gcloud と ansible の導入方法を確定

**Files:**
- Modify: `src/haruka-aibara-dev-env/.devcontainer/devcontainer.json` または `Dockerfile`
- Modify: `src/haruka-aibara-dev-env/.devcontainer/post-create.sh`(ansible を uv 導入にする場合)

- [ ] **Step 1: gcloud のコミュニティ Feature を調査**

Run:
```bash
# 例: 既知のコミュニティ Feature をリストで確認
echo "candidates: ghcr.io/dhoeric/features/google-cloud-cli  ghcr.io/devcontainers-extra/features/..."
```
判断基準: メンテされている(直近リリースがある)・スター/利用実績がある・digest 取得可能。良質な Feature があれば採用、無ければ Dockerfile にピン留め+SHA256 検証でフォールバックする。

- [ ] **Step 2: gcloud を追加**

採用する場合は `devcontainer.json` の features に追記(例):
```jsonc
"ghcr.io/dhoeric/features/google-cloud-cli:1": {}
```
フォールバックする場合は Dockerfile に、公式リポジトリ手順(apt source + keyring)をバージョン/keyring 検証付きで追加する(現状の gcloud 導入ロジックを builder→final に整理して残す)。

- [ ] **Step 3: ansible を uv tool 導入に変更**

apt の `ansible`/`ansible-lint` を Dockerfile から削除し、`post-create.sh` に追記:
```bash
uv tool install ansible-core
uv tool install ansible-lint
```
(理由: apt 版より新しく保て、uv 管理に一元化できる。ADR-0002 に記録。)

- [ ] **Step 4: ビルド + スモークテスト**

Run:
```bash
devcontainer build --workspace-folder src/haruka-aibara-dev-env --image-name devcontainer-foundation:wip
docker run --rm -v "$PWD/src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh:/usr/local/share/smoke-test.sh" \
  devcontainer-foundation:wip bash /usr/local/share/smoke-test.sh
```
Expected: `gcloud` が `OK`。`ansible` は post-create 実行前のため、ここでは FAIL でも可(post-create は `devcontainer up` 時に走る。Step 5 で確認)。

- [ ] **Step 5: post-create 込みで ansible を確認**

Run:
```bash
devcontainer up --workspace-folder src/haruka-aibara-dev-env
devcontainer exec --workspace-folder src/haruka-aibara-dev-env ansible --version
```
Expected: ansible のバージョンが表示される。

- [ ] **Step 6: コミット**

```bash
git add -A src/haruka-aibara-dev-env/.devcontainer
git commit -m "build: add gcloud feature and move ansible to uv tool"
```

---

## Task 5: tenv / uv / Claude Code をピン留め + SHA256 検証 + $TARGETARCH

**Files:**
- Modify: `src/haruka-aibara-dev-env/.devcontainer/Dockerfile`

- [ ] **Step 1: tenv の対象バージョンと SHA256 を取得**

Run:
```bash
TENV_VER=$(curl -fsSL https://api.github.com/repos/tofuutils/tenv/releases/latest | jq -r .tag_name)
echo "TENV_VER=$TENV_VER"
curl -fsSL "https://github.com/tofuutils/tenv/releases/download/${TENV_VER}/tenv_${TENV_VER}_amd64.deb.sha256sum" || \
  echo "※ リリース資産の sha256 ファイル名を releases ページで確認すること"
```
Expected: バージョン文字列と sha256 が得られる(資産名は releases ページで要確認)。amd64/arm64 両方の sha256 を控える。

- [ ] **Step 2: Dockerfile の tenv 導入を ARG ピン + 検証 + arch 対応に書き換え**

builder ステージの tenv 導入を置換:
```dockerfile
ARG TENV_VERSION=<TENV_VER>
ARG TENV_SHA256_AMD64=<sha256-amd64>
ARG TENV_SHA256_ARM64=<sha256-arm64>
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) arch=amd64; sha="${TENV_SHA256_AMD64}";; \
      arm64) arch=arm64; sha="${TENV_SHA256_ARM64}";; \
      *) echo "unsupported arch: ${TARGETARCH}"; exit 1;; \
    esac; \
    curl -fsSL -o tenv.deb "https://github.com/tofuutils/tenv/releases/download/${TENV_VERSION}/tenv_${TENV_VERSION}_${arch}.deb"; \
    echo "${sha}  tenv.deb" | sha256sum -c -; \
    dpkg -i tenv.deb; \
    rm tenv.deb
```

- [ ] **Step 3: uv を検証付きインストールに変更**

final ステージの `curl -LsSf https://astral.sh/uv/install.sh | sh` を、バージョンピン + チェックサム検証へ。astral の release 資産(`uv-x86_64-unknown-linux-gnu.tar.gz` 等)を使う:
```dockerfile
ARG UV_VERSION=<uv-version>
ARG UV_SHA256_AMD64=<sha256>
ARG UV_SHA256_ARM64=<sha256>
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) triple=x86_64-unknown-linux-gnu; sha="${UV_SHA256_AMD64}";; \
      arm64) triple=aarch64-unknown-linux-gnu; sha="${UV_SHA256_ARM64}";; \
      *) echo "unsupported arch: ${TARGETARCH}"; exit 1;; \
    esac; \
    curl -fsSL -o uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${triple}.tar.gz"; \
    echo "${sha}  uv.tar.gz" | sha256sum -c -; \
    tar -xzf uv.tar.gz; \
    install "uv-${triple}/uv" "uv-${triple}/uvx" /home/vscode/.local/bin/; \
    rm -rf uv.tar.gz "uv-${triple}"
```
(`/home/vscode/.local/bin` は既存 ENV PATH に含まれる。ディレクトリが無ければ事前に `mkdir -p`。)
各バージョン/SHA は `https://github.com/astral-sh/uv/releases` で確認して埋める。

- [ ] **Step 4: Claude Code をバージョンピン + 検証に変更**

`curl -fsSL https://claude.ai/install.sh | bash` を、固定バージョン指定 + インストール後の存在検証に変更する。公式インストーラがバージョン引数/チェックサムを公開している場合はそれを使用。最低限、インストール後に `claude --version` が成功することをビルド内で検証する:
```dockerfile
ARG CLAUDE_VERSION=<version>
RUN set -eux; \
    curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh; \
    bash /tmp/claude-install.sh "${CLAUDE_VERSION}"; \
    rm /tmp/claude-install.sh; \
    /home/vscode/.local/bin/claude --version
```
> 注: 公式インストーラの引数仕様を実装時に確認すること。チェックサムが提供されていれば sha256 検証も追加する。

- [ ] **Step 5: ビルド + スモークテスト(amd64)**

Run:
```bash
devcontainer build --workspace-folder src/haruka-aibara-dev-env --image-name devcontainer-foundation:wip
docker run --rm -v "$PWD/src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh:/usr/local/share/smoke-test.sh" \
  devcontainer-foundation:wip bash /usr/local/share/smoke-test.sh
```
Expected: `tenv` `uv` `claude` が `OK`。`SMOKE TEST PASSED`(Marp 削除は次タスクだが、現状 Marp はまだ残っているので "forbidden absent" は FAIL のはず → 次タスクで解消)。

- [ ] **Step 6: arm64 でもビルドできることを確認(クロスビルド)**

Run:
```bash
docker buildx build --platform linux/arm64 -t devcontainer-foundation:arm64 src/haruka-aibara-dev-env/.devcontainer
```
Expected: arm64 でビルド成功(QEMU エミュレーション経由)。失敗する場合は arch 分岐/SHA を見直す。

- [ ] **Step 7: コミット**

```bash
git add src/haruka-aibara-dev-env/.devcontainer/Dockerfile
git commit -m "build: pin and checksum-verify tenv/uv/claude with multi-arch support"
```

---

## Task 6: Marp / GUI 依存を削除

**Files:**
- Modify: `src/haruka-aibara-dev-env/.devcontainer/Dockerfile`
- Modify: `src/haruka-aibara-dev-env/.devcontainer/devcontainer.json`
- Create: `docs/adr/0005-drop-marp-presentation-tools.md`

- [ ] **Step 1: Dockerfile から Chrome / LibreOffice / CJK フォントを削除**

final ステージの apt インストールから `libreoffice-impress`、`fonts-noto-cjk` を削除。Google Chrome のリポジトリ追加(keyring + source list)と `google-chrome-stable` インストール行を削除。`unzip zip gzip tar curl wget htop tree jq ca-certificates` 等の最小ユーティリティは残す。

- [ ] **Step 2: devcontainer.json から Marp 関連を削除**

`extensions` から `"marp-team.marp-vscode"` を削除。`settings` から `"markdown.marp.pptx.editable"` と `"markdown.marp.exportType"` を削除。他の markdown 拡張/設定(table-prettify, mermaid, preview-enhanced 等)は維持。

- [ ] **Step 3: ADR を書く**

`docs/adr/0005-drop-marp-presentation-tools.md`:
```markdown
# ADR-0005: Marp/プレゼンツールを devcontainer から廃止する

## ステータス
採用 (2026-06-13)

## コンテキスト
従来 Chrome / LibreOffice Impress / CJK フォントを同梱していた。これは Marp の PDF/PPTX エクスポート(ヘッドレス Chromium 依存)のためで、イメージ肥大化と攻撃面増大を招いていた。執筆・発表自体は VS Code 拡張だけで可能で、重いのはエクスポート部分のみ。

## 決定
Marp 関連(Chrome / LibreOffice / CJK フォント / Marp 拡張 / Marp 設定)を全廃する。プレゼンが必要になった場合は別途 CI ジョブ(marp-cli)等で対応する。

## 検討した選択肢
- 常に同梱(現状): イメージ肥大・攻撃面大。却下。
- build ARG でオプション化: 機械が増える。Marp 利用頻度低下のため不要。
- 別テンプレートに分離: テンプレ二重管理。不要。
- 完全廃止(採用): 最軽量・最小攻撃面。

## トレードオフ
ローカルでの即時 PPTX/PDF 出力ができなくなる。必要時は CI で行う。
```

- [ ] **Step 4: ビルド + スモークテスト(今度は PASS するはず)**

Run:
```bash
devcontainer build --workspace-folder src/haruka-aibara-dev-env --image-name devcontainer-foundation:wip
docker run --rm -v "$PWD/src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh:/usr/local/share/smoke-test.sh" \
  devcontainer-foundation:wip bash /usr/local/share/smoke-test.sh
```
Expected: `google-chrome absent` `libreoffice absent` が `OK`、全体が `SMOKE TEST PASSED`。

- [ ] **Step 5: コミット**

```bash
git add src/haruka-aibara-dev-env/.devcontainer/Dockerfile src/haruka-aibara-dev-env/.devcontainer/devcontainer.json docs/adr/0005-drop-marp-presentation-tools.md
git commit -m "build: drop Marp/Chrome/LibreOffice presentation deps (ADR-0005)"
```

---

## Task 7: 認証マウント廃止 + 認証 ADR

**Files:**
- Modify: `src/haruka-aibara-dev-env/.devcontainer/devcontainer.json`
- Create: `docs/adr/0004-auth-no-long-lived-secrets.md`

- [ ] **Step 1: devcontainer.json の mounts を削除**

`devcontainer.json` の `"mounts": [...]`(`~/.aws` / `~/.config/gcloud` / `~/.gitconfig` の 3 件)を丸ごと削除する。

- [ ] **Step 2: 認証 ADR を書く**

`docs/adr/0004-auth-no-long-lived-secrets.md`:
```markdown
# ADR-0004: 認証は長期シークレットを持たない方式に統一する

## ステータス
採用 (2026-06-13)

## コンテキスト
従来はホストの ~/.aws / ~/.config/gcloud / ~/.gitconfig をマウントしていた。これはコンテナに認証情報を持ち込み、エンタープライズのレビューで指摘対象になる。

## 決定
ホストマウントを全廃し、長期シークレットをイメージにもコンテナ永続層にも置かない。
- AWS: `aws login --remote`(AWS CLI 2.32+)。Identity Center 不要・長期鍵ゼロ。短命 credential を 15 分ごと自動更新・最大 12 時間。IAM ユーザは SignInLocalDevelopmentAccess ポリシーが必要。
- GCP: `gcloud auth login` + `gcloud auth application-default login`(短命 OAuth/ADC)。
- Git: SSH agent 転送(Dev Containers 既定)。秘密鍵はコンテナに入らない。署名も agent 転送。
- CI: OIDC フェデレーション(保存シークレットゼロ)。
- 禁止: 長期アクセスキー / サービスアカウント JSON 鍵。

## 利用手順(clone-in-volume)
新規ボリュームでは初回に各ログインを実行。同一ボリューム再オープン間はキャッシュが残る。
ホスト側で ssh-agent に鍵が登録されていること(`ssh-add`)が SSH agent 転送の前提。

## トレードオフ
都度ログインの一手間が増えるが、認証情報の漏えい面を排除できる。
```

- [ ] **Step 3: devcontainer.json が妥当か検証**

Run:
```bash
devcontainer read-configuration --workspace-folder src/haruka-aibara-dev-env >/dev/null && echo "config OK"
```
Expected: `config OK`(JSON として妥当)。

- [ ] **Step 4: コミット**

```bash
git add src/haruka-aibara-dev-env/.devcontainer/devcontainer.json docs/adr/0004-auth-no-long-lived-secrets.md
git commit -m "feat: remove host credential mounts; document auth (ADR-0004)"
```

---

## Task 8: post-create.sh の強化

**Files:**
- Modify: `src/haruka-aibara-dev-env/.devcontainer/post-create.sh`

- [ ] **Step 1: エラーハンドリングを強化**

先頭の `set -e` を `set -euo pipefail` に変更。`trap 'echo "ERROR: Command failed at line $LINENO"' ERR` は維持。

- [ ] **Step 2: ansible 導入行を追加(Task 4 で未追加なら)**

Python ツール導入の節に追記(重複導入にならないよう確認):
```bash
uv tool install ansible-core
uv tool install ansible-lint
```

- [ ] **Step 3: crossnote(Mermaid AWS アイコン)節は維持**

`~/.local/state/crossnote/head.html` 生成部分は Marp とは別機能(markdown-preview-enhanced 用)なので削除しない。そのまま残す。

- [ ] **Step 4: shellcheck を通す**

Run: `shellcheck src/haruka-aibara-dev-env/.devcontainer/post-create.sh`
Expected: 出力なし。警告は修正する(`uv tool list` 等の動的コマンドは必要なら `# shellcheck disable=...` ではなく実害が無いことを確認)。

- [ ] **Step 5: post-create 込みで起動して全ツール確認**

Run:
```bash
devcontainer up --workspace-folder src/haruka-aibara-dev-env
devcontainer exec --workspace-folder src/haruka-aibara-dev-env bash /workspaces/devcontainer-templates/src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh
```
Expected: `SMOKE TEST PASSED`、`ansible` も `OK`。

- [ ] **Step 6: コミット**

```bash
git add src/haruka-aibara-dev-env/.devcontainer/post-create.sh
git commit -m "chore: harden post-create.sh (set -euo pipefail, uv ansible)"
```

---

## Task 9: 残り ADR と最終検証

**Files:**
- Create: `docs/adr/0002-prefer-devcontainer-features.md`, `docs/adr/0007-multi-arch-support.md`

- [ ] **Step 1: ADR-0002 を書く**

`docs/adr/0002-prefer-devcontainer-features.md`:
```markdown
# ADR-0002: 公式 devcontainer Features を優先し、Dockerfile を極薄化する

## ステータス
採用 (2026-06-13)

## コンテキスト
AWS CLI / kubectl / minikube / Node / Python 等を生の RUN で手組みしており、メンテ・バージョン管理・マルチアーキ対応を全て自前で抱えていた。

## 決定
公式 Feature があるものは Feature に移譲する(aws-cli, kubectl-helm-minikube, node, python, docker-in-docker)。Feature の無いもの(tenv, uv, Claude Code)だけ Dockerfile にバージョンピン+SHA256 検証で残す。ansible は uv tool 導入に一元化。gcloud は良質なコミュニティ Feature があれば採用、無ければ Dockerfile にピン+検証でフォールバック。

## トレードオフ
一部コミュニティ Feature に依存するが、digest ピン + Renovate 追跡で供給を管理する。Dockerfile の保守コストが大幅に下がる。
```

- [ ] **Step 2: ADR-0007 を書く**

`docs/adr/0007-multi-arch-support.md`:
```markdown
# ADR-0007: マルチアーキテクチャ(amd64 + arm64)対応

## ステータス
採用 (2026-06-13)

## コンテキスト
従来は x86_64/amd64 をハードコードしており、Apple Silicon 等の arm64 環境でビルドが壊れた。

## 決定
Dockerfile 内のアーキ依存ダウンロードを `$TARGETARCH` で分岐し、amd64/arm64 双方の SHA256 をピンする。CI のイメージビルドは buildx でマルチアーキ manifest を publish する。

## トレードオフ
アーキ毎の SHA 管理が増えるが、Renovate が両方を追跡する。
```

- [ ] **Step 3: 全体最終ビルド + スモークテスト + lint**

Run:
```bash
docker run --rm -i hadolint/hadolint < src/haruka-aibara-dev-env/.devcontainer/Dockerfile
shellcheck src/haruka-aibara-dev-env/.devcontainer/*.sh
devcontainer up --workspace-folder src/haruka-aibara-dev-env
devcontainer exec --workspace-folder src/haruka-aibara-dev-env bash /workspaces/devcontainer-templates/src/haruka-aibara-dev-env/.devcontainer/smoke-test.sh
```
Expected: hadolint 重大指摘なし、shellcheck クリーン、`SMOKE TEST PASSED`。

- [ ] **Step 4: コミット**

```bash
git add docs/adr/0002-prefer-devcontainer-features.md docs/adr/0007-multi-arch-support.md
git commit -m "docs: add ADR-0002 (features) and ADR-0007 (multi-arch)"
```

- [ ] **Step 5: requesting-code-review スキルでレビュー(任意・推奨)**

実装完了後、`superpowers:requesting-code-review` を使って差分をレビューする。

---

## 完了の定義 (Plan A)

- `devcontainer up` → スモークテストが PASS(必須ツール全て存在、`aws login` 利用可、Marp/GUI 依存が不在)。
- Dockerfile が digest ピン base + `$TARGETARCH` 対応 + tenv/uv/claude が SHA256 検証付き。
- devcontainer.json が Features 中心、認証マウント無し、Marp 拡張/設定無し。
- hadolint / shellcheck クリーン。
- ADR-0002/0004/0005/0007 が `docs/adr/` に存在。
- amd64/arm64 双方でビルド可能。

## 次の計画(別ファイルで作成予定)

- **Plan B: CI・サプライチェーン** — ci.yaml 新設、release.yaml のプレビルド+Trivy+SBOM+cosign 署名+SLSA attestation+マルチアーキ publish、Actions の SHA ピン、最小権限。ADR-0003/0006。
- **Plan C: Renovate + 残り ADR** — renovate.json5(base digest / Features / ピン留めツール / Actions SHA を追跡)、ADR-0001、ADR 一覧の README 整備。
```
