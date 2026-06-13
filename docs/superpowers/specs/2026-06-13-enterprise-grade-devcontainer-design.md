# エンタープライズ級 devcontainer 再設計 — 設計書

- 日付: 2026-06-13
- 対象リポジトリ: `haruka-aibara/devcontainer-templates`
- ステータス: ドラフト(ユーザレビュー待ち)

## 1. 背景と目的

現状の devcontainer は「個人用テンプレート」として作られており、以下の課題がある。

- **再現性なし**: Dockerfile が全ツールを `latest` で動的取得。ビルドのたびに中身が変わり、壊れたとき「いつ何が変わったか」を追えない。
- **手組みインストールが多い**: AWS CLI / kubectl / minikube / tenv 等を生の `RUN curl` で導入。メンテ・バージョン管理・マルチアーキ対応を全て自前で抱えている。
- **`amd64` ハードコード**: arm64(Apple Silicon 等)で壊れる。
- **`curl | bash` を無検証で実行**: uv / Claude Code のインストールでチェックサム検証なし。
- **GUI 系が重い**: Chrome / LibreOffice Impress / CJK フォントが常に同梱され、イメージ肥大化と攻撃面増大。
- **配布物が未検証**: Template(ソース)配布のため、利用者のビルド成果物を検証できない。
- **ホスト認証情報マウント**: `~/.aws` / `~/.config/gcloud` / `~/.gitconfig` をマウントしており、コンテナに認証情報を持ち込んでいる。

**目的**: 大企業の DevOps 現場のレビューでも突っ込みどころのない、本番グレードの devcontainer に再設計する。柱は **(1) 再現性 (2) 自動更新 (3) 検証可能性 (4) 最小権限の認証**。加えて、**なぜその設計にしたかの根拠を ADR として残す**。

## 2. 想定ワークフロー(これが設計の起点)

ユーザの実際の使い方は次の通り。設計はこれに最適化する。

- 対象 repo に `.devcontainer` ディレクトリは **置かない**。
- ghcr に公開した**自分のプレビルド済みコンテナイメージ**で開発する。
- VS Code の **「Clone Repository in Container Volume」** で任意 repo をボリュームにクローンし、選択リストから公開イメージを選んで起動する。

これを成立させる仕様上の根拠:

- **メタデータ埋め込み**: Dev Container CLI / GitHub Action でプレビルドすると、devcontainer.json の設定(拡張機能・settings・remoteUser・Features)がイメージの `devcontainer.metadata` ラベルに焼き込まれ、イメージが**自己完結**する。repo 側に `.devcontainer` が無くても設定が適用される。
- **選択リスト**: repo に devcontainer.json が無い場合、「Clone Repository in Container Volume」は first-party/community index の Template と Image の選択リストを表示し、そこから公開イメージ/テンプレを選べる。

## 3. 決定事項サマリ

| # | 項目 | 決定 | ADR |
|---|---|---|---|
| 1 | 更新方式 | 全バージョンをピン留めし、**Renovate** が PR で自動更新 | ADR-0001 |
| 2 | ツール導入 | 公式 **devcontainer Features** 中心。Feature の無いもの(tenv/uv/Claude Code)だけ Dockerfile にピン留め+チェックサム検証で残す | ADR-0002 |
| 3 | サプライチェーン | **フルセット**: base digest ピン / checksum 検証 / Trivy スキャン / SBOM(SPDX) / cosign キーレス署名 / SLSA provenance attestation / GitHub Actions の SHA ピン / 最小権限 | ADR-0003 |
| 4 | 認証・認可 | **長期シークレットゼロ**。AWS `aws login --remote`、GCP `gcloud auth login` + ADC、Git は **SSH agent 転送**、CI は **OIDC**。ホストマウントは**全廃** | ADR-0004 |
| 5 | プレゼンツール(Marp) | **完全廃止**。Chrome / LibreOffice Impress / CJK フォント / Marp 拡張 / Marp 設定を削除 | ADR-0005 |
| 6 | 配布モデル | **C: プレビルド署名イメージ(主)+ Template(従)**。Features 焼き込み済み・メタデータ埋め込みで自己完結。devcontainer はイメージを `@sha256` 参照 | ADR-0006 |
| 7 | マルチアーキ | `amd64` ハードコード廃止、`$TARGETARCH` で **arm64 対応** | ADR-0007 |
| 8 | 設計根拠 | 各判断を **ADR** 形式で `docs/adr/` に記録 | — |

## 4. ターゲット構成

```
devcontainer-templates/
├── src/haruka-aibara-dev-env/
│   ├── devcontainer-template.json       # メタ(CI 自動 bump)
│   └── .devcontainer/
│       ├── Dockerfile                    # 極薄。digest ピン base + 検証付きツールのみ
│       ├── devcontainer.json             # Features 中心 + agent 転送 + Marp 削除
│       └── post-create.sh                # 検証(verify)中心、インストール最小
├── .github/
│   ├── workflows/
│   │   ├── ci.yaml                       # PR: build + hadolint + shellcheck + Trivy
│   │   └── release.yaml                  # push(main): bump→prebuild image→scan→SBOM→sign→attest→publish(image+template)
│   ├── renovate.json5                    # 全ピン留め値の自動更新 PR
│   └── workflows/ は SHA ピン
└── docs/
    ├── adr/
    │   ├── 0001-pin-versions-and-renovate.md
    │   ├── 0002-prefer-devcontainer-features.md
    │   ├── 0003-supply-chain-hardening.md
    │   ├── 0004-auth-no-long-lived-secrets.md
    │   ├── 0005-drop-marp-presentation-tools.md
    │   ├── 0006-distribution-prebuilt-signed-image.md
    │   └── 0007-multi-arch-support.md
    └── superpowers/specs/2026-06-13-enterprise-grade-devcontainer-design.md  # 本書
```

## 5. コンポーネント設計

### 5.1 ツールの配置先

**公式 Features に移行(devcontainer.json):**

| ツール | 移行先 Feature | 備考 |
|---|---|---|
| AWS CLI v2 | `ghcr.io/devcontainers/features/aws-cli` | 最新版で `aws login`(2.32+)が使える |
| kubectl + minikube + helm | `ghcr.io/devcontainers/features/kubectl-helm-minikube` | 3 つを 1 Feature でカバー |
| Node / npm | `ghcr.io/devcontainers/features/node` | 公式 |
| Python | `ghcr.io/devcontainers/features/python` | VS Code Python 拡張用の基盤インタプリタ |
| docker-in-docker | `ghcr.io/devcontainers/features/docker-in-docker`(現状維持) | digest ピン + Renovate 追跡に変更 |
| gcloud | コミュニティ Feature(digest ピン) | 公式が無いため。実装時に品質を確認し、無ければ Dockerfile にピン留め+検証でフォールバック |
| ansible / ansible-lint | uv tool で導入 もしくはコミュニティ Feature | apt 版より新しく保てる |

すべての Feature はバージョンタグ + Renovate による digest 追跡でピン留めする。

**Dockerfile に残す(極薄・全てピン留め+チェックサム検証):**

| ツール | 残す理由 | 安全策 |
|---|---|---|
| tenv | 中核ツール。プロジェクト毎に Terraform バージョンを切替える運用で、単一バージョンしか入らない公式 terraform Feature では役不足 | GitHub リリースをバージョンピン + SHA256 検証 |
| uv | Python 環境/ツールの基盤 | バージョンピン + チェックサム検証(現状は無検証) |
| Claude Code | ユーザ指定の CLI | バージョンピン + チェックサム検証 |
| 最小 apt 群(jq, tree, htop, wget 等) | 細かいユーティリティ | base イメージの digest ピンで土台を固定。distro パッケージは Ubuntu のパッチ管理に委ねる(ADR-0003 に根拠) |

### 5.2 Dockerfile の変更点

- `FROM mcr.microsoft.com/devcontainers/base:ubuntu` → **`@sha256:...` の digest ピン**(Renovate が更新 PR)。
- マルチステージ維持(ビルド成果物を最終イメージに持ち込まない)。
- `amd64`/`x86_64` ハードコードを **`$TARGETARCH`** ベースに置換し arm64 対応。
- すべての `curl | bash` 系を **「DL → SHA256 照合 → 実行」** の 3 段に。検証失敗時はビルドを落とす。
- Marp 関連(google-chrome-stable / libreoffice-impress / fonts-noto-cjk とそのリポジトリ追加)を削除。

### 5.3 devcontainer.json の変更点

- `build.dockerfile` 主体 → **プレビルド `image` 参照を主**にする(配布モデル C)。ローカルでカスタムビルドしたい場合のために Dockerfile も残す。
- `mounts`(`~/.aws` / `~/.config/gcloud` / `~/.gitconfig`)を**全削除**。
- SSH agent 転送に必要な設定を明示(Dev Containers は既定で `SSH_AUTH_SOCK` を転送するが、ADR に前提手順を記載)。
- 上記 Features を `features` に列挙。
- VS Code 拡張から Marp 関連(`marp-team.marp-vscode`)を削除。`settings` から `markdown.marp.*` を削除。
- それ以外の拡張/設定(Terraform, Python, Ansible, Markdown, Ruff 等)は維持。

### 5.4 post-create.sh の変更点

- Python ツール(flake8/pylint/pyre-check/pytest)の `uv tool install` は維持。
- tenv による Terraform 最新安定版セットアップは維持(tenv 自体は Dockerfile でピン導入)。
- crossnote(markdown-preview-enhanced の Mermaid AWS アイコン)設定は Marp とは別機能なので**維持**。
- 末尾の各種バージョン検証出力は維持(壊れたら気づける)。
- `set -euo pipefail` に強化し、shellcheck をかける。

### 5.5 認証・認可(ADR-0004)

長期シークレットをイメージにもコンテナ永続層にも置かない。

| 対象 | 方法 | 備考 |
|---|---|---|
| AWS | `aws login --remote` | Identity Center 不要・長期鍵ゼロ。ブラウザ無し(SSH)環境向けに `--remote`。短命 credential を `~/.aws/login/cache` にキャッシュ、15 分ごと自動更新・最大 12 時間。IAM ユーザは `SignInLocalDevelopmentAccess` ポリシーが必要 |
| GCP | `gcloud auth login` + `gcloud auth application-default login` | 短命 OAuth トークン(ADC) |
| Git | SSH agent 転送 | 秘密鍵はコンテナに入らない。署名(gpg/ssh)も agent 転送 |
| CI | OIDC フェデレーション | 保存シークレットゼロ |
| 禁止事項 | 長期アクセスキー / SA JSON 鍵 | ADR に「使用しない」と明文化 |

clone-in-volume では、ボリューム作成時に初回ログインし、同一ボリュームの再オープン間はキャッシュが残る。新規ボリュームでは都度ログイン(=設計どおり)。

## 6. CI/CD・サプライチェーン

### 6.1 ci.yaml(PR 検証・新規)

- トリガ: `src/**` を触る PR。
- 内容: devcontainer イメージのビルド(`devcontainers/ci`)、hadolint(Dockerfile)、shellcheck(post-create.sh)、Trivy 脆弱性スキャン、devcontainer.json バリデーション。
- ゲート: Trivy で CRITICAL 検出時は失敗(HIGH は警告)。
- すべての action は SHA ピン、`permissions` は最小。

### 6.2 release.yaml(main push・改修)

1. バージョン bump(既存ロジック維持: feat→minor / fix 他→patch / BREAKING→major)。
2. **Features 焼き込み済みイメージをプレビルド**(`devcontainers/ci`、`devcontainer.metadata` ラベル埋め込み、arm64+amd64 マルチアーキ)。
3. **Trivy スキャン** → CRITICAL で停止。
4. **SBOM(SPDX)生成**(syft 等)。
5. **cosign キーレス署名**(OIDC, Sigstore/Fulcio/Rekor)。
6. **SLSA provenance attestation** 付与。
7. ghcr へ push(`@sha256` digest 固定)。**イメージ(主)+ Template(従)**の両方を publish。
8. action は全て SHA ピン、`permissions` 最小化(`id-token: write`(OIDC/cosign), `packages: write`, `contents: write`、不要権限は削除)、`attestations: write` 等は必要分のみ。

### 6.3 Renovate(renovate.json5・新規)

- 追跡対象: base イメージ digest、各 Feature の digest/タグ、Dockerfile 内ピン留めツール(tenv/uv/Claude Code)のバージョン、GitHub Actions の SHA、docker-in-docker 等。
- まとめ方: パッチ/マイナーはグループ化、メジャーは個別 PR。
- CI(ci.yaml の build+scan)が緑なら自動マージ可(パッチ・マイナーのみ自動、メジャーは手動レビュー)を方針とする。

## 7. ドキュメント(ADR)

各決定を ADR(Architecture Decision Record)形式で残す。各 ADR は **コンテキスト / 決定 / 検討した選択肢 / トレードオフ / 結論** を含む。一覧は §4 のツリー参照。ADR は「なぜこの設計にしたか」を後から人が読んで納得できる形で記録することを目的とする。

## 8. スコープ外(YAGNI)

- 複数テンプレートへの分割(プレゼン専用テンプレ等)は行わない(Marp 廃止のため不要)。
- 本設計に直接関係しないリファクタリングは行わない。
- イメージ署名鍵の独自管理(KMS 等)は行わず、cosign キーレス(OIDC)で十分とする。

## 9. 段階導入の目安(実装計画で詳細化)

1. Dockerfile/devcontainer.json の Features 移行・Marp 削除・マルチアーキ・検証付き導入。
2. 認証マウント廃止と ADR-0004 の手順整備。
3. ci.yaml 新設、release.yaml のプレビルド+スキャン+SBOM+署名+attestation 化。
4. Renovate 導入。
5. ADR 一式の執筆。

各判断の根拠は対応する ADR に記録する。
