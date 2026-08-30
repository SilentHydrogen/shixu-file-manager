import relationalStore from '@ohos.data.relationalStore'

export type LogStatus = 'running' | 'completed' | 'failed'

export class RagAnalysisLog {
  id?: number
  batchId: string = ''
  fileCount: number = 0
  startTime: number = Date.now()
  endTime?: number
  llmTokensUsed?: number
  status: LogStatus = 'running'
  errorMessage?: string

  /**
   * 从数据库行转换
   */
  static fromRow(row: Record<string, Object>): RagAnalysisLog {
    const log = new RagAnalysisLog()
    log.id = row.id as number
    log.batchId = row.batch_id as string
    log.fileCount = row.file_count as number
    log.startTime = row.start_time as number
    log.endTime = row.end_time as number
    log.llmTokensUsed = row.llm_tokens_used as number
    log.status = row.status as LogStatus
    log.errorMessage = row.error_message as string
    return log
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      batch_id: this.batchId,
      file_count: this.fileCount,
      start_time: this.startTime,
      status: this.status
    }

    if (this.endTime) values.end_time = this.endTime
    if (this.llmTokensUsed) values.llm_tokens_used = this.llmTokensUsed
    if (this.errorMessage) values.error_message = this.errorMessage

    return values
  }

  /**
   * 计算执行时长（毫秒）
   */
  getDuration(): number | null {
    if (!this.endTime) return null
    return this.endTime - this.startTime
  }

  /**
   * 是否完成
   */
  isCompleted(): boolean {
    return this.status === 'completed' || this.status === 'failed'
  }
}
