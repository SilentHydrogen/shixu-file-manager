import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { RagAnalysisLog, LogStatus } from '../model/RagAnalysisLog'

interface RagStatistics {
  totalBatches: number
  totalFiles: number
  totalTokens: number
  successRate: number
  avgDuration: number
}

export class RagAnalysisLogRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }

  /**
   * 创建分析日志
   */
  async createLog(batchId: string, fileCount: number): Promise<number> {
    const log = new RagAnalysisLog()
    log.batchId = batchId
    log.fileCount = fileCount
    log.status = 'running'

    const store = await this.getStore()
    const values = log.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS, values)
  }

  /**
   * 更新日志状态
   */
  async updateStatus(
    logId: number,
    status: LogStatus,
    endTime?: number,
    tokensUsed?: number,
    errorMessage?: string
  ): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.equalTo('id', logId)

    const values: relationalStore.ValuesBucket = {
      status: status
    }

    if (endTime) values.end_time = endTime
    if (tokensUsed) values.llm_tokens_used = tokensUsed
    if (errorMessage) values.error_message = errorMessage

    await store.update(values, predicates)
  }

  /**
   * 根据 ID 查询日志
   */
  async findById(id: number): Promise<RagAnalysisLog | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.equalTo('id', id)

    const resultSet = await store.query(predicates)

    try {
      if (resultSet.goToFirstRow()) {
        const rowData = this.resultSetToObject(resultSet)
        return RagAnalysisLog.fromRow(rowData)
      }
      return null
    } finally {
      resultSet.close()
    }
  }

  /**
   * 查询最近的日志
   */
  async findRecent(limit: number = 20): Promise<RagAnalysisLog[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.orderByDesc('start_time')
    predicates.limitAs(limit)

    const resultSet = await store.query(predicates)
    const logs: RagAnalysisLog[] = []

    try {
      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        logs.push(RagAnalysisLog.fromRow(rowData))
      }
      return logs
    } finally {
      resultSet.close()
    }
  }

  /**
   * 统计总 Token 消耗
   */
  async getTotalTokensUsed(sinceTime?: number): Promise<number> {
    const store = await this.getStore()
    let sql = `SELECT SUM(llm_tokens_used) as total FROM ${DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS} WHERE llm_tokens_used IS NOT NULL`
    const args: string[] = []

    if (sinceTime) {
      sql += ' AND start_time >= ?'
      args.push(sinceTime.toString())
    }

    const resultSet = await store.querySql(sql, args)

    try {
      if (resultSet.goToFirstRow()) {
        const total = resultSet.getLong(0)
        return total
      }
      return 0
    } finally {
      resultSet.close()
    }
  }

  /**
   * 获取统计信息
   */
  async getStatistics(sinceTime?: number): Promise<RagStatistics> {
    const store = await this.getStore()
    let sql = `
      SELECT
        COUNT(*) as total_batches,
        COALESCE(SUM(file_count), 0) as total_files,
        COALESCE(SUM(llm_tokens_used), 0) as total_tokens,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
        AVG(CASE WHEN end_time IS NOT NULL THEN end_time - start_time ELSE NULL END) as avg_duration
      FROM ${DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS}
    `
    const args: string[] = []

    if (sinceTime) {
      sql += ' WHERE start_time >= ?'
      args.push(sinceTime.toString())
    }

    const resultSet = await store.querySql(sql, args)

    try {
      if (resultSet.goToFirstRow()) {
        const totalBatches = resultSet.getLong(0)
        const totalFiles = resultSet.getLong(1)
        const totalTokens = resultSet.getLong(2)
        const completed = resultSet.getLong(3)
        const avgDuration = resultSet.isColumnNull(4) ? 0 : resultSet.getDouble(4)

        const successRate = totalBatches > 0 ? (completed / totalBatches) * 100 : 0

        const stats: RagStatistics = {
          totalBatches,
          totalFiles,
          totalTokens,
          successRate,
          avgDuration
        }
        return stats
      }

      const emptyStats: RagStatistics = {
        totalBatches: 0,
        totalFiles: 0,
        totalTokens: 0,
        successRate: 0,
        avgDuration: 0
      }
      return emptyStats
    } finally {
      resultSet.close()
    }
  }

  /**
   * 删除旧日志
   */
  async deleteOlderThan(days: number): Promise<number> {
    const store = await this.getStore()
    const threshold = Date.now() - (days * 24 * 60 * 60 * 1000)

    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.lessThan('start_time', threshold)

    return await store.delete(predicates)
  }

  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
  private resultSetToObject(resultSet: relationalStore.ResultSet): Record<string, Object> {
    const columnNames = resultSet.columnNames
    const row: Record<string, Object> = {}

    for (let i = 0; i < columnNames.length; i++) {
      const columnName = columnNames[i]
      const columnType = resultSet.getColumnTypeSync(i)

      switch (columnType) {
        case relationalStore.ColumnType.INTEGER:
          row[columnName] = resultSet.getLong(i)
          break
        case relationalStore.ColumnType.REAL:
          row[columnName] = resultSet.getDouble(i)
          break
        case relationalStore.ColumnType.TEXT:
          row[columnName] = resultSet.getString(i)
          break
        default:
          row[columnName] = ''
      }
    }

    return row
  }
}
