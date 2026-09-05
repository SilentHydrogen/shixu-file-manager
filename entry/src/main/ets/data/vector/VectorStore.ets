import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { FileEmbedding } from '../model/FileEmbedding'

export class VectorStore {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }

  /**
   * 保存文件的 embedding 向量
   */
  async saveEmbedding(fileId: number, embedding: number[]): Promise<void> {
    const store = await this.getStore()

    const fileEmbedding = new FileEmbedding()
    fileEmbedding.fileId = fileId
    fileEmbedding.embedding = embedding

    const values = fileEmbedding.toValuesBucket()

    // 使用 INSERT OR REPLACE 实现 upsert
    const sql = `
      INSERT OR REPLACE INTO file_embeddings (file_id, embedding_vector, created_time)
      VALUES (?, ?, ?)
    `

    await store.executeSql(sql, [
      fileId.toString(),
      values.embedding_vector as string,
      (values.created_time as number).toString()
    ])
  }

  /**
   * 获取文件的 embedding 向量
   */
  async getEmbedding(fileId: number): Promise<number[] | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates('file_embeddings')
    predicates.equalTo('file_id', fileId)

    const resultSet = await store.query(predicates)

    try {
      if (resultSet.goToFirstRow()) {
        const embeddingJson = resultSet.getString(resultSet.getColumnIndex('embedding_vector'))
        return JSON.parse(embeddingJson)
      }
      return null
    } finally {
      resultSet.close()
    }
  }

  /**
   * 获取所有文件的 embeddings（用于构建索引）
   */
  async getAllEmbeddings(): Promise<FileEmbedding[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates('file_embeddings')

    const resultSet = await store.query(predicates)
    const embeddings: FileEmbedding[] = []

    try {
      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        embeddings.push(FileEmbedding.fromRow(rowData))
      }
      return embeddings
    } finally {
      resultSet.close()
    }
  }

  /**
   * 删除文件的 embedding
   */
  async deleteEmbedding(fileId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates('file_embeddings')
    predicates.equalTo('file_id', fileId)
    await store.delete(predicates)
  }

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
        case relationalStore.ColumnType.TEXT:
          row[columnName] = resultSet.getString(i)
          break
        case relationalStore.ColumnType.REAL:
          row[columnName] = resultSet.getDouble(i)
          break
        default:
          row[columnName] = ''
      }
    }

    return row
  }
}
