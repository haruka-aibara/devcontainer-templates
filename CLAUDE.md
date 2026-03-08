# devcontainer-templates リポジトリ

haruka-aibara の個人用 devcontainer テンプレートを管理するリポジトリ。

## リポジトリ構成

```
src/haruka-aibara-dev-env/
  devcontainer-template.json          # テンプレートメタ情報（version管理）
  .devcontainer/
    Dockerfile                        # マルチステージビルド
    devcontainer.json                 # VS Code拡張・設定・features定義
    post-create.sh                    # コンテナ作成後セットアップ

.devcontainer/                        # このリポジトリ自体の開発環境（src配下と同内容）
.github/workflows/release.yaml        # mainへのpushで自動リリース
```

## 含まれるツール

**Dockerfile でインストール（最新版を動的取得）:**
- AWS CLI v2
- Google Cloud CLI (gcloud)
- kubectl, minikube
- tenv (Terraform バージョンマネージャ)
- uv (Python パッケージマネージャ)
- ansible, ansible-lint
- npm, jq, curl, wget, htop, tree, zip/tar 等
- Google Chrome, LibreOffice Impress, fonts-noto-cjk

**post-create.sh でインストール:**
- Python ツール: flake8, pylint, pyre-check, pytest (via uv tool)
- Terraform 最新安定版 (via tenv)
- Mermaid AWS アイコン設定

## リリースフロー

- `src/**` または `release.yaml` への push → GitHub Actions が自動実行
- CI がコミットメッセージを見てバージョンを自動 bump してコミット・push
- その後 `devcontainers/action@v1` がテンプレートを ghcr.io に publish

### バージョン bump ルール

| コミットメッセージ | 変化 |
|---|---|
| `feat: ...` | minor bump（例: 0.4.x → 0.5.0）|
| `fix: ...` / その他 | patch bump（例: 0.4.12 → 0.4.13）|
| `BREAKING ...` | major bump（例: 0.4.x → 1.0.0）|

### バージョンについての注意

- `devcontainer-template.json` の `version` フィールドは CI が自動管理するため手動で変えない
- push 時点でファイルに入っている番号は「前回 CI が書いた番号」であり、CI が push 後に +1 して publish する
- publish されるバージョンは CI が bump した後の番号（手元のファイルの番号ではない）
- CI の bump コミット後に `git pull` すれば手元も揃う

## バージョン管理の方針

- Dockerfile 内のツールはほぼ全て "latest" を動的取得（固定バージョンなし）
- GitHub Actions: `actions/checkout@v4`, `devcontainers/action@v1`
- devcontainer feature: `ghcr.io/devcontainers/features/docker-in-docker:2`
