import { describe, it, expect } from '@ohos/hypium'
import { chunkText, limitLeadingText } from '../../../main/ets/llm/RagTextUtils'

export default function ragTextUtilsTest() {
  describe('RagTextUtils', () => {
    it('limits leading content', 0, () => {
      expect(limitLeadingText('a'.repeat(10000), 0.2, 8000).length).assertEqual(2000)
    })
    it('chunks with overlap', 0, () => {
      const chunks: string[] = chunkText('0123456789'.repeat(80), 256, 32, 32)
      expect(chunks.length).assertLarger(1)
      expect(chunks[1].substring(0, 32)).assertEqual(chunks[0].substring(224))
    })
  })
}
