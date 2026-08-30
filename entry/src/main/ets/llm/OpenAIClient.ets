// entry/src/main/ets/llm/OpenAIClient.ets

import http from '@ohos.net.http'
import { LLMConfig } from './LLMConfig'
import { LLMRequest, LLMResponse, EmbeddingRequest, EmbeddingResponse } from './LLMTypes'

/**
 * OpenAI API 客户端
 */
export class OpenAIClient {
  private config: LLMConfig

  constructor(config: LLMConfig) {
    this.config = config
  }

  /**
   * 发送聊天完成请求
   */
  async chat(request: LLMRequest): Promise<LLMResponse> {
    const httpRequest = http.createHttp()

    try {
      const requestBody = {
        model: request.model ?? this.config.model,
        messages: request.messages,
        max_tokens: request.maxTokens ?? this.config.maxTokens,
        temperature: request.temperature ?? this.config.temperature,
        stream: false
      }

      const response = await httpRequest.request(
        `${this.config.baseURL}/chat/completions`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.config.apiKey}`
          },
          extraData: JSON.stringify(requestBody),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 60000,
          readTimeout: 60000
        }
      )

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as OpenAIChatResponse

        return {
          content: result.choices[0].message.content,
          tokens: result.usage.total_tokens,
          finishReason: result.choices[0].finish_reason,
          model: result.model
        }
      } else {
        throw new Error(`API request failed: ${response.responseCode}`)
      }
    } finally {
      httpRequest.destroy()
    }
  }

  /**
   * 生成文本嵌入向量
   */
  async createEmbedding(request: EmbeddingRequest): Promise<EmbeddingResponse> {
    const httpRequest = http.createHttp()

    try {
      const requestBody = {
        model: request.model ?? 'text-embedding-ada-002',
        input: request.input
      }

      const response = await httpRequest.request(
        `${this.config.baseURL}/embeddings`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.config.apiKey}`
          },
          extraData: JSON.stringify(requestBody),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 60000,
          readTimeout: 60000
        }
      )

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as OpenAIEmbeddingResponse

        return {
          embeddings: result.data.map(item => item.embedding),
          model: result.model,
          tokens: result.usage.total_tokens
        }
      } else {
        throw new Error(`API request failed: ${response.responseCode}`)
      }
    } finally {
      httpRequest.destroy()
    }
  }
}

/**
 * OpenAI Chat API 响应类型
 */
interface OpenAIChatResponse {
  id: string
  object: string
  created: number
  model: string
  choices: Array<{
    index: number
    message: {
      role: string
      content: string
    }
    finish_reason: string
  }>
  usage: {
    prompt_tokens: number
    completion_tokens: number
    total_tokens: number
  }
}

/**
 * OpenAI Embedding API 响应类型
 */
interface OpenAIEmbeddingResponse {
  object: string
  data: Array<{
    object: string
    embedding: number[]
    index: number
  }>
  model: string
  usage: {
    prompt_tokens: number
    total_tokens: number
  }
}
