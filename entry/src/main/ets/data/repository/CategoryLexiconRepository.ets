import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { CategoryLexicon } from '../model/CategoryLexicon'

export class CategoryLexiconRepository {
  private async store(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }

  async upsert(item: CategoryLexicon): Promise<void> {
    const db = await this.store()
    await db.executeSql(
      'INSERT OR REPLACE INTO category_lexicons(category_name,subtitle,source,seed_keywords,expanded_keywords,embedding_vector,fingerprint,updated_time) VALUES(?,?,?,?,?,?,?,?)',
      [item.categoryName, item.subtitle, item.source, JSON.stringify(item.seedKeywords),
        JSON.stringify(item.expandedKeywords), JSON.stringify(item.embedding), item.fingerprint, item.updatedTime.toString()])
  }

  async list(): Promise<CategoryLexicon[]> {
    const db = await this.store()
    const rows = await db.querySql('SELECT category_name,subtitle,source,seed_keywords,expanded_keywords,embedding_vector,fingerprint,updated_time FROM category_lexicons')
    const result: CategoryLexicon[] = []
    try {
      while (rows.goToNextRow()) {
        result.push({
          categoryName: rows.getString(0),
          subtitle: rows.getString(1),
          source: rows.getString(2) === 'preset' ? 'preset' : 'user',
          seedKeywords: JSON.parse(rows.getString(3)) as string[],
          expandedKeywords: JSON.parse(rows.getString(4)) as string[],
          embedding: JSON.parse(rows.getString(5)) as number[],
          fingerprint: rows.getString(6),
          updatedTime: rows.getLong(7)
        })
      }
      return result
    } finally {
      rows.close()
    }
  }
}
