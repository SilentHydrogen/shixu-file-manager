// entry/src/main/ets/data/model/FileInfo.ets

import relationalStore from '@ohos.data.relationalStore'

export class FileInfo {
  id?: number
  uri: string = ''
  name: string = ''
  type: string = ''
  size: number = 0
  path: string = ''
  createdTime: number = 0
  modifiedTime: number = 0
  contentHash?: string
  isProcessed: boolean = false
  processedTime?: number
  contentSummary?: string
  extractedKeywords?: string[]

  /**
   * 从数据库行转换为 FileInfo
   */
  static fromRow(row: Record<string, Object>): FileInfo {
    const fileInfo = new FileInfo()
    fileInfo.id = row.id as number
    fileInfo.uri = row.uri as string
    fileInfo.name = row.name as string
    fileInfo.type = row.type as string
    fileInfo.size = row.size as number
    fileInfo.path = row.path as string
    fileInfo.createdTime = row.created_time as number
    fileInfo.modifiedTime = row.modified_time as number
    fileInfo.contentHash = row.content_hash as string
    fileInfo.isProcessed = (row.is_processed as number) === 1
    fileInfo.processedTime = row.processed_time as number
    fileInfo.contentSummary = row.content_summary as string
    fileInfo.extractedKeywords = row.extracted_keywords ? JSON.parse(row.extracted_keywords as string) as string[] : []
    return fileInfo
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
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
