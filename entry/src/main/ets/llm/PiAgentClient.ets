import { runAgent, cancelRun } from '@shixu/pi-agent-harmony'
import { LLMConfig } from './LLMConfig'
import { LLMRequest, LLMResponse, LLMMessage } from './LLMTypes'

interface ClassificationRequest { messages: LLMMessage[]; categories: string[]; maxTokens: number }

/** SDK owns provider protocols, response parsing and the tool loop. */
export class PiAgentClient {
  private config: LLMConfig
  private classificationRun: string = ''
  constructor(config: LLMConfig) { this.config = config }
  async chat(request: LLMRequest): Promise<LLMResponse> {
    const raw = await runAgent(JSON.stringify(this.config), JSON.stringify(request), `chat-${Date.now()}-${Math.random()}`)
    return JSON.parse(raw) as LLMResponse
  }
  async classify(messages: LLMMessage[], categories: string[], execute: (argumentsJson: string) => Promise<string>): Promise<void> {
    const request: ClassificationRequest = { messages, categories, maxTokens: this.config.maxTokens }
    this.classificationRun = `classification-${Date.now()}`
    try { await runAgent(JSON.stringify(this.config), JSON.stringify(request), this.classificationRun, execute) }
    finally { this.classificationRun = '' }
  }
  cancelClassification(): void { if (this.classificationRun.length > 0) cancelRun(this.classificationRun) }
}
