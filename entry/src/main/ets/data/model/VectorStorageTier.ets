export type TierType = 'hot' | 'cold'

export class VectorStorageTier {
  fileId: number
  tier: TierType
  lastAccessed: number
  accessCount: number = 1

  constructor(init?: Partial<VectorStorageTier>) {
    Object.assign(this, init)
  }

  /**
   * 从数据库行转换
   */
  static fromRow(row: any): VectorStorageTier {
    return new VectorStorageTier({
      fileId: row.file_id,
      tier: row.tier as TierType,
      lastAccessed: row.last_accessed,
      accessCount: row.access_count
    })
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    return {
      file_id: this.fileId,
      tier: this.tier,
      last_accessed: this.lastAccessed,
      access_count: this.accessCount
    }
  }
}
