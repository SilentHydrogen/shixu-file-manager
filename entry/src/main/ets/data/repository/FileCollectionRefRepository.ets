// entry/src/main/ets/data/repository/FileCollectionRefRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { FileCollectionRef, CreatedBy } from '../model/FileCollectionRef'

export class FileCollectionRefRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }

  /**
   * 添加文件和收纳箱的关联
   */
  async addRef(
    fileId: number,
    collectionId: number,
    confidence: number = 1.0,
    createdBy: CreatedBy = 'llm'
  ): Promise<number> {
    const ref = new FileCollectionRef()
    ref.fileId = fileId
    ref.collectionId = collectionId
    ref.confidence = confidence
    ref.createdBy = createdBy

    const store = await this.getStore()
    const values = ref.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_FILE_COLLECTION_REFS, values)
  }

  /**
   * 根据文件 ID 查询所有关联
   */
  async findByFileId(fileId: number): Promise<FileCollectionRef[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('file_id', fileId)

    const resultSet = await store.query(predicates)
    try {
      const refs: FileCollectionRef[] = []

      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        refs.push(FileCollectionRef.fromRow(rowData))
      }

      return refs
    } finally {
      resultSet.close()
    }
  }

  /**
   * 根据收纳箱 ID 查询所有关联
   */
  async findByCollectionId(collectionId: number): Promise<FileCollectionRef[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('collection_id', collectionId)

    const resultSet = await store.query(predicates)
    try {
      const refs: FileCollectionRef[] = []

      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        refs.push(FileCollectionRef.fromRow(rowData))
      }

      return refs
    } finally {
      resultSet.close()
    }
  }

  /**
   * 移除文件和收纳箱的关联
   */
  async removeRef(fileId: number, collectionId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('file_id', fileId)
    predicates.and()
    predicates.equalTo('collection_id', collectionId)

    await store.delete(predicates)
  }

  /**
   * 检查关联是否存在
   */
  async exists(fileId: number, collectionId: number): Promise<boolean> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('file_id', fileId)
    predicates.and()
    predicates.equalTo('collection_id', collectionId)

    const resultSet = await store.query(predicates)
    try {
      return resultSet.goToFirstRow()
    } finally {
      resultSet.close()
    }
  }

  /**
   * 获取收纳箱中的文件数量
   */
  async countByCollectionId(collectionId: number): Promise<number> {
    const store = await this.getStore()
    const sql = `SELECT COUNT(*) as count FROM ${DatabaseConfig.TABLE_FILE_COLLECTION_REFS} WHERE collection_id = ?`
    const resultSet = await store.querySql(sql, [collectionId.toString()])

    try {
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(0)
      }
      return 0
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
