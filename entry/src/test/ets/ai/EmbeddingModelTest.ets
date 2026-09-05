import { describe, it, expect } from '@ohos/hypium'
import { EmbeddingModel, tokenTensorData } from '../../../main/ets/ai/model/EmbeddingModel'
import { mindSporeLite } from '@kit.MindSporeLiteKit'

export default function embeddingModelTest() {
  describe('EmbeddingModel', () => {
    it('matches INT32 and INT64 tensor storage widths', 0, () => {
      const values: number[] = [101, 102]
      expect(tokenTensorData(values, mindSporeLite.DataType.NUMBER_TYPE_INT32).byteLength).assertEqual(8)
      expect(tokenTensorData(values, mindSporeLite.DataType.NUMBER_TYPE_INT64).byteLength).assertEqual(16)
    })
    it('declares BGE output dimension and requires ability context', 0, async () => {
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
