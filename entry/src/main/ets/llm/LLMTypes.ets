// entry/src/main/ets/llm/LLMTypes.ets

/**
 * LLM 请求消息
 */
export interface LLMMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

/**
 * LLM 请求参数
 */
export interface LLMRequest {
  messages: LLMMessage[]
  model?: string
  maxTokens?: number
  temperature?: number
  stream?: boolean
}

/**
 * LLM 响应
 */
export interface LLMResponse {
  content: string
  tokens: number
  finishReason: string
  model: string
}

/**
 * Embedding 请求
 */
export interface EmbeddingRequest {
  input: string | string[]
  model?: string
}

/**
 * Embedding 响应
 */
export interface EmbeddingResponse {
  embeddings: number[][]
  model: string
  tokens: number
}

/**
 * 文件分析结果
 */
export interface FileAnalysisResult {
  summary: string
  keywords: string[]
  category: string
  sentiment?: string
}

/**
 * 问答结果
 */
export interface QAResult {
  answer: string
  relevantFiles: RelevantFile[]
  confidence: number
}

/**
 * 相关文件信息
 */
export interface RelevantFile {
  fileId: number
  fileName: string
  similarity: number
  snippet: string
}
