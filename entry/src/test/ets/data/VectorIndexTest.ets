import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { VectorIndex } from '../../../main/ets/data/vector/VectorIndex'
import { VectorStore } from '../../../main/ets/data/vector/VectorStore'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function vectorIndexTest() {
  describe('VectorIndex', () => {
    let index: VectorIndex
    let store: VectorStore

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      index = new VectorIndex()
      store = new VectorStore()
    })

    afterEach(async () => {
      const dbStore = await DatabaseManager.getInstance().getStore()
      await dbStore.executeSql('DELETE FROM file_embeddings')
    })

    it('should build index from stored embeddings', async () => {
      // 准备测试数据
      await store.saveEmbedding(1, [0.1, 0.2, 0.3])
      await store.saveEmbedding(2, [0.4, 0.5, 0.6])

      // 构建索引
      await index.build()

      const stats = index.getStats()
      expect(stats.totalVectors).assertEqual(2)
      expect(stats.dimension).assertEqual(3)
    })

    it('should find most similar vectors', async () => {
      // 添加测试向量
      await store.saveEmbedding(1, [1.0, 0.0, 0.0])
      await store.saveEmbedding(2, [0.0, 1.0, 0.0])
      await store.saveEmbedding(3, [0.9, 0.1, 0.0])

      await index.build()

      // 查询与 [1, 0, 0] 最相似的向量
      const queryVector = [1.0, 0.0, 0.0]
      const results = await index.search(queryVector, 2)

      expect(results.length).assertEqual(2)
      expect(results[0].fileId).assertEqual(1) // 完全匹配
      expect(results[1].fileId).assertEqual(3) // 次相似
    })

    it('should add and remove vectors from index', async () => {
      await index.build()

      index.addToIndex(100, [0.5, 0.5, 0.0])
      let stats = index.getStats()
      expect(stats.totalVectors).assertEqual(1)

      index.removeFromIndex(100)
      stats = index.getStats()
      expect(stats.totalVectors).assertEqual(0)
    })
  })
}
