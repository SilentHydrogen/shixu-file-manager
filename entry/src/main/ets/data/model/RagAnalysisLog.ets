export type LogStatus = 'running' | 'completed' | 'failed'

export class RagAnalysisLog {
  id?: number
  batchId: string
  fileCount: number
  startTime: number = Date.now()
  endTime?: number
  llmTokensUsed?: number
  status: LogStatus = 'running'
  errorMessage?: string

  constructor(init?: Partial<RagAnalysisLog>) {
    Object.assign(this, init)
  }

  /**
   * 从数据库行转换
   */
  static fromRow(row: any): RagAnalysisLog {
    return new RagAnalysisLog({
      id: row.id,
      batchId: row.batch_id,
      fileCount: row.file_count,
      startTime: row.start_time,
      endTime: row.end_time,
      llmTokensUsed: row.llm_tokens_used,
      status: row.status as LogStatus,
      errorMessage: row.error_message
    })
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
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
