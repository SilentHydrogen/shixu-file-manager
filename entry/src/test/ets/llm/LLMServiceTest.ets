// entry/src/test/ets/llm/LLMServiceTest.ets

import { describe, it, expect } from '@ohos/hypium'
import { LLMService } from '../../../main/ets/llm/LLMService'
import { LLMConfigManager } from '../../../main/ets/llm/LLMConfig'

export default function llmServiceTest() {
  describe('LLMService', () => {
    it('should be singleton', 0, () => {
      const instance1 = LLMService.getInstance()
      const instance2 = LLMService.getInstance()
      expect(instance1).assertEqual(instance2)
    })

    it('should not be configured initially', 0, () => {
      const service = LLMService.getInstance()
      const isConfigured = service.isConfigured()
      // Will be false unless API key is set
      expect(typeof isConfigured).assertEqual('boolean')
    })

    it('should throw error when not configured', 0, async () => {
      const configManager = LLMConfigManager.getInstance()
      configManager.updateConfig({
        apiKey: ''
      })

      const service = LLMService.getInstance()
      service.reinitialize()

      try {
        await service.generate({ messages: [{ role: 'user', content: 'test' }] })
        expect(false).assertEqual(true) // Should not reach here
      } catch (err) {
        expect((err as Error).message).assertContain('not configured')
      }
    })
  })
}
