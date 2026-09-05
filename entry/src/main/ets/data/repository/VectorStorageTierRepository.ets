import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { VectorStorageTier, TierType } from '../model/VectorStorageTier'

interface StorageStats {
  hotCount: number
  coldCount: number
}

export class VectorStorageTierRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }

  /**
   * 设置文件的存储层级
   */
  async setTier(fileId: number, tier: TierType): Promise<void> {
    const existing = await this.getTier(fileId)

    if (existing) {
      // 更新现有记录
      const store = await this.getStore()
      const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
      predicates.equalTo('file_id', fileId)

      const values: relationalStore.ValuesBucket = {
        tier: tier,
        last_accessed: Date.now()
      }

      await store.update(values, predicates)
    } else {
      // 插入新记录
      const tierInfo = new VectorStorageTier()
      tierInfo.fileId = fileId
      tierInfo.tier = tier
      tierInfo.lastAccessed = Date.now()
      tierInfo.accessCount = 1

      const store = await this.getStore()
      const values = tierInfo.toValuesBucket()
      await store.insert(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS, values)
    }
  }

  /**
   * 获取文件的存储层级
   */
  async getTier(fileId: number): Promise<TierType | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
    predicates.equalTo('file_id', fileId)

    const resultSet = await store.query(predicates)

    try {
      if (resultSet.goToFirstRow()) {
        const rowData = this.resultSetToObject(resultSet)
        const tierInfo = VectorStorageTier.fromRow(rowData)
        return tierInfo.tier
      }

      return null
    } finally {
      resultSet.close()
    }
  }

  /**
   * 查询指定层级的所有文件
   */
  async findByTier(tier: TierType): Promise<VectorStorageTier[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
    predicates.equalTo('tier', tier)

    const resultSet = await store.query(predicates)
    const tiers: VectorStorageTier[] = []

    try {
      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        tiers.push(VectorStorageTier.fromRow(rowData))
      }

      return tiers
    } finally {
      resultSet.close()
    }
  }

  /**
   * 更新文件的访问时间和访问次数
   */
  async updateAccessTime(fileId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
    predicates.equalTo('file_id', fileId)

    // 使用 SQL 更新以原子性地增加计数
    const sql = `UPDATE ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS}
                 SET last_accessed = ?, access_count = access_count + 1
                 WHERE file_id = ?`
    await store.executeSql(sql, [Date.now().toString(), fileId.toString()])
  }

  /**
   * 查找可以降级为冷数据的文件
   * 规则：超过 N 天未访问，或访问次数 < 3 且超过 7 天
   */
  async findColdCandidates(olderThanDays: number = 30): Promise<number[]> {
    const store = await this.getStore()
    const threshold = Date.now() - (olderThanDays * 24 * 60 * 60 * 1000)
    const sevenDaysAgo = Date.now() - (7 * 24 * 60 * 60 * 1000)

    const sql = `
      SELECT file_id FROM ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS}
      WHERE tier = 'hot' AND (
        last_accessed < ? OR
        (access_count < 3 AND last_accessed < ?)
      )
    `

    const resultSet = await store.querySql(sql, [threshold.toString(), sevenDaysAgo.toString()])
    const fileIds: number[] = []

    try {
      while (resultSet.goToNextRow()) {
        fileIds.push(resultSet.getLong(0))
      }

      return fileIds
    } finally {
      resultSet.close()
    }
  }

  /**
   * 批量降级为冷数据
   */
  async demoteToCold(fileIds: number[]): Promise<void> {
    if (fileIds.length === 0) return

    const store = await this.getStore()
    const placeholders = fileIds.map(() => '?').join(',')
    const sql = `UPDATE ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS}
                 SET tier = 'cold'
                 WHERE file_id IN (${placeholders})`

    await store.executeSql(sql, fileIds.map(id => id.toString()))
  }

  /**
   * 批量提升为热数据
   */
  async promoteToHot(fileIds: number[]): Promise<void> {
    if (fileIds.length === 0) return

    const store = await this.getStore()
    const placeholders = fileIds.map(() => '?').join(',')
    const sql = `UPDATE ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS}
                 SET tier = 'hot', last_accessed = ?
                 WHERE file_id IN (${placeholders})`

    const args = [Date.now().toString(), ...fileIds.map(id => id.toString())]
    await store.executeSql(sql, args)
  }

  /**
   * 获取存储统计信息
   */
  async getStats(): Promise<StorageStats> {
    const store = await this.getStore()
    const sql = `
      SELECT
        SUM(CASE WHEN tier = 'hot' THEN 1 ELSE 0 END) as hot_count,
        SUM(CASE WHEN tier = 'cold' THEN 1 ELSE 0 END) as cold_count
      FROM ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS}
    `

    const resultSet = await store.querySql(sql)

    try {
      if (resultSet.goToFirstRow()) {
        const hotCount = resultSet.getLong(0)
        const coldCount = resultSet.getLong(1)
        const stats: StorageStats = { hotCount, coldCount }
        return stats
      }

      const emptyStats: StorageStats = { hotCount: 0, coldCount: 0 }
      return emptyStats
    } finally {
      resultSet.close()
    }
  }

  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
  private resultSetToObject(resultSet: relationalStore.ResultSet): Record<string, Object> {
    const columnNames = resultSet.columnNames
    const row: Record<string, Object> = {}

    for (let i = 0; i < columnNames.length; i++) {
      const columnName = columnNames[i]
      const columnType = resultSet.getColumnTypeSync(i)

      switch (columnType) {
        case relationalStore.ColumnType.INTEGER:
          row[columnName] = resultSet.getLong(i)
          break
        case relationalStore.ColumnType.REAL:
          row[columnName] = resultSet.getDouble(i)
          break
        case relationalStore.ColumnType.TEXT:
          row[columnName] = resultSet.getString(i)
          break
        default:
          row[columnName] = ''
      }
    }

    return row
  }
}
