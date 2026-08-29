import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { RagAnalysisLogRepository } from '../../../main/ets/data/repository/RagAnalysisLogRepository'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function ragAnalysisLogRepositoryTest() {
  describe('RagAnalysisLogRepository', () => {
    let repository: RagAnalysisLogRepository

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      repository = new RagAnalysisLogRepository()
    })

    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM rag_analysis_logs')
    })

    it('should create log with running status', async () => {
      const logId = await repository.createLog('batch-001', 10)
      expect(logId).assertLarger(0)

      const log = await repository.findById(logId)
      expect(log).assertNotNull()
      expect(log!.status).assertEqual('running')
      expect(log!.fileCount).assertEqual(10)
    })

    it('should update log status to completed', async () => {
      const logId = await repository.createLog('batch-002', 5)
      const endTime = Date.now()

      await repository.updateStatus(logId, 'completed', endTime, 1500)

      const log = await repository.findById(logId)
      expect(log!.status).assertEqual('completed')
      expect(log!.endTime).assertEqual(endTime)
      expect(log!.llmTokensUsed).assertEqual(1500)
    })

    it('should update log status to failed with error', async () => {
      const logId = await repository.createLog('batch-003', 8)
      const endTime = Date.now()

      await repository.updateStatus(logId, 'failed', endTime, undefined, 'Network error')

      const log = await repository.findById(logId)
      expect(log!.status).assertEqual('failed')
      expect(log!.errorMessage).assertEqual('Network error')
    })

    it('should find recent logs', async () => {
      await repository.createLog('batch-001', 5)
      await repository.createLog('batch-002', 10)
      await repository.createLog('batch-003', 15)

      const recent = await repository.findRecent(2)
      expect(recent.length).assertEqual(2)
      // 最新的在前
      expect(recent[0].batchId).assertEqual('batch-003')
      expect(recent[1].batchId).assertEqual('batch-002')
    })

    it('should calculate total tokens used', async () => {
      const log1Id = await repository.createLog('batch-001', 5)
      const log2Id = await repository.createLog('batch-002', 10)

      await repository.updateStatus(log1Id, 'completed', Date.now(), 1000)
      await repository.updateStatus(log2Id, 'completed', Date.now(), 1500)

      const total = await repository.getTotalTokensUsed()
      expect(total).assertEqual(2500)
    })

    it('should calculate tokens used since time', async () => {
      const now = Date.now()
      const log1Id = await repository.createLog('batch-001', 5)

      // 模拟旧日志
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql(
        'UPDATE rag_analysis_logs SET start_time = ?, llm_tokens_used = 500 WHERE id = ?',
        [(now - 10000).toString(), log1Id.toString()]
      )

      // 新日志
      const log2Id = await repository.createLog('batch-002', 10)
      await repository.updateStatus(log2Id, 'completed', Date.now(), 1500)

      const total = await repository.getTotalTokensUsed(now - 5000)
      expect(total).assertEqual(1500) // 只统计新日志
    })

    it('should get statistics', async () => {
      const log1Id = await repository.createLog('batch-001', 10)
      const log2Id = await repository.createLog('batch-002', 20)
      const log3Id = await repository.createLog('batch-003', 15)

      await repository.updateStatus(log1Id, 'completed', Date.now(), 1000)
      await repository.updateStatus(log2Id, 'completed', Date.now(), 2000)
      await repository.updateStatus(log3Id, 'failed', Date.now(), undefined, 'Error')

      const stats = await repository.getStatistics()
      expect(stats.totalBatches).assertEqual(3)
      expect(stats.totalFiles).assertEqual(45)
      expect(stats.totalTokens).assertEqual(3000)
      expect(stats.successRate).assertClose(66.67, 0.1) // 2/3 * 100
    })

    it('should delete old logs', async () => {
      const now = Date.now()
      const log1Id = await repository.createLog('batch-old', 5)

      // 设置为 40 天前
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql(
        'UPDATE rag_analysis_logs SET start_time = ? WHERE id = ?',
        [(now - 40 * 24 * 60 * 60 * 1000).toString(), log1Id.toString()]
      )

      await repository.createLog('batch-new', 10)

      const deletedCount = await repository.deleteOlderThan(30)
      expect(deletedCount).assertEqual(1)

      const remaining = await repository.findRecent()
      expect(remaining.length).assertEqual(1)
      expect(remaining[0].batchId).assertEqual('batch-new')
    })
  })
}
