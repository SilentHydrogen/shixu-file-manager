import relationalStore from '@ohos.data.relationalStore'

export class FileEmbedding {
  fileId: number = 0
  embedding: number[] = []
  createdTime: number = Date.now()

  /**
   * 从数据库行转换
   */
  static fromRow(row: Record<string, Object>): FileEmbedding {
    const embedding = new FileEmbedding()
    embedding.fileId = row.file_id as number
    embedding.embedding = JSON.parse(row.embedding_vector as string) as number[]
    embedding.createdTime = row.created_time as number
    return embedding
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      file_id: this.fileId,
      embedding_vector: JSON.stringify(this.embedding),
      created_time: this.createdTime
    }
    return values
  }
}
