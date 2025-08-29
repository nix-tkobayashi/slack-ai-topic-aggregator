/**
 * EventBridgeのスケジュール式から分単位の間隔を抽出
 * @param {string} scheduleExpression - rate(X minutes) or rate(X hours) format
 * @returns {number} 分単位の間隔
 */
export function parseScheduleToMinutes(scheduleExpression) {
  // デフォルト値
  const defaultMinutes = 5;
  
  if (!scheduleExpression) {
    return defaultMinutes;
  }
  
  // rate(X minutes) パターン
  const minutesMatch = scheduleExpression.match(/rate\((\d+)\s*minutes?\)/i);
  if (minutesMatch) {
    return parseInt(minutesMatch[1], 10);
  }
  
  // rate(X hours) パターン
  const hoursMatch = scheduleExpression.match(/rate\((\d+)\s*hours?\)/i);
  if (hoursMatch) {
    return parseInt(hoursMatch[1], 10) * 60;
  }
  
  // rate(X days) パターン
  const daysMatch = scheduleExpression.match(/rate\((\d+)\s*days?\)/i);
  if (daysMatch) {
    return parseInt(daysMatch[1], 10) * 60 * 24;
  }
  
  // cron式の場合やパースできない場合はデフォルト値
  console.warn(`Unable to parse schedule expression: ${scheduleExpression}, using default ${defaultMinutes} minutes`);
  return defaultMinutes;
}