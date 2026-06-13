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
