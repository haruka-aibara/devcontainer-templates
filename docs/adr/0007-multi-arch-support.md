# ADR-0007: マルチアーキテクチャ(amd64 + arm64)対応

## ステータス
採用 (2026-06-13)

## コンテキスト
従来は x86_64/amd64 をハードコードしており、Apple Silicon 等の arm64 環境でビルドが壊れた。

## 決定
Dockerfile 内のアーキ依存ダウンロード(tenv / uv / Claude Code)を `$TARGETARCH` で分岐し、amd64/arm64 双方の SHA256 をピンする。base イメージは digest ピン。CI のイメージビルドは buildx でマルチアーキ manifest を publish する(CI 整備は別計画)。

## トレードオフ
アーキ毎の SHA 管理が増えるが、Renovate が両アーキを追跡する。
