// entry/src/main/ets/data/model/FileInfo.ets

export class FileInfo {
  id?: number
  uri: string
  name: string
  type: string
  size: number
  path: string
  createdTime: number
  modifiedTime: number
  contentHash?: string
  isProcessed: boolean = false
  processedTime?: number
  contentSummary?: string
  extractedKeywords?: string[]

  constructor(init?: Partial<FileInfo>) {
    Object.assign(this, init)
  }

  /**
   * 从数据库行转换为 FileInfo
   */
  static fromRow(row: any): FileInfo {
    return new FileInfo({
      id: row.id,
      uri: row.uri,
      name: row.name,
      type: row.type,
      size: row.size,
      path: row.path,
      createdTime: row.created_time,
      modifiedTime: row.modified_time,
      contentHash: row.content_hash,
      isProcessed: row.is_processed === 1,
      processedTime: row.processed_time,
      contentSummary: row.content_summary,
      extractedKeywords: row.extracted_keywords ? JSON.parse(row.extracted_keywords) : []
    })
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
      uri: this.uri,
      name: this.name,
      type: this.type,
      size: this.size,
      path: this.path,
      created_time: this.createdTime,
      modified_time: this.modifiedTime,
      is_processed: this.isProcessed ? 1 : 0
    }

    if (this.contentHash) values.content_hash = this.contentHash
    if (this.processedTime) values.processed_time = this.processedTime
    if (this.contentSummary) values.content_summary = this.contentSummary
    if (this.extractedKeywords) values.extracted_keywords = JSON.stringify(this.extractedKeywords)

    return values
  }
}
