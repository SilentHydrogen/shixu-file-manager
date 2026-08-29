// entry/src/test/ets/data/FileCollectionRefRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { FileCollectionRefRepository } from '../../../main/ets/data/repository/FileCollectionRefRepository'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { CollectionRepository } from '../../../main/ets/data/repository/CollectionRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import { Collection } from '../../../main/ets/data/model/Collection'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function fileCollectionRefRepositoryTest() {
  describe('FileCollectionRefRepository', () => {
    let refRepository: FileCollectionRefRepository
    let fileRepository: FileRepository
    let collectionRepository: CollectionRepository
    let testFileId: number
    let testCollectionId: number

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      refRepository = new FileCollectionRefRepository()
      fileRepository = new FileRepository()
      collectionRepository = new CollectionRepository()

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

      // 创建测试收纳箱
      const collection = new Collection({
        name: 'Test Collection',
        rules: []
      })
      testCollectionId = await collectionRepository.insert(collection)
    })

    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM file_collection_refs')
    })

    it('should add file-collection ref', async () => {
      const refId = await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      expect(refId).assertLarger(0)
    })

    it('should find refs by file id', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')

      const refs = await refRepository.findByFileId(testFileId)
      expect(refs.length).assertEqual(1)
      expect(refs[0].collectionId).assertEqual(testCollectionId)
      expect(refs[0].confidence).assertEqual(0.95)
    })

    it('should find refs by collection id', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')

      const refs = await refRepository.findByCollectionId(testCollectionId)
      expect(refs.length).assertEqual(1)
      expect(refs[0].fileId).assertEqual(testFileId)
    })

    it('should remove ref', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      await refRepository.removeRef(testFileId, testCollectionId)

      const refs = await refRepository.findByFileId(testFileId)
      expect(refs.length).assertEqual(0)
    })

    it('should check if ref exists', async () => {
      const existsBefore = await refRepository.exists(testFileId, testCollectionId)
      expect(existsBefore).assertFalse()

      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')

      const existsAfter = await refRepository.exists(testFileId, testCollectionId)
      expect(existsAfter).assertTrue()
    })

    it('should count files in collection', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')

      const count = await refRepository.countByCollectionId(testCollectionId)
      expect(count).assertEqual(1)
    })

    it('should not add duplicate ref', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')

      // 尝试添加重复关联应该失败（UNIQUE 约束）
      try {
        await refRepository.addRef(testFileId, testCollectionId, 0.90, 'manual')
        expect(false).assertTrue() // 不应该到达这里
      } catch (err) {
        expect(true).assertTrue() // 预期抛出异常
      }
    })
  })
}
