import OpenAI from 'openai';

let openai;

/**
 * OpenAIを使用してメッセージのAI関連度を分析し、要約を生成
 * @param {Array} threads - スレッドごとにグループ化されたメッセージ
 * @param {string} channelId - チャンネルID
 * @returns {Object} - { isAIRelated, summaries }
 */
export async function analyzeAndSummarizeThreads(threads, channelId) {
  // OpenAIクライアントを初期化
  if (!openai && process.env.OPENAI_API_KEY) {
    openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY
    });
  }
  
  if (!openai) {
    console.error('OpenAI client not initialized');
    return { isAIRelated: false, summaries: [] };
  }
  
  const results = [];
  
  for (const thread of threads) {
    const threadContent = formatThreadContent(thread);
    
    try {
      const response = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content: `あなたはSlackメッセージ分析の専門家です。
以下のタスクを実行してください：
1. メッセージがAI/機械学習関連の話題かを判定
2. AI関連の場合のみ、議論の要約を生成

AI関連の話題の例：
- AIツール（ChatGPT、Claude、Copilot等）の使用方法や体験
- 機械学習・深層学習の技術的な議論
- AI企業やサービスのニュース
- プロンプトエンジニアリング
- AI倫理や影響に関する議論

AI関連でない話題の例：
- tail、mail等のコマンド（aiが含まれるだけ）
- 一般的なプログラミングの話題
- AI関連キーワードが文脈なく偶然含まれる場合`
          },
          {
            role: "user",
            content: `以下のスレッドを分析してください：

${threadContent}

必ず最初の行に以下のどちらかを記載してください：
AI関連:true
または
AI関連:false

AI関連:trueの場合は、2行目以降に以下の形式で要約を記載してください：
📝 要点: [議論の内容を1-2文で説明]
💡 ポイント:
• [重要な点1]
• [重要な点2]
• [重要な点3]
🔗 参考リンク: (もしあれば)
• [URL1]
• [URL2]`
          }
        ],
        max_tokens: 500,
        temperature: 0.3
      });
      
      const responseText = response.choices[0].message.content;
      const lines = responseText.split('\n');
      
      // 最初の行でAI関連かどうかを判定
      const isAIRelated = lines[0].includes('AI関連:true');
      
      if (isAIRelated) {
        // 2行目以降から要約を抽出
        const summaryContent = lines.slice(1).join('\n').trim();
        
        results.push({
          threadUrl: thread.threadUrl,
          messageCount: thread.messages.length,
          summary: summaryContent,
          urls: thread.urls // 元のURLも保持
        });
      }
      
    } catch (error) {
      console.error('Error analyzing thread:', error);
      // フォールバック: 従来のキーワード検出を使用
      if (hasAIKeywords(threadContent)) {
        results.push({
          threadUrl: thread.threadUrl,
          messageCount: thread.messages.length,
          summary: "分析エラーのため要約を生成できませんでした",
          keyPoints: [],
          urls: thread.urls,
          confidence: 0.5
        });
      }
    }
  }
  
  return {
    isAIRelated: results.length > 0,
    summaries: results
  };
}

/**
 * スレッドの内容をフォーマット
 */
function formatThreadContent(thread) {
  return thread.messages.map(msg => {
    const timestamp = new Date(msg.timestamp * 1000).toLocaleString('ja-JP');
    return `[${timestamp}] ${msg.user_name || 'Unknown'}: ${msg.text}`;
  }).join('\n');
}

/**
 * 簡易的なキーワードチェック（フォールバック用）
 */
function hasAIKeywords(text) {
  const keywords = [
    'ai', 'gpt', 'chatgpt', 'claude', 'llm', '人工知能', '機械学習',
    'deep learning', 'neural network', 'openai', 'anthropic'
  ];
  
  const lowerText = text.toLowerCase();
  return keywords.some(keyword => {
    if (keyword.length <= 3) {
      // 短いキーワードは厳密にチェック
      return new RegExp(`(?<![a-z0-9])${keyword}(?![a-z0-9])`, 'i').test(lowerText);
    } else {
      // 長いキーワードは通常の単語境界
      return new RegExp(`\\b${keyword}\\b`, 'i').test(lowerText);
    }
  });
}

/**
 * 要約をSlack用にフォーマット
 */
export function formatSummariesForSlack(summaries) {
  if (summaries.length === 0) {
    return "AI関連の話題はありませんでした。";
  }
  
  let formatted = `📊 *AI関連スレッドの要約* (${summaries.length}スレッド)\n\n`;
  
  summaries.forEach((thread, index) => {
    formatted += `━━━━━━━━━━━━━━━━━━━━━━\n`;
    formatted += `*スレッド ${index + 1}* | 💬 ${thread.messageCount}件のメッセージ\n`;
    formatted += `🔗 <${thread.threadUrl}|スレッドを表示>\n\n`;
    formatted += thread.summary;
    formatted += '\n\n';
  });
  
  return formatted;
}