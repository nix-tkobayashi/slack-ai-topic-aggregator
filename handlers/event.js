import crypto from 'crypto';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { isAIRelated } from '../services/aiDetector.js';
import { WebClient } from '@slack/web-api';

const dynamodb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const slack = new WebClient(process.env.SLACK_BOT_TOKEN);

/**
 * Slack Event APIからのWebhookを処理
 */
export const handler = async (event) => {
  console.log('Received event:', JSON.stringify(event, null, 2));

  try {
    // Slack署名検証
    if (!verifySlackSignature(event)) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Invalid signature' })
      };
    }

    const body = JSON.parse(event.body);

    // URL Verification Challenge対応
    if (body.type === 'url_verification') {
      return {
        statusCode: 200,
        body: JSON.stringify({ challenge: body.challenge })
      };
    }

    // イベントの処理
    if (body.type === 'event_callback') {
      const slackEvent = body.event;
      
      // メッセージイベントのみ処理
      if (slackEvent.type === 'message' && !slackEvent.subtype) {
        await processMessage(slackEvent);
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ ok: true })
    };
  } catch (error) {
    console.error('Error processing event:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};

/**
 * Slackからの署名を検証
 */
function verifySlackSignature(event) {
  const signature = event.headers['x-slack-signature'];
  const timestamp = event.headers['x-slack-request-timestamp'];
  const body = event.body;

  // タイムスタンプが5分以上古い場合は拒否
  const currentTime = Math.floor(Date.now() / 1000);
  if (Math.abs(currentTime - timestamp) > 300) {
    return false;
  }

  const sigBasestring = `v0:${timestamp}:${body}`;
  const mySignature = 'v0=' + crypto
    .createHmac('sha256', process.env.SLACK_SIGNING_SECRET)
    .update(sigBasestring)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(mySignature),
    Buffer.from(signature)
  );
}

/**
 * メッセージを処理してDynamoDBに保存
 */
async function processMessage(message) {
  // モニタリング対象チャンネルか確認
  const monitorChannels = process.env.MONITOR_CHANNELS.split(',');
  if (!monitorChannels.includes(message.channel)) {
    console.log(`Channel ${message.channel} is not monitored`);
    return;
  }

  // AI関連度チェック
  const relevanceScore = isAIRelated(message.text);
  if (relevanceScore < 0.3) {
    console.log('Message is not AI-related');
    return;
  }

  // ユーザー情報取得
  let userName = 'Unknown';
  try {
    const userInfo = await slack.users.info({ user: message.user });
    userName = userInfo.user?.real_name || userInfo.user?.name || 'Unknown';
  } catch (error) {
    console.error('Error fetching user info:', error);
  }

  // DynamoDBに保存
  const item = {
    PK: `CHANNEL#${message.channel}`,
    SK: `MSG#${message.ts}`,
    message_id: `${message.channel}-${message.ts}`,
    channel_id: message.channel,
    timestamp: parseFloat(message.ts),
    text: message.text,
    user: message.user,
    user_name: userName,
    relevance_score: relevanceScore,
    detected_at: new Date().toISOString(),
    ttl: Math.floor(Date.now() / 1000) + 604800 // 7日後に自動削除
  };

  await dynamodb.send(new PutCommand({
    TableName: process.env.MESSAGES_TABLE,
    Item: item
  }));

  // 処理済みマーク
  await dynamodb.send(new PutCommand({
    TableName: process.env.PROCESSED_TABLE,
    Item: {
      message_id: item.message_id,
      processed_at: new Date().toISOString(),
      ttl: Math.floor(Date.now() / 1000) + 604800
    }
  }));

  console.log(`Saved AI-related message: ${item.message_id} (score: ${relevanceScore})`);
}