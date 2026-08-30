// entry/src/main/ets/llm/LLMService.ets

import { LLMConfigManager } from './LLMConfig'
import { OpenAIClient } from './OpenAIClient'
import { LLMRequest, LLMResponse, EmbeddingRequest, EmbeddingResponse, LLMMessage } from './LLMTypes'
import { PromptTemplates } from './PromptTemplates'

/**
 * LLM 服务
 */
export class LLMService {
  private static instance: LLMService
  private client: OpenAIClient | null = null

  private constructor() {
    this.initializeClient()
  }

  static getInstance(): LLMService {
    if (!LLMService.instance) {
      LLMService.instance = new LLMService()
    }
    return LLMService.instance
  }

  private initializeClient(): void {
    const config = LLMConfigManager.getInstance().getConfig()
    if (config.apiKey) {
      this.client = new OpenAIClient(config)
    }
  }

  /**
   * 重新初始化客户端（配置更新后调用）
   */
  reinitialize(): void {
    this.initializeClient()
  }

  /**
   * 检查是否已配置
   */
  isConfigured(): boolean {
    return this.client !== null
  }

  /**
   * 生成文本
   */
  async generate(request: LLMRequest): Promise<LLMResponse> {
    if (!this.client) {
      throw new Error('LLM service is not configured. Please set API key first.')
    }

    return await this.client.chat(request)
  }

  /**
   * 生成文本嵌入向量
   */
  async generateEmbedding(text: string): Promise<number[]> {
    if (!this.client) {
      throw new Error('LLM service is not configured. Please set API key first.')
    }

    const request: EmbeddingRequest = {
      input: text
    }

    const response = await this.client.createEmbedding(request)
    return response.embeddings[0]
  }

  /**
   * 批量生成文本嵌入向量
   */
  async batchGenerateEmbeddings(texts: string[]): Promise<number[][]> {
    if (!this.client) {
      throw new Error('LLM service is not configured. Please set API key first.')
    }

    const request: EmbeddingRequest = {
      input: texts
    }

    const response = await this.client.createEmbedding(request)
    return response.embeddings
  }

  /**
   * 生成文件摘要
   */
  async summarizeFile(fileName: string, fileType: string, content: string): Promise<string> {
    const messages: LLMMessage[] = [
      {
        role: 'system',
        content: PromptTemplates.systemPrompt()
      },
      {
        role: 'user',
        content: PromptTemplates.fileSummary(fileName, fileType, content)
      }
    ]

    const response = await this.generate({ messages })
    return response.content.trim()
  }

  /**
   * 提取关键词
   */
  async extractKeywords(content: string): Promise<string[]> {
    const messages: LLMMessage[] = [
      {
        role: 'system',
        content: PromptTemplates.systemPrompt()
      },
      {
        role: 'user',
        content: PromptTemplates.extractKeywords(content)
      }
    ]

    const response = await this.generate({ messages })
    const keywordsStr = response.content.trim()
    return keywordsStr.split(/[,，]/).map(kw => kw.trim()).filter(kw => kw.length > 0)
  }

  /**
   * 文件分类
   */
  async categorizeFile(fileName: string, content: string): Promise<string> {
    const messages: LLMMessage[] = [
      {
        role: 'system',
        content: PromptTemplates.systemPrompt()
      },
      {
        role: 'user',
        content: PromptTemplates.categorizeFile(fileName, content)
      }
    ]

    const response = await this.generate({ messages })
    return response.content.trim()
  }

  /**
   * RAG 问答
   */
  async answerQuestion(
    question: string,
    relevantFiles: Array<{ name: string, content: string }>
  ): Promise<string> {
    const messages: LLMMessage[] = [
      {
        role: 'system',
        content: PromptTemplates.systemPrompt()
      },
      {
        role: 'user',
        content: PromptTemplates.ragQA(question, relevantFiles)
      }
    ]

    const response = await this.generate({ messages })
    return response.content.trim()
  }
}
