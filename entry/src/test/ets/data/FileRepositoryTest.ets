// entry/src/test/ets/data/FileRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function fileRepositoryTest() {
  describe('FileRepository', () => {
    let repository: FileRepository

    beforeAll(async () => {
      // 确保数据库已初始化
      await DatabaseManager.getInstance().init(getContext())
      repository = new FileRepository()
    })

    afterEach(async () => {
      // 清理测试数据
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM files')
    })

    it('should insert file and return id', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      const fileId = await repository.insert(fileInfo)
      expect(fileId).assertLarger(0)
    })

    it('should find file by uri', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      await repository.insert(fileInfo)
      const found = await repository.findByUri('file://test.pdf')

      expect(found).assertNotNull()
      expect(found!.name).assertEqual('test.pdf')
    })

    it('should find unprocessed files', async () => {
      const file1 = new FileInfo({
        uri: 'file://test1.pdf',
        name: 'test1.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test1.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      const file2 = new FileInfo({
        uri: 'file://test2.pdf',
        name: 'test2.pdf',
        type: 'application/pdf',
        size: 2048,
        path: '/data/test2.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      await repository.insert(file1)
      await repository.insert(file2)

      const unprocessed = await repository.findUnprocessed()
      expect(unprocessed.length).assertEqual(2)
    })

    it('should mark file as processed', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      const fileId = await repository.insert(fileInfo)
      await repository.markAsProcessed(fileId)

      const updated = await repository.findById(fileId)
      expect(updated!.isProcessed).assertTrue()
      expect(updated!.processedTime).assertLarger(0)
    })

    it('should update content summary', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      const fileId = await repository.insert(fileInfo)
      await repository.updateContentSummary(fileId, 'This is a test document', ['test', 'document'])

      const updated = await repository.findById(fileId)
      expect(updated!.contentSummary).assertEqual('This is a test document')
      expect(updated!.extractedKeywords!.length).assertEqual(2)
    })

    it('should count unprocessed files', async () => {
      const file1 = new FileInfo({
        uri: 'file://test1.pdf',
        name: 'test1.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test1.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      await repository.insert(file1)
      const count = await repository.countUnprocessed()
      expect(count).assertEqual(1)
    })
  })
}
