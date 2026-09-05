// entry/src/main/ets/data/model/FileCollectionRef.ets

import relationalStore from '@ohos.data.relationalStore'

export type RefType = 'link' | 'physical'
export type CreatedBy = 'llm' | 'manual'

export class FileCollectionRef {
  id?: number
  fileId: number = 0
  collectionId: number = 0
  refType: RefType = 'link'
  confidence?: number
  createdTime: number = Date.now()
  createdBy: CreatedBy = 'llm'

  /**
   * 从数据库行转换
   */
  static fromRow(row: Record<string, Object>): FileCollectionRef {
    const ref = new FileCollectionRef()
    ref.id = row.id as number
    ref.fileId = row.file_id as number
    ref.collectionId = row.collection_id as number
    ref.refType = row.ref_type as RefType
    ref.confidence = row.confidence as number
    ref.createdTime = row.created_time as number
    ref.createdBy = row.created_by as CreatedBy
    return ref
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
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
