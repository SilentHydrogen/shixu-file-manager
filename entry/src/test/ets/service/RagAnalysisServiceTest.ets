// entry/src/test/ets/service/RagAnalysisServiceTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { RagAnalysisService } from '../../../main/ets/service/RagAnalysisService'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'
import common from '@ohos.app.ability.common'

export default function ragAnalysisServiceTest() {
  describe('RagAnalysisService', () => {
    let service: RagAnalysisService
    let fileRepo: FileRepository
    let testFileId: number

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext() as common.UIAbilityContext)
      service = new RagAnalysisService()
      fileRepo = new FileRepository()

      // 初始化服务
      await service.initialize()

      // 创建测试文件
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test-doc.pdf'
      fileInfo.name = 'Machine Learning Tutorial'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 2048
      fileInfo.path = '/data/test-doc.pdf'
      fileInfo.createdTime = Date.now()
      fileInfo.modifiedTime = Date.now()
      testFileId = await fileRepo.insert(fileInfo)
    })

    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM file_embeddings')
    })

    it('should process file and generate embedding', 0, async () => {
      await service.processFile(testFileId)

      const file = await fileRepo.findById(testFileId)
      expect(file).assertInstanceOf("Object")
      expect(file!.isProcessed).assertTrue()
      expect(file!.contentSummary).assertInstanceOf("Object")
    })

    it('should perform semantic search', 0, async () => {
      // 处理文件
      await service.processFile(testFileId)

      // 搜索
      const results = await service.search('machine learning', 5)

      expect(results.length).assertLarger(0)
      expect(results[0].file.id).assertEqual(testFileId)
      expect(results[0].score).assertLarger(0)
    })
  })
}
