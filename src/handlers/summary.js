import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, DeleteCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { WebClient } from '@slack/web-api';
import { analyzeAndSummarizeThreads, formatSummariesForSlack } from '../services/aiAnalyzer.js';

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
 * 定期要約を生成して送信
 */
export const handler = async (event) => {
  console.log('Starting summary generation...');
  
  // SSMからパラメータを取得
  const botToken = await getParameterValue(process.env.SLACK_BOT_TOKEN);
  slack = new WebClient(botToken);
  
  // OpenAI APIキーも設定
  const openaiKey = await getParameterValue(process.env.OPENAI_API_KEY);
  if (openaiKey) {
    process.env.OPENAI_API_KEY = openaiKey;
  }
  
  const targetChannel = await getParameterValue(process.env.TARGET_CHANNEL_ID);
  const results = {
    summaries_sent: 0,
    total_messages: 0,
    errors: [],
    channels_processed: []
  };

  // Botが参加しているチャンネル一覧を取得（要約送信先は除外）
  let monitorChannels = [];
  try {
    let cursor;
    do {
      const response = await slack.conversations.list({
        exclude_archived: true,
        types: 'public_channel', // プライベートチャンネルは権限追加後に対応
        limit: 100,
        cursor: cursor
      });
      
      const botChannels = response.channels.filter(channel => 
        channel.is_member && channel.id !== targetChannel
      );
      
      monitorChannels = monitorChannels.concat(botChannels);
      cursor = response.response_metadata?.next_cursor;
    } while (cursor);
    
    console.log(`Found ${monitorChannels.length} channels to summarize (excluding target channel: ${targetChannel})`);
  } catch (error) {
    console.error('Error fetching bot channels:', error);
    results.errors.push({ error: 'Failed to fetch channels', message: error.message });
    return {
      statusCode: 500,
      body: JSON.stringify(results)
    };
  }

  // 各チャンネルの要約を生成
  for (const channel of monitorChannels) {
    try {
      const messages = await getChannelMessages(channel.id);
      
      if (messages.length === 0) {
        console.log(`No messages found for channel ${channel.name} (${channel.id})`);
        continue;
      }

      results.total_messages += messages.length;
      
      // メッセージをスレッドごとにグループ化
      const threads = groupMessagesByThread(messages);
      
      // OpenAIでAI関連度を判定し、AI関連のスレッドのみ要約を生成
      const analysisResult = await analyzeAndSummarizeThreads(threads, channel.id);
      
      if (!analysisResult.isAIRelated) {
        console.log(`No AI-related content found in channel ${channel.name} (${channel.id})`);
        continue;
      }
      
      results.channels_processed.push({
        id: channel.id,
        name: channel.name,
        message_count: messages.length,
        ai_threads: analysisResult.summaries.length
      });

      // AI関連スレッドの要約をSlackに送信
      const formattedMessage = formatSummariesForSlack(analysisResult.summaries);
      await slack.chat.postMessage({
        channel: targetChannel,
        text: formattedMessage,
        mrkdwn: true
      });

      console.log(`Summary sent for channel ${channel.name}: ${analysisResult.summaries.length} AI-related threads`);
      results.summaries_sent++;

      // 要約したメッセージを削除して次回重複しないようにする
      await markMessagesAsSummarized(channel.id, messages);
    } catch (error) {
      console.error(`Error processing channel ${channel.name} (${channel.id}):`, error);
      results.errors.push({ channel: channel.name, id: channel.id, error: error.message });
    }
  }

  console.log('Summary generation complete:', results);
  return {
    statusCode: 200,
    body: JSON.stringify(results)
  };
};

/**
 * チャンネルのメッセージを取得
 */
async function getChannelMessages(channelId) {
  const messages = [];
  let lastEvaluatedKey = undefined;

  do {
    const params = {
      TableName: process.env.MESSAGES_TABLE,
      KeyConditionExpression: 'PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `CHANNEL#${channelId}`
      },
      Limit: 100
    };

    if (lastEvaluatedKey) {
      params.ExclusiveStartKey = lastEvaluatedKey;
    }

    const response = await dynamodb.send(new QueryCommand(params));
    
    if (response.Items) {
      messages.push(...response.Items);
    }
    
    lastEvaluatedKey = response.LastEvaluatedKey;
  } while (lastEvaluatedKey);

  // タイムスタンプでソート
  messages.sort((a, b) => a.timestamp - b.timestamp);
  
  return messages;
}

/**
 * メッセージをスレッドごとにグループ化
 */
function groupMessagesByThread(messages) {
  const threads = new Map();
  
  messages.forEach(msg => {
    // スレッドのキーを決定（thread_tsがある場合はそれを、ない場合はメッセージのts）
    const threadKey = msg.thread_ts || msg.SK?.replace('MSG#', '');
    
    if (!threads.has(threadKey)) {
      threads.set(threadKey, {
        messages: [],
        threadUrl: null,
        urls: new Set()
      });
    }
    
    const thread = threads.get(threadKey);
    thread.messages.push(msg);
    
    // URLを抽出（Slack形式のURLも処理）
    const slackUrlRegex = /<(https?:\/\/[^|>]+)(?:\|[^>]+)?>/g;
    const normalUrlRegex = /(https?:\/\/[^\s<>]+)/gi;
    
    let match;
    while ((match = slackUrlRegex.exec(msg.text)) !== null) {
      thread.urls.add(match[1]);
    }
    
    const textWithoutSlackUrls = msg.text.replace(slackUrlRegex, '');
    const normalUrls = textWithoutSlackUrls.match(normalUrlRegex) || [];
    normalUrls.forEach(url => thread.urls.add(url));
    
    // スレッドURLを設定
    if (!thread.threadUrl) {
      const threadTs = threadKey.replace('.', '');
      thread.threadUrl = `https://slack.com/archives/${msg.channel_id}/p${threadTs}`;
    }
  });
  
  // Map to Array
  return Array.from(threads.values()).map(thread => ({
    messages: thread.messages.sort((a, b) => a.timestamp - b.timestamp),
    threadUrl: thread.threadUrl,
    urls: Array.from(thread.urls)
  }));
}

/**
 * 要約済みメッセージをマーク（削除して重複防止）
 */
async function markMessagesAsSummarized(channelId, messages) {
  // 要約済みメッセージを削除
  for (const message of messages) {
    await dynamodb.send(new DeleteCommand({
      TableName: process.env.MESSAGES_TABLE,
      Key: {
        PK: message.PK,
        SK: message.SK
      }
    }));
    
    // 要約済みマーカーを追加（オプション：履歴保持したい場合）
    await dynamodb.send(new PutCommand({
      TableName: process.env.PROCESSED_TABLE,
      Item: {
        message_id: `summarized_${message.message_id}`,
        summarized_at: new Date().toISOString(),
        channel_id: channelId,
        ttl: Math.floor(Date.now() / 1000) + 2592000 // 30日後に削除
      }
    }));
  }
  
  console.log(`Marked ${messages.length} messages as summarized for channel ${channelId}`);
}