// entry/src/main/ets/data/repository/CollectionRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { Collection } from '../model/Collection'

export class CollectionRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }

  /**
   * 插入收纳箱
   */
  async insert(collection: Collection): Promise<number> {
    const store = await this.getStore()
    const values = collection.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_COLLECTIONS, values)
  }

  /**
   * 查询所有收纳箱
   */
  async findAll(): Promise<Collection[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.orderByAsc('created_time')

    const resultSet = await store.query(predicates)
    const collections: Collection[] = []

    try {
      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        collections.push(Collection.fromRow(rowData))
      }
    } finally {
      resultSet.close()
    }

    return collections
  }

  /**
   * 根据 ID 查询收纳箱
   */
  async findById(id: number): Promise<Collection | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('id', id)

    const resultSet = await store.query(predicates)

    try {
      if (resultSet.goToFirstRow()) {
        const rowData = this.resultSetToObject(resultSet)
        return Collection.fromRow(rowData)
      }
      return null
    } finally {
      resultSet.close()
    }
  }

  /**
   * 更新收纳箱
   */
  async update(collection: Collection): Promise<void> {
    if (!collection.id) {
      throw new Error('Collection id is required for update')
    }

    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('id', collection.id)

    const values = collection.toValuesBucket()
    await store.update(values, predicates)
  }

  /**
   * 删除收纳箱
   */
  async delete(id: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('id', id)
    await store.delete(predicates)
  }

  /**
   * 查询预设收纳箱
   */
  async findPresets(): Promise<Collection[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('is_preset', 1)

    const resultSet = await store.query(predicates)
    const collections: Collection[] = []

    try {
      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        collections.push(Collection.fromRow(rowData))
      }
    } finally {
      resultSet.close()
    }

    return collections
  }

  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
  private resultSetToObject(resultSet: relationalStore.ResultSet): Record<string, any> {
    const columnNames = resultSet.columnNames
    const row: Record<string, any> = {}

    for (let i = 0; i < columnNames.length; i++) {
      const columnName = columnNames[i]
      const columnType = resultSet.getColumnType(i)

      switch (columnType) {
        case relationalStore.ColumnType.TYPE_INTEGER:
          row[columnName] = resultSet.getLong(i)
          break
        case relationalStore.ColumnType.TYPE_FLOAT:
          row[columnName] = resultSet.getDouble(i)
          break
        case relationalStore.ColumnType.TYPE_STRING:
          row[columnName] = resultSet.getString(i)
          break
        default:
          row[columnName] = null
      }
    }

    return row
  }
}
