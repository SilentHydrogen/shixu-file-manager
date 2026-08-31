import { describe, it, expect } from '@ohos/hypium'
import { EmbeddingModel } from '../../../main/ets/ai/model/EmbeddingModel'

export default function embeddingModelTest() {
  describe('EmbeddingModel', () => {
    it('declares BGE output dimension and never returns fake vector', 0, async () => {
      const model = new EmbeddingModel()
      expect(model.getDimension()).assertEqual(512)
      try {
        await model.encode('本地测试')
        expect(false).assertTrue()
      } catch (error) {
        expect(model.isAvailable()).assertFalse()
      }
    })
  })
}
