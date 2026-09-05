// entry/src/test/ets/data/FileRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'
import common from '@ohos.app.ability.common'

export default function fileRepositoryTest() {
  describe('FileRepository', () => {
    let repository: FileRepository

    beforeAll(async () => {
      // 确保数据库已初始化
      await DatabaseManager.getInstance().init(getContext() as common.UIAbilityContext)
      repository = new FileRepository()
    })

    afterEach(async () => {
      // 清理测试数据
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM files')
    })

    it('should insert file and return id', 0, async () => {
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test.pdf'
      fileInfo.name = 'test.pdf'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 1024
      fileInfo.path = '/data/test.pdf'
      fileInfo.createdTime = Date.now()
      fileInfo.modifiedTime = Date.now()

      const fileId = await repository.insert(fileInfo)
      expect(fileId).assertLarger(0)
    })

    it('should find file by uri', 0, async () => {
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test.pdf'
      fileInfo.name = 'test.pdf'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 1024
      fileInfo.path = '/data/test.pdf'
      fileInfo.createdTime = Date.now()
      fileInfo.modifiedTime = Date.now()

      await repository.insert(fileInfo)
      const found = await repository.findByUri('file://test.pdf')

      expect(found).assertInstanceOf("Object")
      expect(found!.name).assertEqual('test.pdf')
    })

    it('should find unprocessed files', 0, async () => {
      const file1 = new FileInfo()
      file1.uri = 'file://test1.pdf'
      file1.name = 'test1.pdf'
      file1.type = 'application/pdf'
      file1.size = 1024
      file1.path = '/data/test1.pdf'
      file1.createdTime = Date.now()
      file1.modifiedTime = Date.now()

      const file2 = new FileInfo()
      file2.uri = 'file://test2.pdf'
      file2.name = 'test2.pdf'
      file2.type = 'application/pdf'
      file2.size = 2048
      file2.path = '/data/test2.pdf'
      file2.createdTime = Date.now()
      file2.modifiedTime = Date.now()

      await repository.insert(file1)
      await repository.insert(file2)

      const unprocessed = await repository.findUnprocessed()
      expect(unprocessed.length).assertEqual(2)
    })

    it('should mark file as processed', 0, async () => {
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test.pdf'
      fileInfo.name = 'test.pdf'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 1024
      fileInfo.path = '/data/test.pdf'
      fileInfo.createdTime = Date.now()
      fileInfo.modifiedTime = Date.now()

      const fileId = await repository.insert(fileInfo)
      await repository.markAsProcessed(fileId)

      const updated = await repository.findById(fileId)
      expect(updated!.isProcessed).assertTrue()
      expect(updated!.processedTime).assertLarger(0)
    })

    it('should update content summary', 0, async () => {
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test.pdf'
      fileInfo.name = 'test.pdf'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 1024
      fileInfo.path = '/data/test.pdf'
      fileInfo.createdTime = Date.now()
      fileInfo.modifiedTime = Date.now()

      const fileId = await repository.insert(fileInfo)
      await repository.updateContentSummary(fileId, 'This is a test document', ['test', 'document'])

      const updated = await repository.findById(fileId)
      expect(updated!.contentSummary).assertEqual('This is a test document')
      expect(updated!.extractedKeywords!.length).assertEqual(2)
    })

    it('should count unprocessed files', 0, async () => {
      const file1 = new FileInfo()
      file1.uri = 'file://test1.pdf'
      file1.name = 'test1.pdf'
      file1.type = 'application/pdf'
      file1.size = 1024
      file1.path = '/data/test1.pdf'
      file1.createdTime = Date.now()
      file1.modifiedTime = Date.now()

      await repository.insert(file1)
      const count = await repository.countUnprocessed()
      expect(count).assertEqual(1)
    })
  })
}
