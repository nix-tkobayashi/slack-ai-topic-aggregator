# GitHubリポジトリへのプッシュ手順

## 1. GitHubでリポジトリを作成

1. [GitHub](https://github.com)にログイン
2. 右上の「+」から「New repository」を選択
3. リポジトリ名を入力（例: `slack-ai-aggregator`）
4. PublicまたはPrivateを選択
5. READMEなどは追加しない（既に作成済みのため）
6. 「Create repository」をクリック

## 2. ローカルリポジトリをGitHubに接続

GitHubでリポジトリ作成後、表示されるURLを使用：

```bash
# HTTPSを使用する場合
git remote add origin https://github.com/YOUR_USERNAME/slack-ai-aggregator.git

# SSHを使用する場合（推奨）
git remote add origin git@github.com:YOUR_USERNAME/slack-ai-aggregator.git
```

## 3. GitHubにプッシュ

```bash
# リモートリポジトリにプッシュ
git push -u origin main
```

## 4. 認証情報の設定（必要な場合）

### HTTPSの場合
- Personal Access Token（PAT）が必要
- GitHub Settings → Developer settings → Personal access tokens → Generate new token

### SSHの場合
```bash
# SSHキーが未設定の場合
ssh-keygen -t ed25519 -C "your_email@example.com"

# 公開鍵をGitHubに追加
cat ~/.ssh/id_ed25519.pub
# この内容をGitHub Settings → SSH and GPG keys → New SSH keyに追加
```

## 5. 今後の更新

```bash
# 変更をステージング
git add .

# コミット
git commit -m "コミットメッセージ"

# プッシュ
git push origin main
```

## 注意事項

- `.credentials`ファイルは`.gitignore`に含まれているため、GitHubにはアップロードされません
- AWS認証情報や秘密情報は絶対にコミットしないでください
- Terraform stateファイルも自動的に除外されます