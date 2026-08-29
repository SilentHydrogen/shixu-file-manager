import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { VectorStorageTierRepository } from '../../../main/ets/data/repository/VectorStorageTierRepository'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'

export default function vectorStorageTierRepositoryTest() {
  describe('VectorStorageTierRepository', () => {
    let repository: VectorStorageTierRepository
    let fileRepository: FileRepository
    let testFileId: number

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      repository = new VectorStorageTierRepository()
      fileRepository = new FileRepository()

      // 创建测试文件
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      testFileId = await fileRepository.insert(fileInfo)
    })

    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM vector_storage_tiers')
    })

    it('should set file tier', async () => {
      await repository.setTier(testFileId, 'hot')
      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('hot')
    })

    it('should update existing tier', async () => {
      await repository.setTier(testFileId, 'hot')
      await repository.setTier(testFileId, 'cold')

      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('cold')
    })

    it('should find files by tier', async () => {
      await repository.setTier(testFileId, 'hot')

      const hotFiles = await repository.findByTier('hot')
      expect(hotFiles.length).assertEqual(1)
      expect(hotFiles[0].fileId).assertEqual(testFileId)

      const coldFiles = await repository.findByTier('cold')
      expect(coldFiles.length).assertEqual(0)
    })

    it('should update access time and count', async () => {
      await repository.setTier(testFileId, 'hot')

      const before = await repository.findByTier('hot')
      const initialCount = before[0].accessCount

      await repository.updateAccessTime(testFileId)

      const after = await repository.findByTier('hot')
      expect(after[0].accessCount).assertEqual(initialCount + 1)
      expect(after[0].lastAccessed).assertLarger(before[0].lastAccessed)
    })

    it('should find cold candidates', async () => {
      // 设置一个很旧的访问时间
      await repository.setTier(testFileId, 'hot')

      const store = await DatabaseManager.getInstance().getStore()
      const oldTime = Date.now() - (40 * 24 * 60 * 60 * 1000) // 40 天前
      await store.executeSql(
        'UPDATE vector_storage_tiers SET last_accessed = ? WHERE file_id = ?',
        [oldTime.toString(), testFileId.toString()]
      )

      const candidates = await repository.findColdCandidates(30)
      expect(candidates.length).assertEqual(1)
      expect(candidates[0]).assertEqual(testFileId)
    })

    it('should demote to cold in batch', async () => {
      await repository.setTier(testFileId, 'hot')
      await repository.demoteToCold([testFileId])

      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('cold')
    })

    it('should promote to hot in batch', async () => {
      await repository.setTier(testFileId, 'cold')
      await repository.promoteToHot([testFileId])

      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('hot')
    })

    it('should get storage stats', async () => {
      const file2 = new FileInfo({
        uri: 'file://test2.pdf',
        name: 'test2.pdf',
        type: 'application/pdf',
        size: 2048,
        path: '/data/test2.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      const file2Id = await fileRepository.insert(file2)

      await repository.setTier(testFileId, 'hot')
      await repository.setTier(file2Id, 'cold')

      const stats = await repository.getStats()
      expect(stats.hotCount).assertEqual(1)
      expect(stats.coldCount).assertEqual(1)
    })
  })
}
