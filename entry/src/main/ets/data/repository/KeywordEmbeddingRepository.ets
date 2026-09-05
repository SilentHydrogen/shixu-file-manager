import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { KeywordEmbedding } from '../model/KeywordEmbedding'

export class KeywordEmbeddingRepository {
  private async store(): Promise<relationalStore.RdbStore> { return await DatabaseManager.getInstance().getStore() }
  async upsert(item: KeywordEmbedding): Promise<void> {
    const db = await this.store()
    await db.executeSql('INSERT OR REPLACE INTO keyword_embeddings(keyword,category,synonyms,embedding_vector,updated_time) VALUES(?,?,?,?,?)', [item.keyword, item.category, JSON.stringify(item.synonyms), JSON.stringify(item.embedding), item.updatedTime.toString()])
  }
  async list(): Promise<KeywordEmbedding[]> {
    const db = await this.store()
    const rows = await db.querySql('SELECT keyword,category,synonyms,embedding_vector,updated_time FROM keyword_embeddings')
    const result: KeywordEmbedding[] = []
    try {
      while (rows.goToNextRow()) result.push({ keyword: rows.getString(0), category: rows.getString(1), synonyms: JSON.parse(rows.getString(2)) as string[], embedding: JSON.parse(rows.getString(3)) as number[], updatedTime: rows.getLong(4) })
      return result
    } finally { rows.close() }
  }
}
