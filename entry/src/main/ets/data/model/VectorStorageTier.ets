import relationalStore from '@ohos.data.relationalStore'

export type TierType = 'hot' | 'cold'

export class VectorStorageTier {
  fileId: number = 0
  tier: TierType = 'hot'
  lastAccessed: number = 0
  accessCount: number = 1

  /**
   * 从数据库行转换
   */
  static fromRow(row: Record<string, Object>): VectorStorageTier {
    const tier = new VectorStorageTier()
    tier.fileId = row.file_id as number
    tier.tier = row.tier as TierType
    tier.lastAccessed = row.last_accessed as number
    tier.accessCount = row.access_count as number
    return tier
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      file_id: this.fileId,
      tier: this.tier,
      last_accessed: this.lastAccessed,
      access_count: this.accessCount
    }
    return values
  }
}
