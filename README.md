# AI Topic Aggregator for Slack

SlackチャンネルのAI関連の話題を自動的に検出し、スレッドごとに要約して特定チャンネルに通知するBotです。

## 🌟 主な機能

- **自動チャンネル検出**: Botが招待されたチャンネルを自動的に監視対象に
- **AI話題の自動検出**: 40種類以上のAI関連キーワードを自動検出
- **スレッドベース要約**: スレッドごとに独立した要約を生成
- **スレッドURL付き**: 各スレッドへの直接リンクを含む
- **参考URL抽出**: メッセージ内のURLを自動抽出して要約に含める
- **GPT-4o活用**: OpenAIの最新モデルで高品質な要約を生成

## 🚀 クイックスタート

### 1. Botをチャンネルに招待

```slack
/invite @AI Topic Aggregator
```

### 2. 自動的に監視開始

- 1分毎にAI関連メッセージを収集（テスト時）
- 5分毎に要約を生成して指定チャンネルに送信

### 3. 監視を停止

```slack
/remove @AI Topic Aggregator
```

## 📋 必要な設定

### Slack App設定

1. [Slack API](https://api.slack.com/apps)で新しいアプリを作成
2. 以下の権限（OAuth Scopes）を追加：
   - `channels:read` - パブリックチャンネルのリスト取得
   - `channels:history` - パブリックチャンネルのメッセージ読み取り
   - `groups:read` - プライベートチャンネルのリスト取得
   - `groups:history` - プライベートチャンネルのメッセージ読み取り
   - `chat:write` - メッセージ送信
   - `users:read` - ユーザー情報取得

### AWS設定

1. AWS SSM Parameter Storeに以下を設定：
   - `/slack-ai/prod/bot-token` - Slack Bot User OAuth Token
   - `/slack-ai/prod/openai-key` - OpenAI API Key
   - `/slack-ai/prod/target-channel` - 要約送信先チャンネルID

## 📁 プロジェクト構造

```
.
├── src/                    # Lambda関数のソースコード
│   ├── handlers/          # Lambda関数のハンドラー
│   │   ├── event.js       # Slackイベントハンドラー
│   │   ├── monitor.js     # チャンネル監視
│   │   └── summary.js     # 要約生成
│   ├── services/          # ビジネスロジック
│   │   └── aiAnalyzer.js  # OpenAI統合
│   ├── package.json       # 依存関係定義
│   └── node_modules/      # NPMパッケージ
├── terraform/             # インフラ構成
│   ├── lambda.tf         # Lambda関数定義
│   ├── dynamodb.tf       # DynamoDBテーブル
│   └── ...
├── scripts/              # ユーティリティスクリプト
│   └── build-lambda.sh   # Lambdaパッケージビルド
└── README.md
```

## 🏗️ アーキテクチャ

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Slack      │────▶│ Lambda       │────▶│  DynamoDB    │
│  Channels    │     │  Monitor     │     │  Messages    │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │ Lambda       │
                     │  Summary     │
                     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐     ┌──────────────┐
                     │   OpenAI     │────▶│    Slack     │
                     │   GPT-4o     │     │   Target Ch  │
                     └──────────────┘     └──────────────┘
```

### コンポーネント

- **Lambda Functions**
  - `channel-monitor`: Botが参加している全チャンネルを監視
  - `summary-generator`: 収集したメッセージを要約
  - `event-handler`: Slackイベント処理（将来の拡張用）

- **DynamoDB Tables**
  - `messages`: AI関連メッセージを一時保存（TTL: 7日）
  - `processed`: 処理済みメッセージIDを記録

- **EventBridge**
  - 監視: 1分毎（テスト時）/ 5分毎（本番）
  - 要約: 5分毎（テスト時）/ 朝夜2回（本番）

## 📝 要約フォーマット

```
📊 AI関連スレッドの要約 (2スレッド)

━━━━━━━━━━━━━━━━━━━━━━
スレッド 1 | 💬 5件のメッセージ
🔗 スレッドを表示

📝 要点: ChatGPTの新機能について議論
💡 ポイント: 
• 音声認識の精度が向上
• 新しいAPIエンドポイント
🔗 参考リンク: 
• https://openai.com/blog/...

━━━━━━━━━━━━━━━━━━━━━━
スレッド 2 | 💬 3件のメッセージ
🔗 スレッドを表示
...
```

## 🛠️ デプロイ方法

### Terraformを使用したデプロイ

1. 依存関係のインストール
```bash
cd terraform
terraform init
```

2. 設定ファイルの作成
```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集（slack_target_channelのみ設定）
```

3. デプロイ実行
```bash
terraform apply
```

### 手動デプロイ（AWS CLI）

```bash
# Lambda関数のパッケージ作成
bash scripts/build-lambda.sh

# Lambda関数の更新
aws lambda update-function-code \
  --function-name slack-ai-aggregator-channel-monitor-prod \
  --zip-file fileb://lambda-deployment.zip \
  --region ap-northeast-1

aws lambda update-function-code \
  --function-name slack-ai-aggregator-summary-generator-prod \
  --zip-file fileb://lambda-deployment.zip \
  --region ap-northeast-1
```

## 🔍 検出されるAIキーワード

- 基本: AI, 人工知能, Machine Learning, 機械学習
- LLM: GPT, ChatGPT, Claude, LLM, 大規模言語モデル
- 画像生成: Stable Diffusion, Midjourney, DALL-E
- ツール: LangChain, Vector Database, RAG
- フレームワーク: TensorFlow, PyTorch, Hugging Face
- 企業: OpenAI, Anthropic, Google Gemini
- その他: 40種類以上のキーワードに対応

## 📊 モニタリング

CloudWatch Logsで各Lambda関数のログを確認：
- `/aws/lambda/slack-ai-aggregator-channel-monitor-prod`
- `/aws/lambda/slack-ai-aggregator-summary-generator-prod`

## 🐛 トラブルシューティング

### Botがチャンネルを検出しない
- Botがチャンネルに招待されているか確認
- Lambda関数の環境変数を確認
- CloudWatchログでエラーを確認

### 要約が送信されない
- 要約送信先チャンネルIDが正しいか確認
- OpenAI APIキーが有効か確認
- DynamoDBにメッセージが保存されているか確認

### プライベートチャンネルが監視できない
- Slack Appに`groups:read`権限を追加
- Botをプライベートチャンネルに招待

## 📝 ライセンス

MIT

## 👥 貢献

Issues、Pull Requestsを歓迎します。

## 📞 サポート

問題が発生した場合は、GitHubでIssueを作成してください。