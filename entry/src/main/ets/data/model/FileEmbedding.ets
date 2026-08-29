export class FileEmbedding {
  fileId: number
  embedding: number[]
  createdTime: number = Date.now()

  constructor(init?: Partial<FileEmbedding>) {
    Object.assign(this, init)
  }

  /**
   * 从数据库行转换
   */
  static fromRow(row: any): FileEmbedding {
    return new FileEmbedding({
      fileId: row.file_id,
      embedding: JSON.parse(row.embedding_vector),
      createdTime: row.created_time
    })
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    return {
      file_id: this.fileId,
      embedding_vector: JSON.stringify(this.embedding),
      created_time: this.createdTime
    }
  }
}
