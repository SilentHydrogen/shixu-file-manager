import { describe, it, expect } from '@ohos/hypium'
import { parseFileAnalysis } from '../../../main/ets/llm/LLMResponseParser'

export default function llmResponseParserTest() {
  describe('LLMResponseParser', () => {
    it('parses structured JSON', 0, () => {
      const result = parseFileAnalysis('{"summary":"摘要","keywords":["合同"],"suggestedCategory":"工作","confidence":0.8,"reason":"命中","insufficientContent":false}')
      expect(result.suggestedCategory).assertEqual('工作')
      expect(result.confidence).assertEqual(0.8)
    })
    it('rejects incomplete JSON', 0, () => {
      try {
        parseFileAnalysis('{"summary":"摘要"}')
        expect(false).assertTrue()
      } catch (error) {
        expect(true).assertTrue()
      }
    })
  })
}
