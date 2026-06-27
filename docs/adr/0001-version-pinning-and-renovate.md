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
