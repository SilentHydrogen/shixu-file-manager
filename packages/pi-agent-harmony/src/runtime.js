import './platform.js';
import { Agent } from '@mariozechner/pi-agent-core/dist/agent.js';
import { streamSimpleOpenAIResponses } from '@mariozechner/pi-ai/openai-responses';
import { streamSimpleOpenAICompletions } from '@mariozechner/pi-ai/openai-completions';

const active = new Map();
export function cancelRun(id) { active.get(id)?.abort(); }

function resolveModel(config) {
  const endpoint = config.baseURL.trim().replace(/\/+$/, '');
  const protocol = config.protocol === 'auto' ? (endpoint.endsWith('/responses') ? 'responses' : 'chat_completions') : config.protocol;
  if (!/^https?:\/\/[^\s/?#]+(?:\/[^\s?#]*)?$/.test(endpoint)) throw new Error('请输入有效的 HTTP 或 HTTPS API 地址');
  if ((endpoint.endsWith('/responses') && protocol !== 'responses') ||
    (endpoint.endsWith('/chat/completions') && protocol !== 'chat_completions')) throw new Error('API 地址与协议不一致');
  return { id: config.model, name: config.model, api: protocol === 'responses' ? 'openai-responses' : 'openai-completions',
    provider: 'shixu-custom', baseUrl: endpoint.replace(/\/(responses|chat\/completions)$/, ''),
    reasoning: false, input: ['text'], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 32768, maxTokens: config.maxTokens || 2000,
    compat: { supportsStore: false, supportsDeveloperRole: false, supportsReasoningEffort: false,
      maxTokensField: 'max_tokens', supportsUsageInStreaming: true } };
}
function safeFailure(message = '') {
  const code = message.match(/(?:\bHTTP\s*)?\b(401|403|404|429|500|502|503|504)\b/)?.[1];
  const labels = { 401: '鉴权失败，请检查 API Key', 403: '访问被拒绝，请检查模型权限', 404: '接口或模型不存在，请检查地址和协议',
    429: '请求受限，请检查额度或稍后重试' };
  if (code) return `${labels[code] || '提供商暂时不可用'}（HTTP ${code}）`;
  for (const phrase of ['请求已取消', '提供商响应超时', '无法连接提供商', '域名解析失败', '证书校验失败']) if (message.includes(phrase)) return phrase;
  return '模型请求失败，请检查提供商协议、模型和网络；服务需支持标准流式接口';
}

/** JSON here is an ArkTS/JavaScript application boundary, never a provider response format. */
export async function runAgent(configJson, requestJson, runId, toolHandler) {
  const config = JSON.parse(configJson), request = JSON.parse(requestJson);
  const model = resolveModel({ ...config, ...request, model: request.model || config.model });
  const protocol = model.api === 'openai-responses' ? streamSimpleOpenAIResponses : streamSimpleOpenAICompletions;
  const systemPrompt = request.messages.filter(m => m.role === 'system').map(m => m.content).join('\n');
  const messages = request.messages.filter(m => m.role !== 'system').map(m => m.role === 'user'
    ? { role: 'user', content: m.content, timestamp: Date.now() }
    : { role: 'assistant', content: [{ type: 'text', text: m.content }], api: model.api, provider: model.provider, model: model.id,
      usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: model.cost }, stopReason: 'stop', timestamp: Date.now() });
  const tools = toolHandler ? [{ name: 'classify_file', label: '归类当前文件',
    description: '调用应用内部分类接口：高置信度时归类，证据不足或规则冲突时创建待确认建议。仅处理当前文件。',
    parameters: { type: 'object', additionalProperties: false,
      properties: { category: { type: 'string', enum: request.categories }, confidence: { type: 'number', minimum: 0, maximum: 1 },
        reason: { type: 'string' }, insufficientContent: { type: 'boolean' } },
      required: ['category', 'confidence', 'reason', 'insufficientContent'] },
    execute: async (_id, args) => ({ content: [{ type: 'text', text: await toolHandler(JSON.stringify(args)) }], details: {}, terminate: true }) }] : [];
  let turns = 0, toolSucceeded = false;
  const agent = new Agent({ toolExecution: 'sequential', initialState: { model, systemPrompt, tools, messages: messages.slice(0, -1) },
    streamFn: (selected, context, options) => protocol(selected, context, { ...options, apiKey: config.apiKey,
      maxTokens: request.maxTokens || config.maxTokens, temperature: request.temperature ?? config.temperature,
      cacheRetention: 'none', maxRetries: 0, timeoutMs: 60000, maxRetryDelayMs: 0 }) });
  agent.subscribe(event => {
    if (event.type === 'tool_execution_end' && !event.isError) toolSucceeded = true;
    if (event.type === 'turn_end' && ++turns >= 3) agent.abort();
  });
  active.set(runId, agent);
  const timeout = setTimeout(() => agent.abort(), 85000);
  try {
    const last = messages[messages.length - 1];
    if (!last || last.role !== 'user') throw new Error('请求缺少用户消息');
    await agent.prompt(last);
    const reply = [...agent.state.messages].reverse().find(m => m.role === 'assistant');
    if (!toolSucceeded && (!reply || reply.stopReason === 'error' || reply.stopReason === 'aborted')) {
      throw new Error(safeFailure(reply?.errorMessage || agent.state.errorMessage));
    }
    const content = reply?.content.filter(p => p.type === 'text').map(p => p.text).join('') || '';
    if (!toolHandler && !content.trim()) throw new Error('模型未返回正文，请检查协议或增加输出 Tokens');
    return JSON.stringify({ content, tokens: reply?.usage?.totalTokens || 0, finishReason: reply?.stopReason || 'stop', model: model.id });
  } finally { clearTimeout(timeout); active.delete(runId); }
}
