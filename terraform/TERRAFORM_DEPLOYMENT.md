# Terraform デプロイ手順書

## 前提条件

- Terraform 1.0以上がインストール済み
- AWS CLI設定済み（適切な権限を持つIAMユーザー）
- Node.js 18以上（Lambda関数のビルド用）
- Slack Appが作成済み

## 必要なAWS権限

デプロイ実行ユーザーには以下の権限が必要です：
- Lambda関数の作成・更新
- DynamoDBテーブルの作成・更新
- API Gatewayの作成・更新
- EventBridge（CloudWatch Events）の作成・更新
- IAMロール・ポリシーの作成・更新
- S3バケットの作成・更新
- CloudWatchログ・アラームの作成・更新
- Systems Manager Parameter Storeの読み書き

## デプロイ手順

### 1. 事前準備

#### Slack資格情報の取得
Slack Appダッシュボードから以下を取得：
- Bot User OAuth Token (`xoxb-...`)
- Signing Secret
- App ID

#### OpenAI APIキーの取得
OpenAI Platformから APIキーを取得

### 2. Lambda Layer の作成

```bash
# プロジェクトルートで依存関係をインストール
npm install

# Layer用のZIPファイルを作成
mkdir -p terraform/nodejs
cp -r node_modules terraform/nodejs/
cd terraform
zip -r layer.zip nodejs/
rm -rf nodejs/
cd ..
```

### 3. SSM Parameter Store に機密情報を設定

```bash
# Slack Bot Token
aws ssm put-parameter \
  --name "/slack-ai/prod/bot-token" \
  --value "xoxb-your-actual-token" \
  --type "SecureString" \
  --overwrite

# Slack Signing Secret
aws ssm put-parameter \
  --name "/slack-ai/prod/signing-secret" \
  --value "your-actual-signing-secret" \
  --type "SecureString" \
  --overwrite

# OpenAI API Key
aws ssm put-parameter \
  --name "/slack-ai/prod/openai-key" \
  --value "sk-your-actual-api-key" \
  --type "SecureString" \
  --overwrite
```

### 4. Terraform設定ファイルの準備

```bash
cd terraform

# terraform.tfvarsファイルを作成
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvarsを編集して実際の値を設定
vim terraform.tfvars
```

必須設定項目：
```hcl
slack_target_channel = "C1234567890"  # 要約送信先チャンネルID
slack_monitor_channels = [
  "C1111111111",  # 監視対象チャンネルID
  "C2222222222",
]
```

### 5. Terraform初期化とデプロイ

```bash
# Terraform初期化
terraform init

# 実行計画の確認
terraform plan

# デプロイ実行
terraform apply
```

確認プロンプトで `yes` を入力してデプロイを実行。

### 6. 出力値の確認

デプロイ完了後、以下の重要な情報が表示されます：

```bash
# API Gateway URL（Slack Webhookに設定）
api_gateway_url = "https://xxxxx.execute-api.ap-northeast-1.amazonaws.com/prod/slack/events"

# Lambda関数名
lambda_event_handler_name = "slack-ai-aggregator-event-handler-prod"
lambda_channel_monitor_name = "slack-ai-aggregator-channel-monitor-prod"
lambda_summary_generator_name = "slack-ai-aggregator-summary-generator-prod"
```

### 7. Slack App設定の更新

1. [Slack API Dashboard](https://api.slack.com/apps) にアクセス
2. Event Subscriptions を有効化
3. Request URL に Terraform出力の `api_gateway_url` を設定
4. URL Verificationが成功することを確認
5. Subscribe to bot events で以下を追加：
   - `message.channels`
   - `message.groups` (プライベートチャンネル監視時)
6. Save Changes

### 8. 動作確認

#### Lambda関数のテスト実行
```bash
# 監視機能のテスト
aws lambda invoke \
  --function-name slack-ai-aggregator-channel-monitor-prod \
  --payload '{}' \
  response.json

# ログ確認
aws logs tail /aws/lambda/slack-ai-aggregator-channel-monitor-prod --follow
```

#### 手動トリガーの実行
```bash
# チャンネル監視を手動実行
aws events put-events \
  --entries '[{"Source":"aws.manual","DetailType":"Manual Channel Monitor","Detail":"{}"}]'

# 要約生成を手動実行
aws events put-events \
  --entries '[{"Source":"aws.manual","DetailType":"Manual Summary Generation","Detail":"{}"}]'
```

## 更新・変更時の手順

### Lambda関数コードの更新

```bash
# コード変更後
cd terraform
terraform apply -target=data.archive_file.lambda_functions
terraform apply
```

### スケジュールの変更

```bash
# terraform.tfvarsを編集
monitor_schedule = "rate(10 minutes)"  # 10分毎に変更
summary_schedule = "cron(0 6,12,18 * * ? *)"  # 時間変更

# 適用
terraform apply
```

### チャンネル追加・削除

```bash
# SSM Parameter経由で更新
aws ssm put-parameter \
  --name "/slack-ai/prod/monitor-channels" \
  --value "C111,C222,C333,C444" \
  --overwrite
```

## トラブルシューティング

### URL Verificationが失敗する

1. Lambda関数のログを確認
```bash
aws logs tail /aws/lambda/slack-ai-aggregator-event-handler-prod
```

2. 署名シークレットが正しいか確認
```bash
aws ssm get-parameter \
  --name "/slack-ai/prod/signing-secret" \
  --with-decryption
```

### メッセージが検出されない

1. チャンネルIDが正しいか確認
```bash
aws ssm get-parameter --name "/slack-ai/prod/monitor-channels"
```

2. Lambda関数が実行されているか確認
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=slack-ai-aggregator-channel-monitor-prod \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### DynamoDBエラー

1. テーブルの状態確認
```bash
aws dynamodb describe-table \
  --table-name slack-ai-aggregator-messages-prod
```

2. キャパシティモードの変更が必要な場合
```hcl
# terraform.tfvars
dynamodb_billing_mode = "PROVISIONED"
dynamodb_read_capacity = 10
dynamodb_write_capacity = 10
```

## 環境の削除

```bash
cd terraform

# 削除前に確認
terraform plan -destroy

# 削除実行
terraform destroy
```

**注意**: DynamoDBテーブルのデータも削除されます。必要に応じてバックアップを取得してください。

## コスト管理

### 見積もりコスト（月額）

- Lambda: ~$1-2
- DynamoDB: ~$1-2 (On-Demand)
- API Gateway: ~$1
- CloudWatch Logs: ~$0.5
- **合計: 約$4-6/月**

### コスト削減のヒント

1. CloudWatchログの保持期間を短縮
```hcl
log_retention_days = 3  # 3日に短縮
```

2. DynamoDB TTLを短く設定（コード内で調整）

3. Lambda同時実行数を制限（既に設定済み）

## セキュリティベストプラクティス

1. **最小権限の原則**: IAMロールは必要最小限の権限のみ付与
2. **暗号化**: SSM Parameter StoreでSecureString使用
3. **監査ログ**: CloudTrailでAPI呼び出しを記録
4. **定期的な更新**: 依存関係とLambdaランタイムの更新

## 参考リンク

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Slack API Documentation](https://api.slack.com/)
- [OpenAI API Documentation](https://platform.openai.com/docs/)