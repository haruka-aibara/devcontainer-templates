## reference articles

https://github.com/devcontainers/template-starter

https://zenn.dev/tellernovel_inc/articles/7a14c416d5ddfd#fn-be58-2

# Dev Containerテンプレート作成・公開: 最低限の手順

## 基本ステップ

1. テンプレートスターターをクローン or Fork
   ```bash
   git clone https://github.com/devcontainers/template-starter
   ```

2. 最低限必要なファイル構成
   ```
   src/
   └── テンプレート名/
       ├── devcontainer-template.json  # 必須
       └── .devcontainer/
           └── devcontainer.json       # 必須
   ```

3. devcontainer-template.jsonの最小構成
   ```json
   {
     "id": "テンプレート名",
     "version": "0.1.0",
     "name": "表示名",
     "description": "説明文",
     "platforms": ["対応プラットフォーム"]
   }
   ```

## GitHubにおける重要設定

1. **Workflow権限の設定**
   - リポジトリ設定 > Actions > General > Workflow permissions
   - ✅ **Allow GitHub Actions to create and approve pull requests**

2. テンプレート公開のワークフロー実行
   - Actions > "Release Dev Container Templates & Generate Documentation"
   - 「Run workflow」ボタンから実行

## テンプレート使用方法

```bash
devcontainer templates apply --template-id=ghcr.io/ユーザー名/devcontainer-templates/テンプレート名:latest
```

## 注意事項

- IDとsrc/以下のフォルダ名は一致させる必要あり
