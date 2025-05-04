# ベースイメージを使用したマルチステージビルド
FROM mcr.microsoft.com/devcontainers/base:ubuntu AS builder

# システムの更新とツールのインストール - すべて1つのレイヤーで
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        unzip \
        curl \
        jq \
        # ca-certificates \
    # キャッシュのクリーンアップ
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# AWS CLI のインストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# minikube のインストール
RUN curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64 \
    && install minikube-linux-amd64 /usr/local/bin/minikube \
    && rm minikube-linux-amd64

# tenv のインストール
RUN LATEST_VERSION=$(curl --silent https://api.github.com/repos/tofuutils/tenv/releases/latest | jq -r .tag_name) \
    && curl -O -L "https://github.com/tofuutils/tenv/releases/latest/download/tenv_${LATEST_VERSION}_amd64.deb" \
    && dpkg -i "tenv_${LATEST_VERSION}_amd64.deb" \
    && rm "tenv_${LATEST_VERSION}_amd64.deb"

# kubectl のインストール
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# 最終イメージの作成
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# ビルドステージからのツールのコピー
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/minikube /usr/local/bin/minikube
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/bin/tenv /usr/bin/tenv
COPY --from=builder /usr/bin/terraform /usr/bin/terraform

# 必要なシステムツールのインストール - 最小限のセットのみ
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
    # シンボリックリンクの作成
    && ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws \
    && ln -s /usr/local/aws-cli/v2/current/bin/aws_completer /usr/local/bin/aws_completer \
    # キャッシュのクリーンアップ
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# 非rootユーザーの作成と権限設定
RUN mkdir -p /home/vscode/logs \
    && chown -R vscode:vscode /home/vscode \
    && chmod -R 750 /home/vscode

# セキュリティハードニング設定
ENV DOCKER_OPTIONS="--security-opt=no-new-privileges --cap-drop=ALL --security-opt=seccomp=unconfined"

# ログディレクトリを作成し、アクセス許可を適切に設定
RUN mkdir -p /var/log/app \
    && chown vscode:vscode /var/log/app \
    && chmod 750 /var/log/app

# 健全性チェックのためのエンドポイント
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# 非rootユーザーに切り替え
USER vscode

# 作業ディレクトリを設定
WORKDIR /home/vscode

# uvのインストール - Pythonパッケージとプロジェクトマネージャー
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# パスを通す
ENV PATH=/home/vscode/.local/bin:$PATH

# アプリケーションデータの非機密性を宣言
LABEL org.opencontainers.image.description="Secure development environment for AWS, Terraform, and Python projects"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/haruka-aibara/my-devcontainer-template"