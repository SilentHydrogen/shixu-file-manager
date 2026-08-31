import { LLMConfigManager } from './LLMConfig'
import { OpenAIClient } from './OpenAIClient'
import { LLMRequest, LLMResponse, LLMMessage, RelevantContext } from './LLMTypes'
import { PromptTemplates } from './PromptTemplates'
import { parseFileAnalysis, StructuredFileAnalysis } from './LLMResponseParser'

export class LLMService {
  private static instance: LLMService
  private client: OpenAIClient | null = null

  private constructor() {
    this.initializeClient()
  }

  static getInstance(): LLMService {
    if (LLMService.instance === undefined) {
      LLMService.instance = new LLMService()
    }
    return LLMService.instance
  }

  private initializeClient(): void {
    const config = LLMConfigManager.getInstance().getConfig()
    this.client = config.apiKey.trim().length > 0 ? new OpenAIClient(config) : null
  }

  reinitialize(): void {
    this.initializeClient()
  }

  isConfigured(): boolean {
    return this.client !== null && LLMConfigManager.getInstance().isConfigured()
  }

  async testConnection(): Promise<void> {
    await this.generate({
      messages: [{ role: 'user', content: '请只回复：连接成功' }],
      maxTokens: 16,
      temperature: 0
    })
  }

  async generate(request: LLMRequest): Promise<LLMResponse> {
    if (this.client === null) {
      throw new Error('LLM service is not configured. Please set API key first.')
    }
    return await this.client.chat(request)
  }

  async summarizeFile(fileName: string, fileType: string, content: string): Promise<string> {
    const response: LLMResponse = await this.generate(this.requestWithUserPrompt(
      PromptTemplates.fileSummary(fileName, fileType, content)))
    return response.content.trim()
  }

  async extractKeywords(content: string): Promise<string[]> {
    const response: LLMResponse = await this.generate(this.requestWithUserPrompt(
      PromptTemplates.extractKeywords(content)))
    return response.content.trim().split(/[,，]/)
      .map((keyword: string) => keyword.trim())
      .filter((keyword: string) => keyword.length > 0)
  }

  async categorizeFile(fileName: string, content: string): Promise<string> {
    const response: LLMResponse = await this.generate(this.requestWithUserPrompt(
      PromptTemplates.categorizeFile(fileName, content)))
    return response.content.trim()
  }

  async analyzeFile(fileName: string, fileType: string, content: string, categories: string[]): Promise<StructuredFileAnalysis> {
    const response: LLMResponse = await this.generate(this.requestWithUserPrompt(
      PromptTemplates.analyzeFile(fileName, fileType, content, categories)))
    return parseFileAnalysis(response.content)
  }

  async answerQuestion(question: string, relevantFiles: RelevantContext[]): Promise<string> {
    const response: LLMResponse = await this.generate(this.requestWithUserPrompt(
      PromptTemplates.ragQA(question, relevantFiles)))
    return response.content.trim()
  }

  private requestWithUserPrompt(prompt: string): LLMRequest {
    const messages: LLMMessage[] = [
      { role: 'system', content: PromptTemplates.systemPrompt() },
      { role: 'user', content: prompt }
    ]
    return { messages: messages }
  }
}
