# ADR-0002: 公式 devcontainer Features を優先し、Dockerfile を極薄化する

## ステータス
採用 (2026-06-13)

## コンテキスト
AWS CLI / kubectl / minikube / Node / Python 等を生の RUN で手組みしており、メンテ・バージョン管理・マルチアーキ対応を全て自前で抱えていた。

## 決定
公式 Feature があるものは Feature に移譲する(aws-cli, kubectl-helm-minikube, node, python, docker-in-docker)。Feature の無いもの(tenv, uv, Claude Code)だけ Dockerfile にバージョンピン+SHA256 検証で残す。ansible は uv tool 導入に一元化。gcloud は公式 devcontainer Feature が無く、コミュニティ Feature(第三者メンテナ)へ依存するより Google 公式 apt リポジトリ(keyring 検証)で入れる方が供給網として堅牢なため、Dockerfile に残す。

## トレードオフ
gcloud と tenv/uv/Claude は Dockerfile に残るが、いずれもバージョンピン+検証で管理し Renovate が追跡する。公式 Feature 由来のツールは digest ピン + Renovate 追跡。全体として Dockerfile の保守コストが大幅に下がる。
