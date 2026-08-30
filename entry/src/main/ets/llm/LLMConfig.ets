// entry/src/main/ets/llm/LLMConfig.ets

/**
 * LLM 配置接口
 */
export interface LLMConfig {
  apiKey: string
  baseURL?: string
  model: string
  maxTokens: number
  temperature: number
}

/**
 * 默认 LLM 配置
 */
export const DEFAULT_LLM_CONFIG: LLMConfig = {
  apiKey: '',
  baseURL: 'https://api.openai.com/v1',
  model: 'gpt-3.5-turbo',
  maxTokens: 2000,
  temperature: 0.7
}

/**
 * LLM 配置管理器
 */
export class LLMConfigManager {
  private static instance: LLMConfigManager
  private config: LLMConfig

  private constructor() {
    this.config = { ...DEFAULT_LLM_CONFIG }
  }

  static getInstance(): LLMConfigManager {
    if (!LLMConfigManager.instance) {
      LLMConfigManager.instance = new LLMConfigManager()
    }
    return LLMConfigManager.instance
  }

  getConfig(): LLMConfig {
    return { ...this.config }
  }

  updateConfig(config: Partial<LLMConfig>): void {
    this.config = {
      ...this.config,
      apiKey: config.apiKey ?? this.config.apiKey,
      baseURL: config.baseURL ?? this.config.baseURL,
      model: config.model ?? this.config.model,
      maxTokens: config.maxTokens ?? this.config.maxTokens,
      temperature: config.temperature ?? this.config.temperature
    }
  }

  isConfigured(): boolean {
    return this.config.apiKey !== ''
  }
}
