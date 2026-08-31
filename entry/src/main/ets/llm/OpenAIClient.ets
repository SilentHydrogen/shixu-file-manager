import http from '@ohos.net.http'
import { LLMConfig } from './LLMConfig'
import { LLMRequest, LLMResponse, LLMMessage } from './LLMTypes'

interface OpenAIMessage {
  content?: string
}

interface OpenAIChoice {
  message?: OpenAIMessage
  finish_reason?: string
}

interface OpenAIUsage {
  total_tokens?: number
}

interface OpenAIChatResponse {
  model?: string
  choices?: OpenAIChoice[]
  usage?: OpenAIUsage
}

interface ChatRequestBody {
  model: string
  messages: LLMMessage[]
  max_tokens: number
  temperature: number
  stream: boolean
}

export class OpenAIClient {
  private config: LLMConfig

  constructor(config: LLMConfig) {
    this.config = {
      apiKey: config.apiKey,
      baseURL: config.baseURL,
      model: config.model,
      maxTokens: config.maxTokens,
      temperature: config.temperature
    }
  }

  async chat(request: LLMRequest): Promise<LLMResponse> {
    const httpRequest = http.createHttp()
    try {
      const requestBody: ChatRequestBody = {
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
          connectTimeout: 30000,
          readTimeout: 60000
        }
      )
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`LLM request failed with status ${response.responseCode}`)
      }
      const result: OpenAIChatResponse = JSON.parse(response.result as string) as OpenAIChatResponse
      const choice = result.choices === undefined ? undefined : result.choices[0]
      const content: string | undefined = choice?.message?.content
      if (content === undefined) {
        throw new Error('LLM response did not contain message content')
      }
      return {
        content: content,
        tokens: result.usage?.total_tokens ?? 0,
        finishReason: choice?.finish_reason ?? 'stop',
        model: result.model ?? this.config.model
      }
    } catch (error) {
      if (error instanceof Error) {
        throw error
      }
      throw new Error('LLM request failed')
    } finally {
      httpRequest.destroy()
    }
  }
}
