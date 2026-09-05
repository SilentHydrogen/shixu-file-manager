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
      expect(config.protocol).assertEqual('auto')
    })

    it('should update config', 0, () => {
      const manager = LLMConfigManager.getInstance()

      manager.updateConfig({
        apiKey: '',
        model: 'gpt-4',
        protocol: 'responses',
        maxTokens: 4000
      })

      const config = manager.getConfig()
      expect(config.model).assertEqual('gpt-4')
      expect(config.maxTokens).assertEqual(4000)
      expect(config.protocol).assertEqual('responses')
    })

    it('should check if configured', 0, () => {
      const manager = LLMConfigManager.getInstance()

      manager.updateConfig({ apiKey: '' })
      expect(manager.isConfigured()).assertEqual(false)

      manager.updateConfig({ apiKey: ' ' })
      expect(manager.isConfigured()).assertEqual(false)
    })
  })
}
