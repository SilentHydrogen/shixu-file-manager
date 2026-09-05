export interface LLMMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}
/** Wire protocol used by remote chat providers. */
export type LLMProtocol = 'auto' | 'chat_completions' | 'responses'
export interface LLMRequest {
  messages: LLMMessage[]
  model?: string
  protocol?: LLMProtocol
  maxTokens?: number
  temperature?: number
  stream?: boolean
}
export interface LLMResponse {
  content: string
  tokens: number
  finishReason: string
  model: string
}
export interface FileAnalysisResult {
  summary: string
  keywords: string[]
  category: string
  suggestedCategory?: string
  confidence?: number
  reason?: string
  insufficientContent?: boolean
  sentiment?: string
}
export interface QAResult {
  answer: string
  relevantFiles: RelevantFile[]
  confidence: number
}
export interface RelevantFile {
  fileId: number
  fileName: string
  similarity: number
  snippet: string
  chunkIndex?: number
}
export interface RelevantContext {
  name: string
  content: string
}
