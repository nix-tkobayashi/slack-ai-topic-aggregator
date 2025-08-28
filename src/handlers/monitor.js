import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { WebClient } from '@slack/web-api';

const dynamodb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const ssm = new SSMClient({});

// SSMパラメータから実際の値を取得
async function getParameterValue(paramPath) {
  if (paramPath.startsWith('ssm:')) {
    const paramName = '/' + paramPath.substring(4);
    const command = new GetParameterCommand({ Name: paramName, WithDecryption: true });
    const response = await ssm.send(command);
    return response.Parameter.Value;
  }
  return paramPath;
}

// Slack clientは後で初期化
let slack;

/**
 * 簡易的なAI関連チェック（事前フィルタ用）
 * OpenAIでの判定前の軽量な事前フィルタ
 * 明らかにAI関連でないものだけを除外し、疑わしいものは全て収集
 */
function quickAICheck(text) {
  if (!text) return false;
  
  // 非常に緩いチェック - 疑わしいものは通す
  // 短い単語は単語境界でチェック、長い単語は部分一致OK
  const strictKeywords = ['ai', 'gpt', 'llm'];
  const flexibleKeywords = ['claude', '機械学習', '人工知能', 'chatgpt', 'openai', 'gemini', 'anthropic'];
  const lowerText = text.toLowerCase();
  
  // 厳密なキーワード（単語境界でチェック）
  const hasStrict = strictKeywords.some(keyword => {
    const pattern = new RegExp(`(?<![a-z0-9])${keyword}(?![a-z0-9])`, 'i');
    return pattern.test(lowerText);
  });
  
  // 柔軟なキーワード（部分一致OK）
  const hasFlexible = flexibleKeywords.some(keyword => lowerText.includes(keyword));
  
  return hasStrict || hasFlexible;
}

/**
 * 定期的に全チャンネルを監視
 */
export const handler = async (event) => {
  console.log('Starting channel monitoring...');
  
  // SSMからトークンと設定を取得
  const botToken = await getParameterValue(process.env.SLACK_BOT_TOKEN);
  const targetChannelId = await getParameterValue(process.env.TARGET_CHANNEL_ID);
  slack = new WebClient(botToken);
  
  const results = {
    processed: 0,
    found: 0,
    errors: [],
    channels_monitored: []
  };

  // Botが参加しているチャンネル一覧を取得
  let monitorChannels = [];
  try {
    // Bot自身の情報を取得
    const authResponse = await slack.auth.test();
    const botUserId = authResponse.user_id;
    
    // Botが参加している全チャンネルを取得
    let cursor;
    do {
      const response = await slack.conversations.list({
        exclude_archived: true,
        types: 'public_channel', // プライベートチャンネルは権限追加後に対応
        limit: 100,
        cursor: cursor
      });
      
      // Botがメンバーのチャンネルのみをフィルタ（要約送信先チャンネルは除外）
      const botChannels = response.channels.filter(channel => 
        channel.is_member && channel.id !== targetChannelId
      );
      
      monitorChannels = monitorChannels.concat(botChannels);
      cursor = response.response_metadata?.next_cursor;
    } while (cursor);
    
    console.log(`Bot is member of ${monitorChannels.length} channels (excluding target channel: ${targetChannelId})`);
    results.channels_monitored = monitorChannels.map(ch => ({
      id: ch.id,
      name: ch.name,
      is_private: ch.is_private
    }));
    
  } catch (error) {
    console.error('Error fetching bot channels:', error);
    results.errors.push({ error: 'Failed to fetch bot channels', message: error.message });
    return {
      statusCode: 500,
      body: JSON.stringify(results)
    };
  }

  // 5分前のタイムスタンプ
  const since = (Date.now() / 1000 - 300).toString();

  for (const channel of monitorChannels) {
    try {
      await processChannel(channel.id, since, results);
    } catch (error) {
      console.error(`Error processing channel ${channel.name} (${channel.id}):`, error);
      results.errors.push({ channel: channel.name, id: channel.id, error: error.message });
    }
  }

  console.log('Monitoring complete:', results);
  return {
    statusCode: 200,
    body: JSON.stringify(results)
  };
};

/**
 * チャンネルのメッセージを処理
 */
async function processChannel(channelId, since, results) {
  // チャンネル情報確認
  let channelInfo;
  try {
    channelInfo = await slack.conversations.info({ channel: channelId });
  } catch (error) {
    console.log(`Cannot access channel info for ${channelId}`);
    return;
  }

  // プライベートチャンネルでBot未参加の場合はスキップ
  if (channelInfo.channel.is_private && !channelInfo.channel.is_member) {
    console.log(`Skipping private channel ${channelId} (bot not member)`);
    return;
  }

  // メッセージ履歴取得
  let messages;
  try {
    const response = await slack.conversations.history({
      channel: channelId,
      oldest: since,
      limit: 100
    });
    messages = response.messages || [];
  } catch (error) {
    if (error.data?.error === 'not_in_channel') {
      console.log(`Bot not in channel ${channelId}, attempting public access...`);
      return;
    }
    throw error;
  }

  // 各メッセージを処理
  for (const message of messages) {
    if (message.type !== 'message' || message.subtype) continue;
    
    const messageId = `${channelId}-${message.ts}`;
    results.processed++;

    // 既に処理済みか確認
    const processed = await isProcessed(messageId);
    if (processed) {
      console.log(`Message ${messageId} already processed`);
      continue;
    }

    // 簡易的なキーワードチェック（軽量な事前フィルタ）
    // OpenAIでの判定コストを削減するため、明らかにAI関連でないものを除外
    const possiblyAIRelated = quickAICheck(message.text);
    
    // スレッドがある場合、スレッド内のメッセージも確認
    let threadMessages = [];
    let hasPossibleAIContentInThread = false;
    
    if (message.thread_ts && message.reply_count > 0) {
      try {
        const threadResponse = await slack.conversations.replies({
          channel: channelId,
          ts: message.thread_ts,
          limit: 100
        });
        
        if (threadResponse.messages) {
          // 最初のメッセージは親メッセージなのでスキップ
          threadMessages = threadResponse.messages.slice(1);
          
          // スレッド内に可能性のあるAI関連コンテンツがあるか確認
          for (const reply of threadMessages) {
            if (quickAICheck(reply.text)) {
              hasPossibleAIContentInThread = true;
              break;
            }
          }
        }
      } catch (error) {
        console.error(`Error fetching thread for ${message.thread_ts}:`, error);
      }
    }
    
    // 明らかにAI関連でない場合のみスキップ（疑わしいものは全て収集）
    // 実際のAI判定はサマリー生成時にOpenAIが行う
    if (!possiblyAIRelated && !hasPossibleAIContentInThread) continue;

    // ユーザー情報取得（メインメッセージ）
    let userName = 'Unknown';
    try {
      const userInfo = await slack.users.info({ user: message.user });
      userName = userInfo.user?.real_name || userInfo.user?.name || 'Unknown';
    } catch (error) {
      console.error('Error fetching user info:', error);
    }

    // メインメッセージを保存（AI判定は後でOpenAIが行う）
    await saveMessage({
      channel: channelId,
      message: message,
      userName: userName,
      relevanceScore: 0.5, // 暫定スコア（OpenAIで正確に判定）
      threadMessages: threadMessages // スレッドメッセージも含める
    });
    
    // スレッド内の各メッセージも保存
    for (const reply of threadMessages) {
      const replyId = `${channelId}-${reply.ts}`;
      
      // 既に処理済みか確認
      if (await isProcessed(replyId)) {
        continue;
      }
      
      // ユーザー情報取得
      let replyUserName = 'Unknown';
      try {
        const userInfo = await slack.users.info({ user: reply.user });
        replyUserName = userInfo.user?.real_name || userInfo.user?.name || 'Unknown';
      } catch (error) {
        console.error('Error fetching reply user info:', error);
      }
      
      // スレッドの返信として保存
      await saveMessage({
        channel: channelId,
        message: reply,
        userName: replyUserName,
        relevanceScore: 0.5, // 暫定スコア（OpenAIで正確に判定）
        isThreadReply: true,
        threadTs: message.thread_ts
      });
    }

    results.found++;
    console.log(`Found potentially AI-related message: ${messageId} (thread replies: ${threadMessages.length})`);
  }
}

/**
 * メッセージが処理済みか確認
 */
async function isProcessed(messageId) {
  try {
    const response = await dynamodb.send(new GetCommand({
      TableName: process.env.PROCESSED_TABLE,
      Key: { message_id: messageId }
    }));
    return !!response.Item;
  } catch (error) {
    console.error('Error checking processed status:', error);
    return false;
  }
}

/**
 * メッセージをDynamoDBに保存
 */
async function saveMessage({ channel, message, userName, relevanceScore, isThreadReply = false, threadTs = null, threadMessages = [] }) {
  const item = {
    PK: `CHANNEL#${channel}`,
    SK: `MSG#${message.ts}`,
    message_id: `${channel}-${message.ts}`,
    channel_id: channel,
    timestamp: parseFloat(message.ts),
    text: message.text,
    user: message.user,
    user_name: userName,
    relevance_score: relevanceScore,
    is_thread_reply: isThreadReply,
    thread_ts: threadTs || message.thread_ts,
    reply_count: message.reply_count || 0,
    detected_at: new Date().toISOString(),
    ttl: Math.floor(Date.now() / 1000) + 604800 // 7日後に自動削除
  };

  // メッセージ保存
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
}