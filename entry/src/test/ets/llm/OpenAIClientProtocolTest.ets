import { describe, it, expect } from '@ohos/hypium'
import { resolveLLMEndpoint } from '../../../main/ets/llm/OpenAIClient'

export default function openAIClientProtocolTest() {
  describe('OpenAIClientProtocol', () => {
    it('builds Responses endpoint from provider base URL', 0, () => {
      expect(resolveLLMEndpoint('https://api.deepseek.com/', 'responses')).assertEqual('https://api.deepseek.com/responses')
      expect(resolveLLMEndpoint('https://api.deepseek.com/v1', 'responses')).assertEqual('https://api.deepseek.com/v1/responses')
    })
    it('keeps explicit endpoint without duplicate suffix', 0, () => {
      expect(resolveLLMEndpoint('https://gateway.example/v1/responses', 'responses')).assertEqual('https://gateway.example/v1/responses')
      expect(resolveLLMEndpoint('https://gateway.example/v1/chat/completions', 'chat_completions')).assertEqual('https://gateway.example/v1/chat/completions')
    })
    it('rejects conflicting explicit protocol and endpoint', 0, () => {
      let rejected: boolean = false
      try { resolveLLMEndpoint('https://gateway.example/v1/responses/', 'chat_completions') }
      catch (error) { rejected = true }
      expect(rejected).assertTrue()
    })
  })
}
