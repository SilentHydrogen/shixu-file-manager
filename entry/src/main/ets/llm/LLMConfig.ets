import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'
import { decryptSecret, deleteSecret, encryptSecret } from './LLMSecretStore'

export interface LLMConfig {
  apiKey: string
  baseURL: string
  model: string
  maxTokens: number
  temperature: number
}

export const DEFAULT_LLM_CONFIG: LLMConfig = {
  apiKey: '',
  baseURL: 'https://api.openai.com/v1',
  model: 'gpt-3.5-turbo',
  maxTokens: 2000,
  temperature: 0.7
}

const PREFERENCES_NAME: string = 'llm_config'
const CONFIG_KEY: string = 'config'
const API_KEY_KEY: string = 'apiKeyEncrypted'

interface StoredLLMConfig {
  baseURL: string
  model: string
  maxTokens: number
  temperature: number
}

function cloneConfig(config: LLMConfig): LLMConfig {
  return {
    apiKey: config.apiKey,
    baseURL: config.baseURL,
    model: config.model,
    maxTokens: config.maxTokens,
    temperature: config.temperature
  }
}

export class LLMConfigManager {
  private static instance: LLMConfigManager
  private config: LLMConfig = cloneConfig(DEFAULT_LLM_CONFIG)

  private constructor() {}

  static getInstance(): LLMConfigManager {
    if (LLMConfigManager.instance === undefined) {
      LLMConfigManager.instance = new LLMConfigManager()
    }
    return LLMConfigManager.instance
  }

  getConfig(): LLMConfig {
    return cloneConfig(this.config)
  }

  updateConfig(config: Partial<LLMConfig>): void {
    this.config = {
      apiKey: config.apiKey === undefined ? this.config.apiKey : config.apiKey.trim(),
      baseURL: config.baseURL === undefined ? this.config.baseURL : this.normalizeBaseUrl(config.baseURL),
      model: config.model === undefined ? this.config.model : config.model.trim(),
      maxTokens: config.maxTokens === undefined ? this.config.maxTokens : config.maxTokens,
      temperature: config.temperature === undefined ? this.config.temperature : config.temperature
    }
  }

  isConfigured(): boolean {
    return this.config.apiKey.trim().length > 0
  }

  async load(context: common.UIAbilityContext): Promise<void> {
    const store = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME })
    const savedConfig: Object = store.getSync(CONFIG_KEY, '{}') as Object
    if (typeof savedConfig === 'string') {
      try {
        const values: Record<string, Object> = JSON.parse(savedConfig) as Record<string, Object>
        this.updateConfig({
          baseURL: typeof values.baseURL === 'string' ? values.baseURL as string : DEFAULT_LLM_CONFIG.baseURL,
          model: typeof values.model === 'string' ? values.model as string : DEFAULT_LLM_CONFIG.model,
          maxTokens: typeof values.maxTokens === 'number' ? values.maxTokens as number : DEFAULT_LLM_CONFIG.maxTokens,
          temperature: typeof values.temperature === 'number' ? values.temperature as number : DEFAULT_LLM_CONFIG.temperature
        })
      } catch (error) {
        this.config = cloneConfig(DEFAULT_LLM_CONFIG)
      }
    }
    const encrypted: Object = store.getSync(API_KEY_KEY, '') as Object
    if (typeof encrypted === 'string' && encrypted.length > 0) {
      try {
        this.config.apiKey = await decryptSecret(encrypted)
      } catch (error) {
        this.config.apiKey = ''
      }
    }
  }

  async persist(context: common.UIAbilityContext): Promise<void> {
    const store = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME })
    const nonSecret: StoredLLMConfig = {
      baseURL: this.config.baseURL,
      model: this.config.model,
      maxTokens: this.config.maxTokens,
      temperature: this.config.temperature
    }
    store.putSync(CONFIG_KEY, JSON.stringify(nonSecret))
    if (this.config.apiKey.trim().length === 0) {
      store.deleteSync(API_KEY_KEY)
      try {
        await deleteSecret()
      } catch (error) {
        // Missing HUKS key is already equivalent to a cleared key.
      }
    } else {
      const encrypted: string = await encryptSecret(this.config.apiKey)
      store.putSync(API_KEY_KEY, encrypted)
    }
    await store.flush()
  }

  async clearApiKey(context: common.UIAbilityContext): Promise<void> {
    this.config.apiKey = ''
    await this.persist(context)
  }

  private normalizeBaseUrl(value: string): string {
    const trimmed: string = value.trim()
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed
  }
}
