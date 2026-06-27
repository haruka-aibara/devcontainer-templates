# Architecture Decision Records

このディレクトリは、devcontainer 設計上の重要な決定を ADR(Architecture Decision Record)として記録する。

## 一覧

| ADR | タイトル | ステータス |
|-----|---------|---------|
| [0001](0001-version-pinning-and-renovate.md) | 全外部依存をバージョンピン + Renovate で自動管理する | 採用 |
| [0002](0002-prefer-devcontainer-features.md) | 公式 devcontainer Features を優先し、Dockerfile を極薄化する | 採用 |
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
