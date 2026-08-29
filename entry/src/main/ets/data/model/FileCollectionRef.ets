// entry/src/main/ets/data/model/FileCollectionRef.ets

export type RefType = 'link' | 'physical'
export type CreatedBy = 'llm' | 'manual'

export class FileCollectionRef {
  id?: number
  fileId: number
  collectionId: number
  refType: RefType = 'link'
  confidence?: number
  createdTime: number = Date.now()
  createdBy: CreatedBy = 'llm'

  constructor(init?: Partial<FileCollectionRef>) {
    Object.assign(this, init)
  }

  /**
   * 从数据库行转换
   */
  static fromRow(row: any): FileCollectionRef {
    return new FileCollectionRef({
      id: row.id,
      fileId: row.file_id,
      collectionId: row.collection_id,
      refType: row.ref_type as RefType,
      confidence: row.confidence,
      createdTime: row.created_time,
      createdBy: row.created_by as CreatedBy
    })
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
      file_id: this.fileId,
      collection_id: this.collectionId,
      ref_type: this.refType,
      created_time: this.createdTime,
      created_by: this.createdBy
    }

    if (this.confidence !== undefined) {
      values.confidence = this.confidence
    }

    return values
  }
}
