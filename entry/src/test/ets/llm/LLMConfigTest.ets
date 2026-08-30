// entry/src/test/ets/llm/LLMConfigTest.ets

import { describe, it, expect } from '@ohos/hypium'
import { LLMConfigManager, DEFAULT_LLM_CONFIG } from '../../../main/ets/llm/LLMConfig'

export default function llmConfigTest() {
  describe('LLMConfigManager', () => {
    it('should be singleton', 0, () => {
      const instance1 = LLMConfigManager.getInstance()
      const instance2 = LLMConfigManager.getInstance()
      expect(instance1).assertEqual(instance2)
    })

    it('should have default config', 0, () => {
      const manager = LLMConfigManager.getInstance()
      const config = manager.getConfig()

      expect(config.model).assertEqual(DEFAULT_LLM_CONFIG.model)
      expect(config.maxTokens).assertEqual(DEFAULT_LLM_CONFIG.maxTokens)
      expect(config.temperature).assertEqual(DEFAULT_LLM_CONFIG.temperature)
    })

    it('should update config', 0, () => {
      const manager = LLMConfigManager.getInstance()

      manager.updateConfig({
        apiKey: 'new-test-key',
        model: 'gpt-4',
        maxTokens: 4000
      })

      const config = manager.getConfig()
      expect(config.apiKey).assertEqual('new-test-key')
      expect(config.model).assertEqual('gpt-4')
      expect(config.maxTokens).assertEqual(4000)
    })

    it('should check if configured', 0, () => {
      const manager = LLMConfigManager.getInstance()

      manager.updateConfig({ apiKey: '' })
      expect(manager.isConfigured()).assertEqual(false)

      manager.updateConfig({ apiKey: 'test-key' })
      expect(manager.isConfigured()).assertEqual(true)
    })
  })
}
