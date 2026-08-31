// entry/src/main/ets/data/repository/FileRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { FileInfo } from '../model/FileInfo'

export class FileRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }

  /**
   * 插入文件记录
   */
  async insert(fileInfo: FileInfo): Promise<number> {
    const store = await this.getStore()
    const values = fileInfo.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_FILES, values)
  }

  /**
   * 根据 URI 查询文件
   */
  async findByUri(uri: string): Promise<FileInfo | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('uri', uri)

    const resultSet = await store.query(predicates)

    try {
      if (resultSet.goToFirstRow()) {
        const rowData = this.resultSetToObject(resultSet)
        return FileInfo.fromRow(rowData)
      }
      return null
    } finally {
      resultSet.close()
    }
  }

  /**
   * 查询未处理的文件
   */
  async findUnprocessed(limit: number = 100): Promise<FileInfo[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('is_processed', 0)
    predicates.orderByDesc('created_time')
    predicates.limitAs(limit)

    const resultSet = await store.query(predicates)
    const files: FileInfo[] = []

    try {
      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        files.push(FileInfo.fromRow(rowData))
      }
      return files
    } finally {
      resultSet.close()
    }
  }

  /**
   * 查询文件列表，供首页迁移和关键词检索使用。
   */
  async findAll(limit: number = 1000): Promise<FileInfo[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.orderByDesc('modified_time')
    predicates.limitAs(limit)
    const resultSet = await store.query(predicates)
    const files: FileInfo[] = []
    try {
      while (resultSet.goToNextRow()) {
        files.push(FileInfo.fromRow(this.resultSetToObject(resultSet)))
      }
      return files
    } finally {
      resultSet.close()
    }
  }

  /**
   * 标记文件为已处理
   */
  async markAsProcessed(fileId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', fileId)

    const values: relationalStore.ValuesBucket = {
      is_processed: 1,
      processed_time: Date.now()
    }

    await store.update(values, predicates)
  }

  /**
   * 更新文件内容摘要和关键词
   */
  async updateContentSummary(fileId: number, summary: string, keywords: string[]): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', fileId)

    const values: relationalStore.ValuesBucket = {
      content_summary: summary,
      extracted_keywords: JSON.stringify(keywords)
    }

    await store.update(values, predicates)
  }

  /**
   * 根据 ID 查询文件
   */
  async findById(id: number): Promise<FileInfo | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', id)

    const resultSet = await store.query(predicates)

    try {
      if (resultSet.goToFirstRow()) {
        const rowData = this.resultSetToObject(resultSet)
        return FileInfo.fromRow(rowData)
      }
      return null
    } finally {
      resultSet.close()
    }
  }

  /**
   * 删除文件记录
   */
  async deleteById(id: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', id)
    await store.delete(predicates)
  }

  /**
   * 获取未处理文件数量
   */
  async countUnprocessed(): Promise<number> {
    const store = await this.getStore()
    const sql = `SELECT COUNT(*) as count FROM ${DatabaseConfig.TABLE_FILES} WHERE is_processed = 0`
    const resultSet = await store.querySql(sql)

    try {
      if (resultSet.goToFirstRow()) {
        const count = resultSet.getLong(0)
        return count
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
        case relationalStore.ColumnType.BLOB:
          row[columnName] = resultSet.getBlob(i)
          break
        default:
          row[columnName] = ''
      }
    }

    return row
  }
}
