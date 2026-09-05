import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { VectorStorageTierRepository } from '../../../main/ets/data/repository/VectorStorageTierRepository'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import common from '@ohos.app.ability.common'

export default function vectorStorageTierRepositoryTest() {
  describe('VectorStorageTierRepository', () => {
    let repository: VectorStorageTierRepository
    let fileRepository: FileRepository
    let testFileId: number

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext() as common.UIAbilityContext)
      repository = new VectorStorageTierRepository()
      fileRepository = new FileRepository()

      // 创建测试文件
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test.pdf'
      fileInfo.name = 'test.pdf'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 1024
      fileInfo.path = '/data/test.pdf'
      fileInfo.createdTime = Date.now()
      fileInfo.modifiedTime = Date.now()
      testFileId = await fileRepository.insert(fileInfo)
    })

    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM vector_storage_tiers')
    })

    it('should set file tier', 0, async () => {
      await repository.setTier(testFileId, 'hot')
      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('hot')
    })

    it('should update existing tier', 0, async () => {
      await repository.setTier(testFileId, 'hot')
      await repository.setTier(testFileId, 'cold')

      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('cold')
    })

    it('should find files by tier', 0, async () => {
      await repository.setTier(testFileId, 'hot')

      const hotFiles = await repository.findByTier('hot')
      expect(hotFiles.length).assertEqual(1)
      expect(hotFiles[0].fileId).assertEqual(testFileId)

      const coldFiles = await repository.findByTier('cold')
      expect(coldFiles.length).assertEqual(0)
    })

    it('should update access time and count', 0, async () => {
      await repository.setTier(testFileId, 'hot')

      const before = await repository.findByTier('hot')
      const initialCount = before[0].accessCount

      await repository.updateAccessTime(testFileId)

      const after = await repository.findByTier('hot')
      expect(after[0].accessCount).assertEqual(initialCount + 1)
      expect(after[0].lastAccessed).assertLarger(before[0].lastAccessed)
    })

    it('should find cold candidates', 0, async () => {
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

    it('should demote to cold in batch', 0, async () => {
      await repository.setTier(testFileId, 'hot')
      await repository.demoteToCold([testFileId])

      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('cold')
    })

    it('should promote to hot in batch', 0, async () => {
      await repository.setTier(testFileId, 'cold')
      await repository.promoteToHot([testFileId])

      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('hot')
    })

    it('should get storage stats', 0, async () => {
      const file2 = new FileInfo()
      file2.uri = 'file://test2.pdf'
      file2.name = 'test2.pdf'
      file2.type = 'application/pdf'
      file2.size = 2048
      file2.path = '/data/test2.pdf'
      file2.createdTime = Date.now()
      file2.modifiedTime = Date.now()
      const file2Id = await fileRepository.insert(file2)

      await repository.setTier(testFileId, 'hot')
      await repository.setTier(file2Id, 'cold')

      const stats = await repository.getStats()
      expect(stats.hotCount).assertEqual(1)
      expect(stats.coldCount).assertEqual(1)
    })
  })
}
